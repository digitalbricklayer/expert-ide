{****************************************************}
{           Expert System Shell                      }
{           by Jack Hughes                           }
{           Programmed using Turbo Pascal V6.0       }
{           and Turbo Vision                         }
{           with the editor taken from TVEDIT.PAS    }
{****************************************************}

program Expert;

{$M 45132,65132,655360}
{$X+,D-}

uses Overlay, Dos, Objects, Drivers, Memory, Views, Menus, Dialogs, Crt,
  StdDlg, MsgBox, App, Calc, Buffers, Editors, r_base, expconst, RuleHan,
  dbview, d_base, OddDlg;

{$O Objects}
{$O Dos}
{$O Memory}
{$O Views}
{$O Menus}
{$O Dialogs}
{$O StdDlg}
{$O Buffers}
{$O Editors}
{$O r_base}
{$O rulehan}
{$O MsgBox}
{$O OddDlg}

const
  HeapSize = 32 * (1024 div 16);

const
  cmOpen       = 100;
  cmNew        = 101;
  cmChangeDir  = 102;
  cmDosShell   = 103;
  cmShowClip   = 105;
  cmDefQuestions   = 106;
  cmMakeForm       = 107;
  cmAccept         = 108;
  cmForwardChain   = 109;
  cmBackwardChain  = 110;
  cmExamineAns     = 111;
  cmDefineGoal     = 112;
  cmResetSystem    = 113;
  cmExamineDataBase = 114;
  cmBreakpoint      = 115;
  cmWatchPoint      = 116;
  cmInfMechOptions  = 117;
  cmTraceSetting    = 118;
  cmExpertHelp      = 119;
  cmEditorHelp      = 120;
  cmSpy    = 121;
  cmWatch  = 122;
  cmExamineDb = 123;

type
  PEditorApp = ^TEditorApp;
  TEditorApp = object(TApplication)
    constructor Init;
    destructor Done; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure OutOfMemory; virtual;
  end;

var
  EditorApp: TEditorApp;
  ClipWindow: PEditWindow;
  RuleBase : RBase;
  GoalDialogData : BackChainGoalRecord;
  D : Boolean;
  c : Longint;

function ExecDialog(P: PDialog; Data: Pointer): Word;
var
  Result: Word;
begin
  Result := cmCancel;
  P := PDialog(Application^.ValidView(P));
  if P <> nil then
  begin
    if Data <> nil then P^.SetData(Data^);
    Result := DeskTop^.ExecView(P);
    if (Result <> cmCancel) and (Data <> nil) then P^.GetData(Data^);
    Dispose(P, Done);
  end;
  ExecDialog := Result;
end;

function CreateFindDialog: PDialog;
var
  D: PDialog;
  Control: PView;
  R: TRect;
begin
  R.Assign(0, 0, 38, 12);
  D := New(PDialog, Init(R, 'Find'));
  with D^ do
  begin
    Options := Options or ofCentered;

    R.Assign(3, 3, 32, 4);
    Control := New(PInputLine, Init(R, 80));
    Insert(Control);
    R.Assign(2, 2, 15, 3);
    Insert(New(PLabel, Init(R, '~T~ext to find', Control)));
    R.Assign(32, 3, 35, 4);
    Insert(New(PHistory, Init(R, PInputLine(Control), 10)));

    R.Assign(3, 5, 35, 7);
    Insert(New(PCheckBoxes, Init(R,
      NewSItem('~C~ase sensitive',
      NewSItem('~W~hole words only', nil)))));

    R.Assign(14, 9, 24, 11);
    Insert(New(PButton, Init(R, 'O~K~', cmOk, bfDefault)));
    Inc(R.A.X, 12); Inc(R.B.X, 12);
    Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));

    SelectNext(False);
  end;
  CreateFindDialog := D;
end;

function CreateReplaceDialog: PDialog;
var
  D: PDialog;
  Control: PView;
  R: TRect;
begin
  R.Assign(0, 0, 40, 16);
  D := New(PDialog, Init(R, 'Replace'));
  with D^ do
  begin
    Options := Options or ofCentered;

    R.Assign(3, 3, 34, 4);
    Control := New(PInputLine, Init(R, 80));
    Insert(Control);
    R.Assign(2, 2, 15, 3);
    Insert(New(PLabel, Init(R, '~T~ext to find', Control)));
    R.Assign(34, 3, 37, 4);
    Insert(New(PHistory, Init(R, PInputLine(Control), 10)));

    R.Assign(3, 6, 34, 7);
    Control := New(PInputLine, Init(R, 80));
    Insert(Control);
    R.Assign(2, 5, 12, 6);
    Insert(New(PLabel, Init(R, '~N~ew text', Control)));
    R.Assign(34, 6, 37, 7);
    Insert(New(PHistory, Init(R, PInputLine(Control), 11)));

    R.Assign(3, 8, 37, 12);
    Insert(New(PCheckBoxes, Init(R,
      NewSItem('~C~ase sensitive',
      NewSItem('~W~hole words only',
      NewSItem('~P~rompt on replace',
      NewSItem('~R~eplace all', nil)))))));

    R.Assign(17, 13, 27, 15);
    Insert(New(PButton, Init(R, 'O~K~', cmOk, bfDefault)));
    R.Assign(28, 13, 38, 15);
    Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));

    SelectNext(False);
  end;
  CreateReplaceDialog := D;
end;

function DoEditDialog(Dialog: Integer; Info: Pointer): Word; far;
var
  R: TRect;
  T: TPoint;
begin
  case Dialog of
    edOutOfMemory:
      DoEditDialog := MessageBox('Not enough memory for this operation.',
        nil, mfError + mfOkButton);
    edReadError:
      DoEditDialog := MessageBox('Error reading file %s.',
        @Info, mfError + mfOkButton);
    edWriteError:
      DoEditDialog := MessageBox('Error writing file %s.',
        @Info, mfError + mfOkButton);
    edCreateError:
      DoEditDialog := MessageBox('Error creating file %s.',
        @Info, mfError + mfOkButton);
    edSaveModify:
      DoEditDialog := MessageBox('%s has been modified. Save?',
        @Info, mfInformation + mfYesNoCancel);
    edSaveUntitled:
      DoEditDialog := MessageBox('Save untitled file?',
        nil, mfInformation + mfYesNoCancel);
    edSaveAs:
      DoEditDialog := ExecDialog(New(PFileDialog, Init('*.*',
        'Save file as', '~N~ame', fdOkButton, 101)), Info);
    edFind:
      DoEditDialog := ExecDialog(CreateFindDialog, Info);
    edSearchFailed:
      DoEditDialog := MessageBox('Search string not found.',
        nil, mfError + mfOkButton);
    edReplace:
      DoEditDialog := ExecDialog(CreateReplaceDialog, Info);
    edReplacePrompt:
      begin
        { Avoid placing the dialog on the same line as the cursor }
        R.Assign(0, 1, 40, 8);
        R.Move((Desktop^.Size.X - R.B.X) div 2, 0);
        Desktop^.MakeGlobal(R.B, T);
        Inc(T.Y);
        if TPoint(Info).Y <= T.Y then
          R.Move(0, Desktop^.Size.Y - R.B.Y - 2);
        DoEditDialog := MessageBoxRect(R, 'Replace this occurence?',
          nil, mfYesNoCancel + mfInformation);
      end;
  end;
end;

function OpenEditor(FileName: FNameStr; Visible: Boolean): PEditWindow;
var
  P: PView;
  R: TRect;
begin
  DeskTop^.GetExtent(R);
  P := Application^.ValidView(New(PEditWindow,
    Init(R, FileName, wnNoNumber)));
  if not Visible then P^.Hide;
  DeskTop^.Insert(P);
  OpenEditor := PEditWindow(P);
end;

constructor TEditorApp.Init;
var
  H: Word;
  R: TRect;
begin
{  H := PtrRec(HeapEnd).Seg - PtrRec(HeapPtr).Seg;
  if H > HeapSize then BufHeapSize := H - HeapSize else BufHeapSize := 0;}
  BufHeapSize := 525;
  InitBuffers;
  MaxBufMem := 0;
  TApplication.Init;
  DisableCommands([cmSave, cmSaveAs, cmCut, cmCopy, cmPaste, cmClear,
    cmUndo, cmFind, cmReplace, cmSearchAgain]);
  EditorDialog := DoEditDialog;
  ClipWindow := OpenEditor('', False);
  if ClipWindow <> nil then
  begin
    Clipboard := ClipWindow^.Editor;
    Clipboard^.CanUndo := False;
  end;
  RuleBase.Init;
end;

destructor TEditorApp.Done;
begin
  TApplication.Done;
  DoneBuffers;
  RuleBase.Done;
end;

procedure TEditorApp.HandleEvent(var Event: TEvent);

procedure FileOpen;
var
  FileName: FNameStr;
begin
  FileName := '*.DAT';
  if ExecDialog(New(PFileDialog, Init('*.DAT', 'Open file',
    '~N~ame', fdOpenButton, 100)), @FileName) <> cmCancel then
    OpenEditor(FileName, True);
end;

function Exists(Tuple: PString; PossValues: PCollection; DbValues: PCollection): Boolean;
{* check to see if the possible values have already been inserted into the
   possible values list or already exist in the database *}
var
  DbItemsCount,
  PossValuesCount : Integer;
  Str : PString;
begin
  for PossValuesCount := 0 to PossValues^.Count-1 do
  begin
    Str := PossValues^.At(PossValuesCount);
    if Str^ <> '' then
      if Str^ = Tuple^ then
      begin
        Exists := True;
        Exit;
      end; { if }
  end; { for }

  for DbItemsCount := 0 to DbValues^.Count-1 do
  begin
    Str := DbValues^.At(DbItemsCount);
    if Str^ <> '' then
      if Str^ = Tuple^ then
      begin
        Exists := True;
        Exit;
      end; { if }
  end; { for }
  Exists := False;
end;

procedure GeneratePossibleValueList(PossVal : PCollection; DbList : PCollection);
{* Generate all possible combinations of tuples and place into the list,
   ensuring that the tuples are not already in the database list *}
var
  RuleCount,
  CondCount,
  ConsCount : Integer;
  Tuple : PString;
  Temp : String[TupleLen];
  Sub : Integer;
begin
  for RuleCount := 0 to MaxRules-1 do
    for CondCount := 0 to MaxCond-1 do
      if RuleBase.Rules[RuleCount].Conditions[CondCount].Tuple.Identifier <> '' then
      begin
        Tuple := NewStr(RuleBase.Rules[RuleCount].Conditions[CondCount].Tuple.Identifier + ' ' +
                            RuleBase.Rules[RuleCount].Conditions[CondCount].Tuple.Value);
        Temp := Tuple^;
        Sub := 1;
        Temp := GetWordStr(Temp, Sub);
        if RuleBase.ItsQuestion(Temp) then
          if not(Exists(Tuple, PossVal, DbList)) then { search the database and the }
            PossVal^.Insert(Tuple);      { contents of the PossVal list }
      end;
end;

procedure GenerateDbList(List : PCollection);
{* place the contents of the database into the List in the form of a string *}
var
  Count : Integer;
  Tuple : PString;
begin
  for Count := 0 to MaxDbItems-1 do
    if RuleBase.DataBase.Db[Count].Identifier <> '' then
      begin
      Tuple := NewStr(RuleBase.DataBase.Db[Count].Identifier + ' ' +
                                       RuleBase.DataBase.Db[Count].Value);
      List^.Insert(Tuple);
      end;
end;

procedure CopyDbDialogDataToDataBase(DbList : PCollection);
{* Copy Dialog database information back into the database in its proper
   format *}
var
  DbListCount : Integer;
  Str : PString;
  NormalStr : String[TupleLen];
  Id : String[MaxIdentifierLength];
  Val : String[MaxValueLength];
  Position : Integer;
begin
  Id := '';
  Val := '';
  RuleBase.DataBase.ResetDataBase;
  for DbListCount := 0 to DbList^.Count-1 do
  begin
    Position := 1;
    Str := DbList^.At(DbListCount);
    NormalStr := Str^;
    Id := GetWordStr(NormalStr, Position);
    Val := GetWordStr(NormalStr, Position);
    RuleBase.DataBase.LoadDb(False, Id, Val);
  end;
end;

procedure DoEditDataBaseDialog;
var
  Temp : PString;
  TempDialog : PDialog;
  Control : Word;
  DbEditDialogData : DbEditRecord;
begin
  DbEditDialogData.PossibleValueInputLine := '<Not Initialised>';
  DbEditDialogData.PossibleValueList := New(PCollection, Init(0,0));
  DbEditDialogData.PossibleValueList^.SetLimit(200);
  DbEditDialogData.DbContentsInputLine := '<Not Initialised>';
  DbEditDialogData.DbContentsList := New(PCollection, Init(0,0));
  DbEditDialogData.DbContentsList^.SetLimit(100);
  GenerateDbList(DbEditDialogData.DbContentsList);
  GeneratePossibleValueList(DbEditDialogData.PossibleValueList, DbEditDialogData.DbContentsList);
  TempDialog := New(PDbEditDialog, Init('Database Editor', 1, 1));
  if TempDialog <> nil then
  begin
    TempDialog^.SetData(DbEditDialogData);
    TempDialog := PDialog(Application^.ValidView(TempDialog));
    Control := DeskTop^.ExecView(TempDialog);
    if Control <> cmCancel then
    begin
      TempDialog^.GetData(DbEditDialogData);
      CopyDbDialogDataToDataBase(DbEditDialogData.DbContentsList);
    end;
  end
  else
    MessageBox('Dialog failed, Out of memory', nil, mfError + mfOkButton);
  {Dispose(TempDialog, Done);}
end;

procedure GenerateGoalList(var List : PCollection);
{* Place all of the possible goals for the backward chainer into given list
   goals are defined as all identifiers which appear in the consequence part
   of a rule *}
var
  RuleCount,
  ConsCount : Integer;
  Tuple : PString;
  DbList : PCollection;
begin
  DbList := New(PCollection, Init(0, 0));
  DbList^.SetLimit(200);
  GenerateDbList(DbList);
  for RuleCount := 0 to MaxRules-1 do
    for ConsCount := 0 to MaxCons-1 do
      if RuleBase.Rules[RuleCount].Consequences[ConsCount].Identifier <> '' then
      begin
        Tuple := NewStr(RuleBase.Rules[RuleCount].Consequences[ConsCount].Identifier + ' ' +
                            RuleBase.Rules[RuleCount].Consequences[ConsCount].Value);
        if not(Exists(Tuple, List, DbList)) then { search the database and the }
          List^.Insert(Tuple);      { contents of the PossVal list }
      end;
end; { GenerateGoalList }
 
procedure DoBackChainGoalDialog;
{* draw the dialog box to find the required goal for the backward chainer *}
var
  TempDialog : PDialog;
  Control : Word;
begin
  GoalDialogData.GoalInputLine := '<Not Initialised>';
  GoalDialogData.PossibleGoalList := New(PCollection, Init(0,0));
  GoalDialogData.PossibleGoalList^.SetLimit(200);
  GenerateGoalList(GoalDialogData.PossibleGoalList);
  TempDialog := New(PBackChainGoalDialog, Init('Define Goal', 1, 1));
  if TempDialog <> nil then
  begin
    TempDialog^.SetData(GoalDialogData);
    TempDialog := PDialog(Application^.ValidView(TempDialog));
    Control := DeskTop^.ExecView(TempDialog);
    if Control <> cmCancel then
      TempDialog^.GetData(GoalDialogData);
  end
  else
    MessageBox('Dialog failed, Out of memory', nil, mfError + mfOkButton);
  {Dispose(TempDialog, Done);}
end;

procedure FileNew;
begin
  OpenEditor('', True);
end;

procedure ChangeDir;
begin
  ExecDialog(New(PChDirDialog, Init(cdNormal, 0)), nil);
end;

procedure DosShell;
begin
  DoneSysError;
  DoneEvents;
  DoneVideo;
  DoneMemory;
  SetMemTop(Ptr(BufHeapPtr, 0));
  PrintStr('Type EXIT to return to TVEDIT...');
  SwapVectors;
  Exec(GetEnv('COMSPEC'), '');
  SwapVectors;
  SetMemTop(Ptr(BufHeapEnd, 0));
  InitMemory;
  InitVideo;
  InitEvents;
  InitSysError;
  Redraw;
end;

procedure ShowClip;
begin
  ClipWindow^.Select;
  ClipWindow^.Show;
end;

procedure Tile;
var
  R: TRect;
begin
  Desktop^.GetExtent(R);
  Desktop^.Tile(R);
end;

procedure Cascade;
var
  R: TRect;
begin
  Desktop^.GetExtent(R);
  Desktop^.Cascade(R);
end;

procedure DummyRoutine;
begin
  MessageBox('Not Implemented Yet.... Sorry !',
        nil, mfInformation + mfOkButton);
end;

function GetBuff: PEditBuffer;
var
  A : PEditWindow;
  TempPtr : Word;
begin
  A := Message(DeskTop, evBroadcast, cmFindEditor, nil);
  TempPtr := A^.Editor^.CurPtr; {* save cursor position *}
  A^.Editor^.SetCurPtr(A^.Editor^.BufSize, 0);
  A^.Editor^.SetCurPtr(0, 0);  {* go to the beginning *}
  A^.Editor^.SetCurPtr(TempPtr, 0); {* go to original place *}
  GetBuff := A^.Editor^.Buffer;  {* return the buffer *}
end;

function GetBufLen: Word;
var
  A : PEditWindow;
begin
  A := Message(DeskTop, evBroadcast, cmFindEditor, nil);
  GetBufLen := A^.Editor^.BufSize;  {* return the buffer length *}
end;

function GetCurPos: Word;
var
  A : PEditWindow;
begin
  A := Message(DeskTop, evBroadcast, cmFindEditor, nil);
  GetCurPos := A^.Editor^.CurPtr;  {* return the buffer length *}
end;

var
  Goal : SingleIdentifier;
  A, B : Longint;
begin
  TApplication.HandleEvent(Event);
  case Event.What of
    evCommand:
      case Event.Command of
        cmOpen: FileOpen;
        cmNew: FileNew;
        cmChangeDir: ChangeDir;
        cmDosShell: DosShell;
        cmShowClip: ShowClip;
        cmTile: Tile;
        cmCascade: Cascade;
        cmDefQuestions: DummyRoutine;
        cmMakeForm: DummyRoutine;
        cmAccept:
        begin
          RuleBase.Done;
          RuleBase.ParseRules(GetBuff, GetBufLen, GetCurPos);
          c := MaxAvail;
        end; { Accept }
        cmForwardChain: RuleBase.ForwardChain;
        cmBackwardChain: RuleBase.BackChain(GoalDialogData.GoalInputLine);
        cmExamineDataBase: RuleBase.DataBase.ViewDb;
        cmExamineDb: DoEditDataBaseDialog;
        cmDefineGoal: DoBackChainGoalDialog;
        cmResetSystem: RuleBase.ResetSystem;
        cmBreakpoint: DummyRoutine;
        cmWatchPoint: DummyRoutine;
        cmInfMechOptions: DummyRoutine;
        cmTraceSetting: DummyRoutine;
        cmEditorHelp : DummyRoutine;
        cmExpertHelp : DummyRoutine;
      else
        Exit;
      end;
  else
    Exit;
  end;
  ClearEvent(Event);
end;

procedure TEditorApp.InitMenuBar;
var
  R: TRect;
begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('~O~pen...', 'F3', kbF3, cmOpen, hcNoContext,
      NewItem('~N~ew', '', kbNoKey, cmNew, hcNoContext,
      NewItem('~S~ave', 'F2', kbF2, cmSave, hcNoContext,
      NewItem('S~a~ve as...', '', kbNoKey, cmSaveAs, hcNoContext,
      NewLine(
      NewItem('~C~hange dir...', '', kbNoKey, cmChangeDir, hcNoContext,
      NewItem('~D~OS shell', '', kbNoKey, cmDosShell, hcNoContext,
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil))))))))),
    NewSubMenu('~E~dit', hcNoContext, NewMenu(
      NewItem('~U~ndo', '', kbNoKey, cmUndo, hcNoContext,
      NewLine(
      NewItem('Cu~t~', 'Shift-Del', kbShiftDel, cmCut, hcNoContext,
      NewItem('~C~opy', 'Ctrl-Ins', kbCtrlIns, cmCopy, hcNoContext,
      NewItem('~P~aste', 'Shift-Ins', kbShiftIns, cmPaste, hcNoContext,
      NewItem('~S~how clipboard', '', kbNoKey, cmShowClip, hcNoContext,
      NewLine(
      NewItem('~C~lear', 'Ctrl-Del', kbCtrlDel, cmClear, hcNoContext,
      nil))))))))),
    NewSubMenu('~S~earch', hcNoContext, NewMenu(
      NewItem('~F~ind...', '', kbNoKey, cmFind, hcNoContext,
      NewItem('~R~eplace...', '', kbNoKey, cmReplace, hcNoContext,
      NewItem('~S~earch again', 'F4', kbF4, cmSearchAgain, hcNoContext,
      nil)))),
    NewSubMenu('~B~uild', hcNoContext, NewMenu(
      NewItem('~D~efine Questions...', '', kbNoKey, cmDefQuestions, hcNoContext,
      NewItem('~C~onstruct Form...', '', kbNoKey, cmMakeForm, hcNoContext,
      NewLine(
      NewItem('~A~ccept!', '', kbNoKey, cmAccept, hcNoContext,
      nil))))),
    NewSubMenu('~Q~uery', hcNoContext, NewMenu(
      NewItem('~F~orward Chain', '', kbNoKey, cmForwardChain, hcNoContext,
      NewItem('~B~ackward Chain', '', kbNoKey, cmBackwardChain, hcNoContext,
      NewItem('~E~dit Database...', '', kbNoKey, cmExamineDb, hcNoContext,
      NewItem('~D~efine Goal...', '', kbNoKey, cmDefineGoal, hcNoContext,
      NewLine(
      NewItem('~R~eset System...', '', kbNokey, cmResetSystem, hcNoContext,
      nil))))))),
    NewSubMenu('~D~ebug', hcNoContext, NewMenu(
      NewItem('~E~xamine Database...', '', kbNoKey, cmExamineDataBase, hcNoContext,
      NewLine(
      NewItem('~B~reakpoint...', '', kbNoKey, cmBreakpoint, hcNoContext,
      NewItem('~W~atchpoint...', '', kbNoKey, cmWatchpoint, hcNoContext,
      nil))))),
    NewSubMenu('~O~ptions', hcNoContext, NewMenu(
      NewItem('~I~nference Mechanisms...', '', kbNoKey, cmInfMechOptions, hcNoContext,
      NewItem('~T~race on', '', kbNoKey, cmTraceSetting, hcNoContext,
      nil))),
    NewSubMenu('~W~indow', hcNoContext, NewMenu(
      NewItem('~S~ize/move','Ctrl-F5', kbCtrlF5, cmResize, hcNoContext,
      NewItem('~Z~oom', 'F5', kbF5, cmZoom, hcNoContext,
      NewItem('~T~ile', '', kbNoKey, cmTile, hcNoContext,
      NewItem('C~a~scade', '', kbNoKey, cmCascade, hcNoContext,
      NewItem('~N~ext', 'F6', kbF6, cmNext, hcNoContext,
      NewItem('~P~revious', 'Shift-F6', kbShiftF6, cmPrev, hcNoContext,
      NewItem('~C~lose', 'Alt-F3', kbAltF3, cmClose, hcNoContext,
      NewLine(
      NewItem('~W~atch', '', kbNoKey, cmWatch, hcNoContext,
      NewItem('A~g~enda Spy', '', kbNoKey, cmSpy, hcNoContext,
      nil))))))))))),
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~E~ditor...', '', kbNoKey, cmEditorHelp, hcNoContext,
      NewItem('e~X~pert Systems', '', kbNoKey, cmExpertHelp, hcNoContext,
      nil))),
    nil))))))))))));
end;

procedure TEditorApp.InitStatusLine;
var
  R: TRect;
begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  New(StatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F2~ Save', kbF2, cmSave,
      NewStatusKey('~F3~ Open', kbF3, cmOpen,
      NewStatusKey('~Alt-F3~ Close', kbAltF3, cmClose,
      NewStatusKey('~F5~ Zoom', kbF5, cmZoom,
      NewStatusKey('~F6~ Next', kbF6, cmNext,
      NewStatusKey('~F10~ Menu', kbF10, cmMenu,
      NewStatusKey('', kbCtrlF5, cmResize,
      nil))))))),
    nil)));
end;

procedure TEditorApp.OutOfMemory;
begin
  MessageBox('Not enough memory for this operation.',
    nil, mfError + mfOkButton);
end;

const
  OverlayBufSize = 65000;
var
  Size1, Size2 : Longint;
  A : Word;
begin
  Size1 := MaxAvail;
  OvrInit('EXPERT.OVR');
  if OvrResult <> OvrOk then
  begin
    WriteLn('Fatal error in overlay manager');
    Halt(1);
  end; { if }
  OvrInitEMS;  {* How do you limit the amount of EMS this consumes *}
  if OvrResult <> OvrOk then
    WriteLn('No EMS memory available for the overlay buffer');
  OvrSetBuf(OverlayBufSize);
  if OvrResult <> OvrOk then
  begin
    WriteLn('Fatal error allocating overlay buffer space');
    Halt(1);
  end; { if }
  OvrSetRetry(OverlayBufSize div 3);
  if OvrResult <> OvrOk then
  begin
    WriteLn('Fatal error allocating overlay retry space');
    Halt(1);
  end; { if }
  Size2 := MaxAvail;
  WriteLn('Expert System Inference Mechanism Teaching Aid');
  WriteLn('Copyright (C) Jack Hughes 1991');
  Delay(1000);
  EditorApp.Init;
  EditorApp.Run;
  EditorApp.Done;
  Write('Total memory available to application: ');
  WriteLn(Size1);
  Write('Memory available to application after overlays loaded: ');
  WriteLn(Size2);
  Write('Heap space after rule base allocation is: ');
  WriteLn(c);
end. { Expert }
