
{*******************************************************}
{                                                       }
{       Turbo Pascal Version 6.0                        }
{       Turbo Vision Unit                               }
{                                                       }
{       Copyright (c) 1990 Borland International        }
{                                                       }
{*******************************************************}

unit OddDlg;

{$F+,O+,V-,X+,D-}

interface

uses Overlay, Objects, Drivers, Views, Dialogs, Dos, StdDlg, ExpConst;

const

{ Commands }

  cmFileOpen    = 800;   { Returned from TFileDialog when Open pressed }
  cmFileReplace = 801;   { Returned from TFileDialog when Replace pressed }
  cmFileClear   = 802;   { Returned from TFileDialog when Clear pressed }
  cmFileInit    = 803;   { Used by TFileDialog internally }
  cmChangeDir   = 804;   { Used by TChDirDialog internally }
  cmRevert      = 805;   { Used by TChDirDialog internally }

{ Messages }

  cmDbItemFocused = 806;
  cmValueFocused =  808;
  cmFileDoubleClicked     { A file was selected in the TFileList }
                = 807;
  cmAdd = 809;
  cmFindDbContentsList = 810;
  cmDel = 811;

  cmWhy = 812;

type

  PPossibleValueInputLine = ^TPossibleValueInputLine;
  TPossibleValueInputLine = object(TInputLine)
    constructor Init(var Bounds: TRect; AMaxLen: Integer);
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  PDbEditInputLine = ^TDbEditInputLine;
  TDbEditInputLine = object(TInputLine)
    constructor Init(var Bounds: TRect; AMaxLen: Integer);
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  { TFileCollection is a collection of TSearchRec's.            }

  PFileCollection = ^TFileCollection;
  TFileCollection = object(TSortedCollection)
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    procedure FreeItem(Item: Pointer); virtual;
  end;

  { TSortedListBox is a TListBox that assumes it has a          }
  { TStoredCollection instead of just a TCollection.  It will   }
  { perform an incremental search on the contents.              }

  PSortedListBox = ^TSortedListBox;
  TSortedListBox = object(TListBox)
    SearchPos: Word;
    ShiftState: Byte;
    constructor Init(var Bounds: TRect; ANumCols: Word;
      AScrollBar: PScrollBar);
    procedure HandleEvent(var Event: TEvent); virtual;
    function GetKey(var S: String): Pointer; virtual;
    procedure NewList(AList: PCollection); virtual;
  end;

  PPossibleValueList = ^TPossibleValueList;
  TPossibleValueList = object(TSortedListBox)
    constructor Init(var Bounds: TRect; AScrollBar: PScrollBar);
    destructor Done; virtual;
    function DataSize: Word; virtual;
    procedure FocusItem(Item: Integer); virtual;
    procedure GetData(var Rec); virtual;
    function GetText(Item: Integer; MaxLen: Integer): String; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetData(var Rec); virtual;
    procedure DeletePossibleIdentifier(TempId : PString);
  end;

  PDbEditList = ^TDbEditList;
  TDbEditList = object(TSortedListBox)
    constructor Init(var Bounds: TRect; AScrollBar: PScrollBar);
    destructor Done; virtual;
    function DataSize: Word; virtual;
    procedure FocusItem(Item: Integer); virtual;
    procedure GetData(var Rec); virtual;
    function GetText(Item: Integer; MaxLen: Integer): String; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetData(var Rec); virtual;
    procedure DeletePossibleIdentifier(TempId : PString);
  end;

  { TFileDialog is a standard file name input dialog            }

  TWildStr = PathStr;

const
  fdOkButton      = $0001;      { Put an OK button in the dialog }
  fdOpenButton    = $0002;      { Put an Open button in the dialog }
  fdReplaceButton = $0004;      { Put a Replace button in the dialog }
  fdClearButton   = $0008;      { Put a Clear button in the dialog }
  fdHelpButton    = $0010;      { Put a Help button in the dialog }
  fdNoLoadDir     = $0100;      { Do not load the current directory }
                                { contents into the dialog at Init. }
                                { This means you intend to change the }
                                { WildCard by using SetData or store }
                                { the dialog on a stream. }

type

  PDbEditDialog = ^TDbEditDialog;
  TDbEditDialog = object(TDialog)
    PossibleValueInputLine : PPossibleValueInputLine;
    PossibleValueList : PPossibleValueList;
    DbContentsInputLine : PDbEditInputLine;
    DbContentsList : PDbEditList;
    constructor Init(ATitle: String; AOptions: Word;
                      HistoryId: Byte);
    destructor Done; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure SetData(var Rec); virtual;
    procedure GetData(var Rec); virtual;
  end;

  DbEditRecord = record
    PossibleValueInputLine : String[TupleLen];
    PossibleValueList : PCollection;
    DbContentsInputLine : String[TupleLen];
    DbContentsList : PCollection;
  end; { DbEditRecord }

  PBackChainGoalDialog = ^TBackChainGoalDialog;
  TBackChainGoalDialog = object(TDialog)
    GoalInputLine : PPossibleValueInputLine;
    PossibleAnswerList : PPossibleValueList;
    constructor Init(ATitle: String; AOptions: Word;
                      HistoryId: Byte);
    destructor Done; virtual;
    procedure SetData(var Rec); virtual;
    procedure GetData(var Rec); virtual;
  end;

  BackChainGoalRecord = record
    GoalInputLine : String[TupleLen];
    PossibleGoalList : PCollection;
  end; { BackChainGoalRecord }

  PQuestionDialog = ^TQuestionDialog;
  TQuestionDialog = object(TDialog)
    AnswerInputLine : PPossibleValueInputLine;
    PossibleAnswerList : PPossibleValueList;
    constructor Init(ATitle: String; Identifier : String; AOptions: Word;
                      HistoryId: Byte);
    destructor Done; virtual;
    procedure SetData(var Rec); virtual;
    procedure GetData(var Rec); virtual;
  end;

  QuestionRecord = record
    AnswerInputLine : String[TupleLen];
    PossibleAnswerList : PCollection;
  end; { QuestionRecord }

const
  cdNormal     = $0000; { Option to use dialog immediately }
  cdNoLoadDir  = $0001; { Option to init the dialog to store on a stream }
  cdHelpButton = $0002; { Put a help button in the dialog }

const
  CInfoPane = #30;

implementation

uses App, Memory, HistList, MsgBox;

{ TPossibleValueInputLine }

constructor TPossibleValueInputLine.Init(var Bounds: TRect; AMaxLen: Integer);
begin
  TInputLine.Init(Bounds, AMaxLen);
  EventMask := EventMask or evBroadcast;
end;

procedure TPossibleValueInputLine.HandleEvent(var Event: TEvent);
begin
  TInputLine.HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmValueFocused) and
    (State and sfSelected = 0) then
  begin
     Data := NewStr(PString(Event.InfoPtr)^);
     DrawView;
     ClearEvent(Event);
  end;
end;

{ TDbEditInputLine }

constructor TDbEditInputLine.Init(var Bounds: TRect; AMaxLen: Integer);
begin
  TInputLine.Init(Bounds, AMaxLen);
  EventMask := EventMask or evBroadcast;
end;

procedure TDbEditInputLine.HandleEvent(var Event: TEvent);
begin
  TInputLine.HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmDbItemFocused) and
    (State and sfSelected = 0) then
  begin
     Data := NewStr(PString(Event.InfoPtr)^);
     DrawView;
     ClearEvent(Event);
  end;
end;

{ TFileCollection }

function TFileCollection.Compare(Key1, Key2: Pointer): Integer;
begin
  if PString(Key1)^= PString(Key2)^ then Compare := 0
  else if PString(Key1)^ > Pstring(Key2)^ then
    Compare := 1
  else Compare := -1;
end;

procedure TFileCollection.FreeItem(Item: Pointer);
begin
  DisposeStr(PString(Item));
end;

{ TSortedListBox }

constructor TSortedListBox.Init(var Bounds: TRect; ANumCols: Word;
  AScrollBar: PScrollBar);
begin
  TListBox.Init(Bounds, {ANumCols}1, AScrollBar);
  SearchPos := 0;
  ShowCursor;
  SetCursor(1,0);
end;

procedure TSortedListBox.HandleEvent(var Event: TEvent);
var
  ShiftKeys: Byte absolute $40:$17;
  CurString, NewString: String;
  K: Pointer;
  Value, OldPos, OldValue: Integer;
  T: Boolean;

function Equal(var S1: String; var S2: String; Count: Word): Boolean;
var
  I: Word;
begin
  Equal := False;
  if (Length(S1) < Count) or (Length(S2) < Count) then Exit;
  for I := 1 to Count do
    if UpCase(S1[I]) <> UpCase(S2[I]) then Exit;
  Equal := True;
end;

begin
  OldValue := Focused;
  TListBox.HandleEvent(Event);
  if OldValue <> Focused then SearchPos := 0;
  if Event.What = evKeyDown then
  begin
    if Event.CharCode <> #0 then
    begin
      Value := Focused;
      if Value < Range then CurString := GetText(Value, 255)
      else CurString := '';
      OldPos := SearchPos;
      if Event.KeyCode = kbBack then
      begin
        if SearchPos = 0 then Exit;
        Dec(SearchPos);
        if SearchPos = 0 then ShiftState := ShiftKeys;
        CurString[0] := Char(SearchPos);
      end
      else if (Event.CharCode = '.') then SearchPos := Pos('.',CurString)
      else
      begin
        Inc(SearchPos);
        if SearchPos = 1 then ShiftState := ShiftKeys;
        CurString[0] := Char(SearchPos);
        CurString[SearchPos] := Event.CharCode;
      end;
      K := GetKey(CurString);
      T := PSortedCollection(List)^.Search(K, Value);
      if Value < Range then
      begin
        if Value < Range then NewString := GetText(Value, 255)
        else NewString := '';
        if Equal(NewString, CurString, SearchPos) then
        begin
          if Value <> OldValue then
          begin
            FocusItem(Value);
            { Assumes ListControl will set the cursor to the first character }
            { of the sfFocused item }
            SetCursor(Cursor.X+SearchPos, Cursor.Y);
          end
          else SetCursor(Cursor.X+(SearchPos-OldPos), Cursor.Y);
        end
        else SearchPos := OldPos;
      end
      else SearchPos := OldPos;
      if (SearchPos <> OldPos) or (Event.CharCode in ['A'..'Z','a'..'z']) then
        ClearEvent(Event);
    end;
  end;
end;

function TSortedListBox.GetKey(var S: String): Pointer;
begin
  GetKey := @S;
end;

procedure TSortedListBox.NewList(AList: PCollection);
begin
  TListBox.NewList(AList);
  SearchPos := 0;
end;

{ TPossibleValueList }

constructor TPossibleValueList.Init(var Bounds: TRect; AScrollBar: PScrollBar);
begin
  List := New(PCollection, Init(1,1));
  List^.SetLimit(100);
  TSortedListBox.Init(Bounds, 2, AScrollBar);
end;

destructor TPossibleValueList.Done;
begin
  if List <> nil then Dispose(List, Done);
  TListBox.Done;
end;

function TPossibleValueList.DataSize: Word;
begin
  DataSize := 0;
end;

procedure TPossibleValueList.FocusItem(Item: Integer);
begin
  TSortedListBox.FocusItem(Item);
  Message(Owner, evBroadcast, cmValueFocused, List^.At(Item));
end;

procedure TPossibleValueList.GetData(var Rec);
begin
end;

function TPossibleValueList.GetText(Item: Integer; MaxLen: Integer): String;
var
  S: PString;
begin
  S := PString(List^.At(Item));
  GetText := S^;
end;

procedure TPossibleValueList.HandleEvent(var Event: TEvent);
begin
  if (Event.What = evMouseDown) and (Event.Double) then
  begin
    Event.What := evCommand;
    Event.Command := cmOK;
    PutEvent(Event);
    ClearEvent(Event);
  end
  else TSortedListBox.HandleEvent(Event);
end;

procedure TPossibleValueList.SetData(var Rec);
begin
end;

procedure TDbEditList.DeletePossibleIdentifier(TempId : PString);
{* Remove given string from the Possible Value list *}
var
  Count : Integer;
  Str : PString;
begin
  for Count := 0 to Range-1 do
    begin
    Str := List^.At(Count);
    if Str^ = TempId^ then
      begin
      DisposeStr(Str);
      Str := nil;
      List^.AtDelete(Count);
      SetRange(Range-1);
      Exit;
      end; { if }
    end; { for }
end;

{ TDbEditList }

constructor TDbEditList.Init(var Bounds: TRect; AScrollBar: PScrollBar);
begin
  List := New(PCollection, Init(1,1));
  List^.SetLimit(100);
  TSortedListBox.Init(Bounds, 2, AScrollBar);
end;

destructor TDbEditList.Done;
begin
  if List <> nil then Dispose(List, Done);
  TListBox.Done;
end;

function TDbEditList.DataSize: Word;
begin
  DataSize := 0;
end;

procedure TDbEditList.FocusItem(Item: Integer);
begin
  TSortedListBox.FocusItem(Item);
  Message(Owner, evBroadcast, cmDbItemFocused, List^.At(Item));
end;

procedure TDbEditList.GetData(var Rec);
begin
end;

function TDbEditList.GetText(Item: Integer; MaxLen: Integer): String;
var
  S: PString;
begin
  S := PString(List^.At(Item));
  GetText := S^;
end;

procedure TDbEditList.HandleEvent(var Event: TEvent);
begin
  if (Event.What = evMouseDown) and (Event.Double) then
  begin
    Event.What := evCommand;
    Event.Command := cmOK;
    PutEvent(Event);
    ClearEvent(Event);
  end
  else
    TSortedListBox.HandleEvent(Event);
end;

procedure TDbEditList.SetData(var Rec);
begin
end;

procedure TPossibleValueList.DeletePossibleIdentifier(TempId : PString);
{* Remove given string from the Possible Value list *}
var
  Count : Integer;
  Str : PString;
begin
  for Count := 0 to Range-1 do
    begin
    Str := List^.At(Count);
    if Str^ = TempId^ then
      begin
      DisposeStr(Str);
      Str := nil;
      List^.AtDelete(Count);
      SetRange(Range-1);
      Exit;
      end; { if }
    end; { for }
end;

{ TDbEditDialog }

constructor TDbEditDialog.Init(ATitle: String; AOptions: Word;
                                HistoryId: Byte);
var
  Control: PView;
  R: TRect;
  S: String;
  Opt: Word;
  ACurDir: PathStr;
begin
  R.Assign(0, 0, 78, 20);
  TDialog.Init(R, ATitle);
  Options := Options or ofCentered;

  R.Assign(3,3,28,4);
  PossibleValueInputLine := New(PPossibleValueInputLine, Init(R, TupleLen));
  Insert(PossibleValueInputLine);
  R.Assign(2,2,3+CStrLen('Identifier'),3);
  Control := New(PLabel, Init(R, 'Identifier', PossibleValueInputLine));
  Insert(Control);

  R.Assign(3,17,32,18);
  Control := New(PScrollBar, Init(R));
  Insert(Control);
  R.Assign(3,6,32,17);
  PossibleValueList := New(PPossibleValueList, Init(R, PScrollBar(Control)));
  Insert(PossibleValueList);
  R.Assign(2,5,22,6);
  Control := New(PLabel, Init(R, '~P~ossible Values', PossibleValueList));
  Insert(Control);

  R.Assign(32, 7, 43, 9);
  Insert(New(PButton, Init(R, '~A~dd =>>', cmAdd, bfNormal)));

  R.Assign(32, 10, 43, 12);
  Insert(New(PButton, Init(R, '<<= ~D~el', cmDel, bfNormal)));

  R.Assign(45,3,70,4);
  DbContentsInputLine := New(PDbEditInputLine, Init(R, TupleLen));
  Insert(DbContentsInputLine);
  R.Assign(45,2,59,3);
  Control := New(PLabel, Init(R, 'Value', DbContentsInputLine));
  Insert(Control);

  R.Assign(45,14,74,15);
  Control := New(PScrollBar, Init(R));
  Insert(Control);
  R.Assign(45,6,74,14);
  DbContentsList := New(PDbEditList, Init(R, PScrollBar(Control)));
  Insert(DbContentsList);
  R.Assign(45,5,63,6);
  Control := New(PLabel, Init(R, '~D~atabase Contents', DbContentsList));
  Insert(Control);

  R.Assign(55, 16, 65, 18);
  Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));

  R.Assign(66, 16, 74, 18);
  Insert(New(PButton, Init(R, '~O~K', cmOk, bfDefault)));

  SelectNext(False);
end;

destructor TDbEditDialog.Done;
begin
  TDialog.Done;
  PossibleValueInputLine^.Done;
  PossibleValueList^.Done;
  DbContentsInputLine^.Done;
  DbContentsList^.Done;
end;

procedure TDbEditDialog.HandleEvent(var Event: TEvent);
var
  Str : PString;
begin
  TDialog.HandleEvent(Event);
  if Event.What = evCommand then
    case Event.Command of
      cmAdd:
        begin
        if not((PossibleValueInputLine^.Data^ = '') or
                 (PossibleValueInputLine^.Data^ = '<Not Initialised>')) then
          begin
          Str := NewStr(PossibleValueInputLine^.Data^);
          DbContentsList^.List^.Insert(Str);
          DbContentsList^.SetRange(DbContentsList^.Range+1);
          PossibleValueList^.DeletePossibleIdentifier(PossibleValueInputLine^.Data);
          DisposeStr(PossibleValueInputLine^.Data);
          PossibleValueInputLine^.Data := NewStr('<Not Initialised>');
          PossibleValueInputLine^.Draw;
          PossibleValueList^.Draw;
          DbContentsList^.Draw;
          end; { if }
        end;
      cmDel:
        begin
        if not((DbContentsInputLine^.Data^ = '') or
                 (DbContentsInputLine^.Data^ = '<Not Initialised>')) then
          begin
          Str := NewStr(DbContentsInputLine^.Data^);
          PossibleValueList^.List^.Insert(Str);
          PossibleValueList^.SetRange(PossibleValueList^.Range+1);
          DbContentsList^.DeletePossibleIdentifier(DbContentsInputLine^.Data);
          DisposeStr(DbContentsInputLine^.Data);
          DbContentsInputLine^.Data := NewStr('<Not Initialised>');
          DbContentsInputLine^.Draw;
          DbContentsList^.Draw;
          PossibleValueList^.Draw;
          end; { if }
        end;
    end;
end;

procedure TDbEditDialog.SetData(var Rec);
begin
  TDialog.SetData(Rec);
  PossibleValueInputLine^.Data^ := DbEditRecord(Rec).PossibleValueInputLine;
  PossibleValueList^.NewList(DbEditRecord(Rec).PossibleValueList);
  DbContentsInputLine^.Data^ := DbEditrecord(Rec).DbContentsInputLine;
  DbContentsList^.NewList(DbEditRecord(Rec).DbContentsList);
end;

procedure TDbEditDialog.GetData(var Rec);
begin
  TDialog.GetData(Rec);
  DbEditRecord(Rec).PossibleValueInputLine := PossibleValueInputLine^.Data^;
  DbEditRecord(Rec).PossibleValueList := PossibleValueList^.List;
  DbEditRecord(Rec).DbContentsInputLine := DbContentsInputLine^.Data^;
  DbEditRecord(Rec).DbContentsList := DbContentsList^.List;
end;

{ TBackChainGoalDialog }

constructor TBackChainGoalDialog.Init(ATitle: String; AOptions: Word;
                                HistoryId: Byte);
var
  Control: PView;
  R: TRect;
  S: String;
  Opt: Word;
  ACurDir: PathStr;
begin
  R.Assign(0, 0, 40, 15);
  TDialog.Init(R, ATitle);
  Options := Options or ofCentered;

  R.Assign(4,3,34,4);
  GoalInputLine := New(PPossibleValueInputLine, Init(R, TupleLen));
  Insert(GoalInputLine);
  R.Assign(4,2,34,3);
  Control := New(PLabel, Init(R, '~S~elected Goal', GoalInputLine));
  Insert(Control);

  R.Assign(4,10,34,11);
  Control := New(PScrollBar, Init(R));
  Insert(Control);
  R.Assign(4,6,34,10);
  PossibleAnswerList := New(PPossibleValueList, Init(R, PScrollBar(Control)));
  Insert(PossibleAnswerList);
  R.Assign(4,5,34,6);
  Control := New(PLabel, Init(R, '~P~ossible Goals', PossibleAnswerList));
  Insert(Control);

  R.Assign(12, 12, 22, 14);
  Insert(New(PButton, Init(R, '~C~ancel', cmCancel, bfNormal)));

  R.Assign(25, 12, 33, 14);
  Insert(New(PButton, Init(R, '~O~K', cmOk, bfDefault)));

  SelectNext(False);
end;

destructor TBackChainGoalDialog.Done;
begin
  TDialog.Done;
  GoalInputLine^.Done;
  PossibleAnswerList^.Done;
end;

procedure TBackChainGoalDialog.SetData(var Rec);
begin
  TDialog.SetData(Rec);
  GoalInputLine^.Data^ := BackChainGoalRecord(Rec).GoalInputLine;
  PossibleAnswerList^.NewList(BackChainGoalRecord(Rec).PossibleGoalList);
end;

procedure TBackChainGoalDialog.GetData(var Rec);
begin
  TDialog.GetData(Rec);
  BackChainGoalRecord(Rec).GoalInputLine := GoalInputLine^.Data^;
  BackChainGoalRecord(Rec).PossibleGoalList := PossibleAnswerList^.List;
end;

{ TQuestionDialog }

constructor TQuestionDialog.Init(ATitle: String; Identifier : String; AOptions: Word;
                                HistoryId: Byte);
var
  Control: PView;
  R: TRect;
  S: String;
  Opt: Word;
  ACurDir: PathStr;
begin
  R.Assign(0, 0, 65, 15);
  TDialog.Init(R, ATitle);
  Options := Options or ofCentered;

  R.Assign(35,3,61,4);
  AnswerInputLine := New(PPossibleValueInputLine, Init(R, TupleLen));
  Insert(AnswerInputLine);
  R.Assign(35,2,61,3);
  Control := New(PLabel, Init(R, '~A~nswer', AnswerInputLine));
  Insert(Control);

  R.Assign(35,5,61,10);
  Control := New(PScrollBar, Init(R));
  Insert(Control);
  R.Assign(35,6,61,10);
  PossibleAnswerList := New(PPossibleValueList, Init(R, PScrollBar(Control)));
  Insert(PossibleAnswerList);
  R.Assign(35,5,61,6);
  Control := New(PLabel, Init(R, '~P~ossible Answers', PossibleAnswerList));
  Insert(Control);

  R.Assign(4,3,30,4);
  Control := New(PLabel, Init(R, Identifier + ' ?', nil));
  Insert(Control);

  R.Assign(25, 12, 35, 14);
  Insert(New(PButton, Init(R, '~W~hy ?', cmWhy, bfNormal)));

  R.Assign(37, 12, 47, 14);
  Insert(New(PButton, Init(R, '~C~ancel', cmCancel, bfNormal)));

  R.Assign(49, 12, 59, 14);
  Insert(New(PButton, Init(R, '~O~K', cmOk, bfDefault)));

  SelectNext(False);
end;

destructor TQuestionDialog.Done;
begin
  TDialog.Done;
  AnswerInputLine^.Done;
  PossibleAnswerList^.Done;
end;

procedure TQuestionDialog.SetData(var Rec);
begin
  TDialog.SetData(Rec);
  AnswerInputLine^.Data^ := QuestionRecord(Rec).AnswerInputLine;
  PossibleAnswerList^.NewList(QuestionRecord(Rec).PossibleAnswerList);
end;

procedure TQuestionDialog.GetData(var Rec);
begin
  TDialog.GetData(Rec);
  QuestionRecord(Rec).AnswerInputLine := AnswerInputLine^.Data^;
  QuestionRecord(Rec).PossibleAnswerList := PossibleAnswerList^.List;
end;

end.
