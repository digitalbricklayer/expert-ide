unit expagend;

{$F+,O+,D-}

interface
uses Overlay, expconst, Objects;

const
  SizeOfAgenda = 15;

type
  AgendaObject = object(TObject)
    Stack : array[0..SizeOfAgenda-1] of TupleObject;
    TopStack : Integer; { always points at the next insertion point }
    NumItems : Integer; { number of items in the agenda }
    constructor Init;
    destructor Done; virtual;
    function Empty: Boolean;
    procedure Pop;
    procedure Push(Id : String; Val : String);
    function GetIdentifier:String;
    function GetValue: String;
  end; { Agenda }

implementation

constructor AgendaObject.Init;
var
  Count : Integer;
begin
  TObject.Init;
  NumItems := 0;
  TopStack := SizeOfAgenda-1;
  for Count := 0 to SizeOfAgenda-1 do
    Stack[Count].Init;
end;

destructor AgendaObject.Done;
var
  Count : Integer;
begin
  TObject.Done;
  NumItems := 0;
  TopStack := SizeOfAgenda-1;
  for Count := 0 to SizeOfAgenda-1 do
    Stack[Count].Done;
end;

function AgendaObject.Empty: Boolean;
{* Test to see if the agenda is empty *}

begin
  if NumItems = 0 then
    Empty := True
  else
    Empty := False;
end; { AgendaEmpty }

procedure AgendaObject.Pop;
{* Remove top item from agenda *}
begin
  if ((NumItems > 0) and (NumItems < SizeOfAgenda)) then
  begin
    Inc(TopStack);
    Stack[TopStack].Done;
    Dec(NumItems);
  end;
end; { Pop }

procedure AgendaObject.Push(Id : String; Val : String);
{* Push given data onto the top of the agenda *}
begin
  if NumItems < SizeOfAgenda then
  begin
    Stack[TopStack].Identifier := Id;
    Stack[TopStack].Value := Val;
    Dec(TopStack);
    Inc(NumItems);
  end;
end; { Push }

function AgendaObject.GetIdentifier: String;
{* Return the top identifier without removing it *}
var
  Id : String[MaxIdentifierLength];
begin
  if ((NumItems > 0) and (NumItems < SizeOfAgenda)) then
    Id := Stack[TopStack+1].Identifier;
    GetIdentifier := Id;
end; { GetTuple }

function AgendaObject.GetValue: String;
{* Return the top identifier without removing it *}
var
  Val : String[MaxValueLength];
begin
  if ((NumItems > 0) and (NumItems < SizeOfAgenda)) then
    Val := Stack[TopStack+1].Value;
    GetValue := Val;
end; { GetTuple }

end. { Agenda }