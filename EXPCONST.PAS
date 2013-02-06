unit expconst;
{* Constant definitions for Expert system shell *}
{$D-}

interface
uses Objects, StdDlg, Dialogs, Views, Drivers, Dos;
const
  MaxCond = 5;
  MaxCons = 3;
  MaxIdentifierLength = 30;
  MaxValueLength = 30;
  MaxRules = 100;
  MaxDbItems = 20;
  cmDataBaseWinExists = 200;
  cmDummy = 4000;
  TupleLen = ((MaxIdentifierLength + MaxValueLength)+1);
  MaxTuple = 1;
  MaxValuesForId = 10;

type

  UsedValueType = array [0..MaxValuesForId-1] of String[MaxValueLength];
  Ident = String[MaxIdentifierLength];
  Val = String[MaxValueLength];

  SingleIdentifier = record        { single identifier value tuple }
    Identifier : Ident;
    Value : Val;
  end; { SingleIdentifier }

  Cond = record                    { condition record }
    Tuple : SingleIdentifier;
    ConditionFlag : Boolean;
  end; { Cond }

  CondArray = array[0..MaxCond-1] of Cond;

  ConsArray = array[0..MaxCons-1] of SingleIdentifier;

  TupleArray = array [0..MaxTuple-1] of String[61];

  TupleObjectPtr = ^TupleObject;
  TupleObject = object(TObject)
    Identifier : String[MaxIdentifierLength];
    Value : String[MaxValueLength];
    QuestionFlag : Boolean;
    constructor Init;
    constructor Initialise(Id, Val : String; QuestFlag : Boolean);
    destructor Done; virtual;
  end; { TupleObject }
  DbDataType = array [0..MaxDbItems-1] of TupleObject;

  TValueArrayObject = object(TObject)
    Items : array [0..MaxValuesForId-1] of String[MaxValueLength];
    InsertPoint : Integer;
    constructor Init;
    destructor Done; virtual;
    procedure SetItem(Item : String);
    function SeenBefore(Item : String): Boolean;
  end; { TValuArrayObject }

implementation

constructor TValueArrayObject.Init;
var
  Count : Integer;
begin
  for Count := 0 to MaxValuesForId-1 do
    Items[Count] := '';
  InsertPoint := 0;
end; { Init }

destructor TValueArrayObject.Done;
var
  Count : Integer;
begin
  for Count := 0 to MaxValuesForId-1 do
    Items[Count] := '';
  InsertPoint := 0;
end; { Init }

procedure TValueArrayObject.SetItem(Item : String);
begin
  Items[InsertPoint] := Item;
  Inc(InsertPoint);
end; { Insert }

function TValueArrayObject.SeenBefore(Item : String): Boolean;
var
  Count : Integer;
begin
  for Count := 0 to MaxValuesForId-1 do
    if Items[Count] = Item then
    begin
      SeenBefore := True;
      Exit;
    end;
  SeenBefore := False;
end; { SeenBefore }

constructor TupleObject.Init;
{* Copy fields from Temp into 'myself' *}
begin
  Identifier := '';
  Value := '';
  QuestionFlag := False;
end;

constructor TupleObject.Initialise(Id, Val : String; QuestFlag : Boolean);
{* Allocate string fields in TupleObject *}
begin
  Identifier := Id;
  Value := Val;
  QuestionFlag := QuestFlag;
end; { Init }

destructor TupleObject.Done;
{* Deallocate string fields in TupleObject *}
begin
  QuestionFlag := False;
  if not(Value = '') then
    Value := '';
  if not(Identifier = '') then
    Identifier := '';
end; { Done }

end. { expconst }