unit r_base;
{****************************************************************************}
{                               Rule Base Object                             }
{****************************************************************************}
{*
   RBase contains a sorted list of rules, the rules are sorted on the number
   of conditions that a particular rule contains. This sorting is done in
   order to facilitate Specificity conflict resolution.
*}

{$X+,D-,V-,O+,F+}

interface

uses Overlay, Objects, editors, expconst, d_base, expagend, rulehan, OddDlg;

const
  FileNameSize = 13;
  Cond = 0;
  Either = 2;
  Cons = 1;
  MissingToken = 3;
  NoValue = 4;

type
  ExpToken = array [0..2] of String[10];

  RBasePtr = ^RBase;  { rule base object definition }
  RBase = object(TObject)
    DataBase : DBase;
    Agenda : AgendaObject;
    Rules : array [0..MaxRules-1] of Rule;
    RuleNum : Integer;
    RuleSub : Integer; { subscript of currently active rule (used by
                         backward chainer) }
    constructor Init;
    destructor Done; virtual;
    procedure ParseRules(Buffer : PEditBuffer; BufferLen : Word;
                         CursorPos : Word); { parse rules }
    procedure BackChain(GoalStr : String);   { backward chaining routine }
    procedure Backward;
    procedure ForwardChain; { forward chaining routine }
    function ItemsInRb: Integer;
    function ItsQuestion(Identifier : String): Boolean;
    procedure ResetSystem;
    procedure GenerateQuestionValueList(Identifier : String;
                                        var List : PCollection);
    procedure DoQuestionDialog(Identifier : String);
  private
    function FindRule(Id : String; Val : String): Integer;
    function DbHoldsGoal(Id : String; Val : String): Integer;
    function CompareDbItems(Cond : CondArray; Cons : ConsArray;
                            CondNum : Integer): Boolean;
    function GetRuleSub(Id : String; Val : String): Integer;
    function TryDisproveRule(NumRule : Integer): Boolean;
    function ProveRule(Rule : Integer): Boolean;
    procedure MarkRulesInactive(Rule : Integer; Id : String; Val : String);
    procedure PutConditionOnAgenda(Rule : Integer);
    function GoalSatisfied(Id , Val : String): Boolean;
    function GoalExists(Id : String; Val : String): Boolean;
    function ValueExists(Id, Val : String): Boolean;
  end;

function GetWordStr(Source: String; var SubScript : Integer): String;

implementation
{****************************************************************************}
{                    Start of implementation section                         }
{****************************************************************************}
uses MsgBox, Views, App, Drivers, Memory, Dialogs;

type
  ErrorCode = (NoError, TooBigId, TooBigVal, BadToken, MissingVal);

const
  Yes = 2;
  No = 1;
  Almost = 0;
  Fail = -1;

constructor RBase.Init;
var
  Count : Integer;
begin
  for Count := 0 to MaxRules-1 do
    Rules[Count].Initialise;
  RuleNum := 0;
  DataBase.Init;
  Agenda.Init;
end; { Init }

destructor RBase.Done;
var
  Count : Integer;
begin
  Agenda.Done;
  DataBase.Done;
  for Count := 0 to MaxRules-1 do
    Rules[Count].Done;
  RuleNum := 0;
end; { Done }

{****************************************************************************}
{                               Parser                                       }
{****************************************************************************}

function GetGapLen: Word;
var
  A : PEditWindow;
begin
  A := Message(DeskTop, evBroadcast, cmFindEditor, nil);
  GetGapLen := A^.Editor^.GapLen;  {* return the buffer length *}
end;

procedure GetSpaceBack(Buffer : PEditBuffer;
                       var CursorPos : Word;
                       CurrentCurPos : Word;
                       GapLen : Integer);
var
  EndOfGap : Integer;
begin
  EndOfGap := CurrentCurPos + GapLen;
  while (not(Buffer^[CursorPos] in WordChars)) and not(CursorPos = 0) do
    begin
    if CursorPos = EndOfGap then
      CursorPos := CursorPos - GapLen;
    Dec(CursorPos);
    end; { while }
    if CursorPos >= EndOfGap then
      CursorPos := CursorPos - GapLen;
end; { GetWordBack }


function PreviousWord(Buffer : PEditBuffer;
                       var CursorPos : Word;
                       CurrentCurPos : Word): Word;
var
  GapLen : Integer;
  EndOfGap : Integer;
begin
  GapLen := GetGapLen;
  EndOfGap := CurrentCurPos + GapLen;
  GetSpaceBack(Buffer, CursorPos, CurrentCurPos, GapLen);
  while (Buffer^[CursorPos] in WordChars) and not(CursorPos = 0) do
    begin
    if CursorPos = EndOfGap then
      CursorPos := CursorPos - GapLen;
    Dec(CursorPos);
    end; { while }
  if CursorPos = EndOfGap then
    CursorPos := CursorPos - GapLen;
  PreviousWord := CursorPos;
end; { PreviousWord }

procedure DisplayError(Buffer : PEditBuffer;
                       ErrorMessage : String;
                       CursorPos : Word;
                       CurrentCurPos : Word);
var
  A : PEditWindow;
begin
  A := Message(DeskTop, evBroadcast, cmFindEditor, nil);
  A^.Editor^.SetCurPtr(PreviousWord(Buffer, CursorPos, CurrentCurPos), 0);
  A^.Editor^.TrackCursor(False);
  MessageBox(ErrorMessage, nil, mfError + mfOkButton);
end; { DisplayError }
 
procedure GetSpace(Buffer : PEditBuffer;
                   var CurrentPos : Integer;
                   BufferLen : Word;
                   var LineCount : Integer;
                   var Counter : Integer;
                   CursorPos : Word);
var
  CrFlag : Boolean;
  GapLen : Integer;
begin
  while (not(Buffer^[CurrentPos] in WordChars)) and (Counter < Integer(BufferLen)) do
    begin
    if CurrentPos = CursorPos then
      begin
      GapLen := GetGapLen;
      CurrentPos := CurrentPos + GapLen;
      Counter := Counter + GapLen;
      if CurrentPos = BufferLen then
        Exit;
      end;
    if Buffer^[CurrentPos] = #13 then
      CrFlag := True
    else if (Buffer^[CurrentPos] = #10) and (CrFlag) then
      Inc(LineCount);
    Inc(CurrentPos);
    Inc(Counter);
    end;
end; { GetSpace }

function CompareToken(Actual : String; Expected : ExpToken): Integer;

var
  A : Integer;
  C : Integer;
begin
  for A := 0 to 2 do
  begin
    if Expected[A] = Actual then
      CompareToken := A;
  end;
end; { CompareToken }

procedure GetWord(Buffer : PEditBuffer;
                  var CurrentPos : Integer;
                  BufferLen : Word;
                  var Str : String;
                  var LineCount : Integer;
                  CursorPos : Word;
                  var Counter : Integer);
var
  Count : Integer;
  GapLen : Integer;
begin
  GapLen := GetGapLen;
  GetSpace(Buffer, CurrentPos, BufferLen, LineCount, Counter, CursorPos);
  Count := 1;
  while (Buffer^[CurrentPos] in WordChars) and (Counter < Integer(BufferLen)) do
  begin
    if CurrentPos = CursorPos then
      begin
      CurrentPos := CurrentPos + GapLen;
      Counter := Counter + GapLen;
      if (Buffer^[CurrentPos] in WordChars) and
          (CurrentPos < Integer(BufferLen)) then
        begin
        Insert(Buffer^[CurrentPos], Str, Count);
        Inc(Count); Inc(CurrentPos); Inc(Counter);
        end;
      end
    else
      begin
      Insert(Buffer^[CurrentPos], Str, Count);
      Inc(Count); Inc(CurrentPos); Inc(Counter);
      end;
  end; { while }
end;

function GetToken(Buffer : PEditBuffer;
                  var CurrentPos : Integer;
                  BufferLen : Word;
                  var LineCount : Integer;
                  ExpectedToken : String;
                  CursorPos : Word;
                  var Counter : Integer): Integer;

var
  Str : String[10];
  ExpectedTokens : ExpToken;
  Temp : Integer;
begin
  Temp := CurrentPos;
  Str := '';
  GetWord(Buffer, Temp, BufferLen, Str, LineCount, CursorPos, Counter);
  CurrentPos := Temp;
  if (Str = ExpectedToken) or (Str = 'and') then
    begin
    ExpectedTokens[0] := 'if';
    ExpectedTokens[1] := 'then';
    ExpectedTokens[2] := 'and';
    GetToken := CompareToken(Str, ExpectedTokens);
    Exit;
    end
  else
    begin
    if not(Str = '') then
      begin
      GetToken := MissingToken;
      Exit;
      end;
    end;
end; { GetToken }

 
function GetIdentifier(Buffer : PEditBuffer;
                       var Temp : Integer;
                       var Identifier : String;
                       BufferLen : Word;
                       var LineCount : Integer;
                       CursorPos : Word;
                       var Counter : Integer): ErrorCode;
var
  AnotherTemp : Integer;
begin
  AnotherTemp := Temp;
  Identifier := '';
  GetWord(Buffer, AnotherTemp, BufferLen, Identifier, LineCount, CursorPos,
              Counter);
  Temp := AnotherTemp;
  if (Length(Identifier) > MaxIdentifierLength) then
    GetIdentifier:= TooBigId
  else if (Length(Identifier) = 0) then
    GetIdentifier := MissingVal
  else
    GetIdentifier := NoError;
end; { GetIdentifier }


function GetValue(Buffer : PEditBuffer;
                  var Temp : Integer;
                  var Value : String;
                  BufferLen : Word;
                  var LineCount : Integer;
                  CursorPos : Word;
                  var Counter : Integer): ErrorCode;
var
  AnotherTemp : Integer;
begin
  AnotherTemp := Temp;
  Value := '';
  GetWord(Buffer, AnotherTemp, BufferLen, Value, LineCount, CursorPos,
             Counter);
  Temp := AnotherTemp;
  if (Length(Value) > MaxValueLength)  then
    GetValue := TooBigVal
  else if (Length(Value) = 0) then
    GetValue := MissingVal
  else
    GetValue := NoError;
end; { GetValue }

function GetTuple(Buffer : PEditBuffer;
                  var CurrentPos : Integer;
                  var Identifier : String;
                  var Value : String;
                  BufferLen : Word;
                  var LineCount : Integer;
                  CursorPos : Word;
                  var Counter : Integer): ErrorCode;
var
  Result : ErrorCode;
begin
  Result := GetIdentifier(Buffer, CurrentPos, Identifier, BufferLen,
                           LineCount, CursorPos, Counter);
  case Result of
    TooBigId :
      begin
      GetTuple := TooBigId;
      Exit;
      end;
    MissingVal :
      begin
      GetTuple := MissingVal;
      Exit;
      end;
    end;
  Result := GetValue(Buffer, CurrentPos, Value, BufferLen,
                          LineCount, CursorPos, Counter);
  case Result of
    TooBigVal :
      begin
      GetTuple := TooBigVal;
      Exit;
      end;
    MissingVal :
      begin
      GetTuple := MissingVal;
      Exit;
      end;
    end;
  GetTuple := NoError;
end; { GetConsequence }

procedure NoErrorHandle(var Rule : Rule;
                        var CondNum : Integer;
                        Identifier : String;
                        Value : String;
                        var TokenFlag : Boolean;
                        var NextRuleFlag : Boolean);
begin
  Inc(CondNum);
  Rule.Conditions[CondNum-1].Tuple.Identifier := Identifier;
  Rule.Conditions[CondNum-1].Tuple.Value := Value;
  Rule.CondNum := CondNum;
  TokenFlag := True;
  NextRuleFlag := True;
end; { NoErrorHandle }

function GetRule(Buffer : PEditBuffer;
                 var CurrentPos : Integer;
                 BufSize : Word;
                 var Rule : Rule;
                 var LineCount : Integer;
                 CursorPos : Word;
                 var Counter : Integer): Boolean;
var
  CondNum,  {* Number of conditions in a rule *}
  ConsNum,  {* number of consequences in a rule *}
  TokenCode : Integer;  {* code denoting the type of flag currently being used *}
  TokenFlag : Boolean; {* was the previous flag a condition *}
  Identifier : String[80];
  Value : String[80];
  TrueId : String[MaxIdentifierLength];
  TrueValue : String[MaxValueLength];
  NextRuleFlag : Boolean;
  Status : ErrorCode;
  A : PEditWindow;
  C : TPoint;
  ExpectedToken : String[4];
begin
  {* initialise everything *}
  CondNum := 0;
  ConsNum := 0;
  TokenCode := 0;
  TokenFlag := True;
  NextRuleFlag := False;
  ExpectedToken := 'if';

  {* Start the parsing *}
  while (Counter < BufSize) do
  begin
    TokenCode := GetToken(Buffer, CurrentPos, BufSize,
                           LineCount, ExpectedToken, CursorPos, Counter);
    case TokenCode of
      Cond :
        begin
        if not(NextRuleFlag) then
          begin
          Status := GetTuple(Buffer, CurrentPos, Identifier, Value,
                              BufSize, LineCount, CursorPos, Counter);
          if Status = NoError then
            begin
            TrueId := Identifier;
            TrueValue := Value;
            NoErrorHandle(Rule, CondNum, TrueId, TrueValue, TokenFlag, NextRuleFlag);
            ExpectedToken := 'then';
            end
          else if Status = TooBigVal then
            begin
            DisplayError(Buffer, 'Too many characters in this Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end
          else if Status = TooBigId then
            begin
            DisplayError(Buffer, 'Too many characters in this Identifier', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end
          else if Status = MissingVal then
            begin
            DisplayError(Buffer, 'Missing Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end;
          end
        else
          begin
          CurrentPos := CurrentPos - 2;
          Counter := Counter - 2;
          if Status = NoError then
            GetRule := True
          else
            GetRule := False;
          Exit;
          end; { else }
        end;
      Cons :
        begin
          Status := GetTuple(Buffer, CurrentPos, Identifier, Value,
                               BufSize, LineCount, CursorPos, Counter);
          if Status = NoError then
            begin
            TrueId := Identifier;
            TrueValue := Value;
            Inc(ConsNum);
            Rule.Consequences[ConsNum-1].Identifier := Identifier;
            Rule.Consequences[ConsNum-1].Value := Value;
            NextRuleFlag := True;
            TokenFlag := False;
            ExpectedToken := 'if';
            end
          else if Status = TooBigVal then
            begin
            DisplayError(Buffer, 'Too many characters in this Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end
          else if Status = TooBigId then
            begin
            DisplayError(Buffer, 'Too many characters in this Identifier', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end
          else if Status = MissingVal then
            begin
            DisplayError(Buffer, 'Missing Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end;
      end; { Cons }
      Either :
        begin
        if TokenFlag then
          begin
          Status := GetTuple(Buffer, CurrentPos, Identifier, Value,
                               BufSize, LineCount, CursorPos, Counter);
          if Status = NoError then
            begin
            TrueId := Identifier;
            TrueValue := Value;
            Inc(CondNum);
            Rule.Conditions[CondNum-1].Tuple.Identifier := Identifier;
            Rule.Conditions[CondNum-1].Tuple.Value := Value;
            Rule.CondNum := CondNum;
            end
          else if Status = TooBigVal then
            begin
            DisplayError(Buffer, 'Too many characters in this Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end
          else if Status = TooBigId then
            begin
            DisplayError(Buffer, 'Too many characters in this Identifier', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end
          else if Status = MissingVal then
            begin
            DisplayError(Buffer, 'Missing Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
            end;
          end
        else
        begin
          Status := GetTuple(Buffer, CurrentPos, Identifier, Value,
                              BufSize, LineCount, CursorPos, Counter);
          if Status = NoError then
          begin
            TrueId := Identifier;
            TrueValue := Value;
            Inc(ConsNum);
            Rule.Consequences[ConsNum-1].Identifier := Identifier;
            Rule.Consequences[ConsNum-1].Value := Value;
          end
          else if Status = TooBigVal then
          begin
            DisplayError(Buffer, 'Too many characters in this Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
          end
          else if Status = TooBigId then
          begin
            DisplayError(Buffer, 'Too many characters in this Identifier', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
          end
          else if Status = MissingVal then
          begin
            DisplayError(Buffer, 'Missing Value', CurrentPos, CursorPos);
            GetRule := False;
            Exit;
          end;
        end;
      end; { Either }
      MissingToken :
      begin
        DisplayError(Buffer, 'Token missing', CurrentPos, CursorPos);
        GetRule := False;
        Exit;
      end;
     end;
    end; { while }
    GetRule := True;
    Exit;
end; { GetRule }

procedure RBase.ParseRules(Buffer : PEditBuffer;
                           BufferLen : Word;
                           CursorPos : Word);
{* Parse the rule base from the given edit buffer,
   carrying out relevent checks *}
var
  TempRule : Rule;
  RuleCount : Integer;
  CurrentPos : Integer;
  Result : ErrorCode;
  LineCount : Integer;
  Success : Boolean;
  RuleCountStr : String[3];
  DialogStr : String[80];
  Counter : Integer;
  BufferSize : Integer;
begin
  Counter := 0; CurrentPos := 0; RuleCount := 0; LineCount := 1;
  while (RuleNum < MaxRules) and (Counter < Integer(BufferLen)) do
  begin
    TempRule.Initialise;
    Success := GetRule(Buffer, CurrentPos, BufferLen, TempRule, LineCount, CursorPos, Counter);
    if Success then
    begin
      Rules[RuleNum] := TempRule;
      Inc(RuleNum);
    end
    else
    begin
      TempRule.Done;
      Exit;
    end;
  end; { while }
  if Counter <= BufferLen then
  begin
    Str(RuleNum, RuleCountStr);
    DialogStr :=  'Rule base successfully parsed.       ' + RuleCountStr + ' Rules loaded';
    MessageBox(DialogStr, nil, mfInformation + mfOkButton);
  end;
end; { ParseRules }


{****************************************************************************}
{                               Backward Chainer                             }
{****************************************************************************}

function RBase.ValueExists(Id, Val : String): Boolean;
{* Does the tuple exist on the rulebase *}
var
  RuleCount,
  ConsCount : Integer;
begin
  for RuleCount := 0 to RuleNum-1 do
    for ConsCount := 0 to MaxCons-1 do
      if Rules[RuleCount].Consequences[ConsCount].Identifier <> '' then
      begin
        if ((Rules[RuleCount].Consequences[ConsCount].Identifier = Id) and
            (Rules[RuleCount].Consequences[ConsCount].Value = Val)) then
        begin
          ValueExists := True;
          Exit;
        end;
      end;
  ValueExists := False;
end; { ValueExist }

function RBase.GoalExists(Id : String; Val : String): Boolean;
{* Does the current Tuple exist in any of the consequences of the rules *}

begin
  if (not(ItsQuestion(Id)) and (ValueExists(Id, Val))) then
    GoalExists := True
  else
    GoalExists := False;
end; { GoalExists }

procedure RBase.GenerateQuestionValueList(Identifier : String; var List : PCollection);
{* Generate a list of all values relevant to the given identifier *}
var
  RuleCount,
  CondCount : Integer;
  Value : PString;
  UsedValues : TValueArrayObject;
begin
  UsedValues.Init;
  for RuleCount := 0 to MaxRules-1 do
    for CondCount := 0 to MaxCond-1 do
      if Rules[RuleCount].Conditions[CondCount].Tuple.Identifier = Identifier then
      begin
        Value := NewStr(Rules[RuleCount].Conditions[CondCount].Tuple.Value);
        if not(UsedValues.SeenBefore(Value^)) then
        begin
          List^.Insert(Value);
          UsedValues.SetItem(Value^);
        end;
      end;
  UsedValues.Done;
end; { GenerateQuestionValueList }

procedure RBase.DoQuestionDialog(Identifier : String);
{* draw the question dialog box *}
var
  TempDialog : PDialog;
  QuestionDialogData : QuestionRecord;
  Control : Word;
begin
  QuestionDialogData.AnswerInputLine := '<Not Initialised>';
  QuestionDialogData.PossibleAnswerList := New(PCollection, Init(0,0));
  QuestionDialogData.PossibleAnswerList^.SetLimit(200);
  GenerateQuestionValueList(Identifier, QuestionDialogData.PossibleAnswerList);
  TempDialog := New(PQuestionDialog, Init('Define Goal', Identifier, 1, 1));
  if TempDialog <> nil then
  begin
    TempDialog^.SetData(QuestionDialogData);
    TempDialog := PDialog(Application^.ValidView(TempDialog));
    Control := DeskTop^.ExecView(TempDialog);
    if Control <> cmCancel then
    begin
      TempDialog^.GetData(QuestionDialogData);
      if ((QuestionDialogData.AnswerInputLine <> '') or
          (QuestionDialogData.AnswerInputLine <> '<Not Initialised>')) then
        DataBase.LoadDb(True, Identifier, QuestionDialogData.AnswerInputLine);
    end;
  end
  else
    MessageBox('Dialog failed, Out of memory', nil, mfError + mfOkButton);
  {Dispose(TempDialog, Done);}
end;

procedure RBase.MarkRulesInactive(Rule : Integer; Id : String; Val : String);
var
  RuleCount,
  CondCount : Integer;
begin
  Rules[Rule].TryFlag := True;

  for RuleCount := 0 to MaxRules-1 do
    for CondCount := 0 to MaxCond-1 do
      if not(Rules[RuleCount].TryFlag) then
        if ((Rules[RuleCount].Conditions[CondCount].Tuple.Identifier = Id) and
            (Rules[RuleCount].Conditions[CondCount].Tuple.Value = Val)) then
          Rules[RuleCount].TryFlag := True;
end; { MarkRulesInactive }

function RBase.ProveRule(Rule : Integer): Boolean;
{* Given a rule, try to prove a rule by using the database *}
var
  CondCount,
  DbCount,
  SuccessCount : Integer;
begin
  SuccessCount := 0;
  for CondCount := 0 to MaxCond-1 do
    if Rules[Rule].Conditions[CondCount].Tuple.Identifier <> '' then
      for DbCount := 0 to MaxDbItems-1 do
        if ((Rules[Rule].Conditions[CondCount].Tuple.Identifier = DataBase.Db[DbCount].Identifier) and
            (Rules[Rule].Conditions[CondCount].Tuple.Value = DataBase.Db[DbCount].Value)) then
          Inc(SuccessCount);
  if SuccessCount = Rules[Rule].CondNum then
    ProveRule := True
  else
    ProveRule := False;
end; { ProveRule }

function RBase.DbHoldsGoal(Id : String; Val : String): Integer;
var
  DbCount : Integer;
begin
  for DbCount := 0 to MaxDbItems-1 do
    if ((Id = DataBase.Db[DbCount].Identifier) and (Val = DataBase.Db[DbCount].Value)) then
    begin
      DbHoldsGoal := Yes;
      Exit;
    end
    else
      if Id = DataBase.Db[DbCount].Identifier then
      begin
        DbHoldsGoal := Almost;
        Exit;
      end;
  DbHoldsGoal := No;
end; { DbHoldsGoal }

procedure RBase.PutConditionOnAgenda(Rule : Integer);
var
  CondCount : Integer;
begin
  for CondCount := 0 to MaxCond-1 do
    if not(Rules[Rule].Conditions[CondCount].ConditionFlag) then
    begin
      if Rules[Rule].Conditions[CondCount].Tuple.Identifier <> '' then
      begin
        Agenda.Push(Rules[Rule].Conditions[CondCount].Tuple.Identifier,
                    Rules[Rule].Conditions[CondCount].Tuple.Value);
        Rules[Rule].Conditions[CondCount].ConditionFlag := True;
        Exit;
      end;
    end;
end; { PutConditionOnAgenda }

function RBase.GetRuleSub(Id : String; Val : String): Integer;
var
  RuleCount,
  ConsCount : Integer;
begin
  for RuleCount := 0 to RuleNum-1 do
    if not(Rules[RuleCount].TryFlag) then
      for ConsCount := 0 to MaxCons-1 do
        if ((Id = Rules[RuleCount].Consequences[ConsCount].Identifier) and
            (Val = Rules[RuleCount].Consequences[ConsCount].Value)) then
        begin
          GetRuleSub := RuleCount;
          Exit;
        end;
  GetRuleSub := Fail;
end; { GetRuleSub }

function RBase.FindRule(Id : String; Val : String): Integer;
var
  Result : Integer;
begin
  Result := GetRuleSub(Id, Val);
  if Result = Fail then
  begin
    FindRule := Fail;
    Exit;
  end
  else
    if TryDisproveRule(Result) then
    begin
      Rules[Result].TryFlag := True;
      FindRule := FindRule(Id, Val);
    end
    else
      FindRule := Result;
end; { FindRule }

function RBase.TryDisproveRule(NumRule : Integer): Boolean;
var
  CondNum,
  Result : Integer;
begin
  for CondNum := 0 to MaxCond-1 do
    if Rules[NumRule].Conditions[CondNum].Tuple.Identifier <> '' then
    begin
      Result := DbHoldsGoal(Rules[NumRule].Conditions[CondNum].Tuple.Identifier,
                            Rules[NumRule].Conditions[CondNum].Tuple.Value);
      if Result = Almost then
      begin
        TryDisproveRule := True;
        Exit;
      end;
    end;
  TryDisproveRule := False;
end; { TryDisproveRule }

procedure RBase.Backward;
{* low level backward chaining routine *}
var
  Action,
  Result : Integer;
begin
  Action := DbHoldsGoal(Agenda.GetIdentifier, Agenda.GetValue);
  case Action of
    Yes :
    begin
      Agenda.Pop;
      if not(Agenda.Empty) then  { Have all goals been satisfied }
      begin
        Rules[RuleSub].LiveFlag := False;
        Backward;
      end;
    end; { Yes }
    No :
    begin
      Result := FindRule(Agenda.GetIdentifier, Agenda.GetValue);
      if Result = Fail then
        if ItsQuestion(Agenda.GetIdentifier) then
        begin
          DoQuestionDialog(Agenda.GetIdentifier);
          Backward;
        end
        else
        begin
          MarkRulesInactive(RuleSub, Agenda.GetIdentifier, Agenda.GetValue);
          Rules[RuleSub].LiveFlag := False;
          Agenda.Pop;
          if not(Agenda.Empty) then
            Backward;
        end
      else
      begin
        RuleSub := Result;
        if ProveRule(RuleSub) then
        begin
          DataBase.Fire(Rules[RuleSub].Consequences);
          Backward;
        end
        else
        begin
          PutConditionOnAgenda(RuleSub);
          Rules[RuleSub].LiveFlag := True;
          Backward;
        end;
      end;
    end; { No }
    Almost :
    begin
      MarkRulesInactive(RuleSub, Agenda.GetIdentifier, Agenda.GetValue);
      Rules[RuleSub].LiveFlag := False;
      Agenda.Pop;
      if not(Agenda.Empty) then
        Backward;
    end; { Almost }
  end;
end; { Backward }

function GetWordStr(Source: String; var SubScript : Integer): String;
{* return word from the source *}
var
  Count : Integer;
  Pos : Integer;
  Dest : String[MaxIdentifierLength];
  SourceLength : Integer;
begin
  Dest := '';
  Pos := 1;
  SourceLength := Length(Source);
  for Count := SubScript to SourceLength do
  begin
    if not(Source[Count] in WordChars) then
    begin
      GetWordStr := Dest;
      Inc(SubScript);
      Exit;
    end
    else
    begin
      Dest := Dest + Source[Count];
      Inc(Pos);
      Inc(SubScript);
    end;
  end;
  GetWordStr := Dest;
end;

function RBase.GoalSatisfied(Id , Val : String): Boolean;
var
  Status : Integer;
begin
  Status := DbHoldsGoal(Id, Val);
  if Status = Yes then
  begin
    GoalSatisfied := True;
    Exit;
  end
  else
  begin
    GoalSatisfied := False;
    Exit;
  end;
end; { GoalSatisfied }

procedure RBase.BackChain(GoalStr : String);
{* Top level backward chainer, parameter represents desired goal *}
var
  Id : String[MaxIdentifierLength];
  Val : String[MaxValueLength];
  Position : Integer;
  DialogStr : String[80];
begin
  Position := 1; Id := ''; Val := '';
  Id := GetWordStr(GoalStr, Position);
  Val := GetWordStr(GoalStr, Position);
  if GoalExists(Id, Val) then
  begin
    Agenda.Init;
    Agenda.Push(Id, Val);
    Backward;
    {* if goal is satisfied, tell the user about it *}
    if GoalSatisfied(Id, Val) then
    begin
      DialogStr :=  'Satisfied Goal ' + '"' + Id + ' ' + Val + '"';
      MessageBox(DialogStr, nil, mfInformation + mfOkButton);
    end
    else
    begin
      DialogStr :=  'Unable to satisfy goal ' + '"' + Id + ' ' + Val + '"';
      MessageBox(DialogStr, nil, mfInformation + mfOkButton);
    end;
  end
  else
  begin
    DialogStr :=  'Invalid Goal ' + '"' + Id + ' ' + Val + '"';
    MessageBox(DialogStr, nil, mfInformation + mfOkButton);
  end;
end; { BackChain }

{****************************************************************************}
{                               Forward Chainer                              }
{****************************************************************************}


function RBase.CompareDbItems(Cond : CondArray; Cons : ConsArray; CondNum : Integer): Boolean;
{* given conditions from a rule, try to prove all of the conditions on
   the database *}
var
  CondCount : Integer;
  Matches : Integer;
  Status : Integer;
begin
  Matches := 0;
  for CondCount := 0 to CondNum-1 do
  begin
    Status := DbHoldsGoal(Cond[CondCount].Tuple.Identifier,
                          Cond[CondCount].Tuple.Value);
    if Status = Yes then
    begin
      Inc(Matches);
      if Matches = CondNum then
      begin
        DataBase.Fire(Cons);
        CompareDbItems := True;
        Exit;
      end;
    end
    else
    begin
      CompareDbItems := False;
      Exit;
    end;
  end; { for }
end; { CompareDbItems }

procedure RBase.ForwardChain;
{* Forward chaining routine *}
var
  Rle : Rule;
  RuleCount : Integer;
  ContinueFlag : Boolean;
  NumRules : Integer;
  FireCount : Integer;
  FireCountStr : String[10];
  MessageStr : String[80];
begin
  FireCount := 0;
  if DataBase.ItemsInDb <= 0 then
  begin
    MessageBox('Database is empty, cannot forward chain', nil, mfError + mfOkButton);
    Exit;
  end;
  ContinueFlag := True; RuleCount := 0;
  NumRules := RuleNum;
  while ((ContinueFlag) and (RuleCount <> NumRules-1)) do
  begin
    NumRules := ItemsInRb;
    while RuleCount < NumRules-1 do
    begin
      Rle.Initialise; Rle := Rules[RuleCount];
      if not(Rle.FireFlag) then
      begin
        ContinueFlag := CompareDbItems(Rle.Conditions, Rle.Consequences, Rle.CondNum);
        if ContinueFlag then
        begin
          Rle.FireFlag := True;
          Rules[RuleCount] := Rle;
          RuleCount := -1;
          Inc(FireCount);
        end;
      end;
      Inc(RuleCount);
      Rle.Done;
    end; { while }
  end; { while }
  if FireCount <= 0 then
    MessageBox('          No Rules Fired', nil, mfInformation + mfOkButton)
  else
  begin
    Str(FireCount, FireCountStr);
    MessageStr :=  '    ' + FireCountStr + ' Rules successfully fired';
    MessageBox(MessageStr, nil, mfInformation + mfOkButton);
  end;
end; { Forward }

function RBase.ItemsInRb: Integer;
{* return the number of items in the rule base *}
begin
  ItemsInRb := RuleNum;
end; { ItemsInRb }

function RBase.ItsQuestion(Identifier : String): Boolean;
{* Return true if the identifier is a question (ie a leaf node) false
   otherwise *}
var
  RuleCount,
  ConsCount : Integer;
begin
  for RuleCount := 0 to RuleNum-1 do
    for ConsCount := 0 to MaxCons-1 do
      if Identifier = Rules[RuleCount].Consequences[ConsCount].Identifier then
      begin
        ItsQuestion := False;
        Exit;
      end;
  ItsQuestion := True;
end; { ItsQuestion }

procedure RBase.ResetSystem;
{* Reset Agenda and Database and reset all flags in the rulebase *}
var
  RuleCount,
  CondCount : Integer;
begin
  DataBase.Init;
  Agenda.Init;
  for RuleCount := 0 to RuleNum-1 do
  begin
    Rules[RuleCount].FireFlag := False;
    Rules[RuleCount].LiveFlag := False;
    Rules[RuleCount].TryFlag := False;
    for CondCount := 0 to MaxCond-1 do
      Rules[RuleCount].Conditions[CondCount].ConditionFlag := False;
  end;
  DataBase.UpdateDbWin;
end; { ResetSystem }

end. { of r_base }