unit RuleHan;
{* Handler for Rule object, Rules are placed in the
   RuleBase Sorted Collection *}

{$O+,F+,D-}

interface
uses Overlay, expconst, Objects;

type
  RulePtr = ^Rule;
  Rule = object(TObject)
    CondNum : Integer;
    FireFlag : Boolean;
    TryFlag : Boolean;
    LiveFlag : Boolean;
    Conditions : CondArray;
    Consequences : ConsArray;
    constructor Initialise;
    destructor Done; virtual;
  end; { Rule }

implementation

constructor Rule.Initialise;
var
  A : Integer;
begin
  TObject.Init;
  CondNum := 0;
  FireFlag := False;
  TryFlag := False;
  LiveFlag := False;
  {* Initialise conditions *}
  for A := 0 to MaxCond-1 do
  begin
    Conditions[A].Tuple.Identifier := '';
    Conditions[A].Tuple.Value := '';
    Conditions[A].ConditionFlag := False;
  end; { for }
  {* initialise consequences *}
  for A := 0 to MaxCons-1 do
  begin
    Consequences[A].Identifier := '';
    Consequences[A].Value := '';
  end; { for }
end; { Initialise }

destructor Rule.Done;
var
  A : Integer;
begin
  {* Get rid of consequences *}
  for A := MaxCons-1 downto 0 do
  begin
    Consequences[A].Identifier := '';
    Consequences[A].Value := '';
  end; { for }
  {* Get rid of conditions *}
  for A := MaxCond-1 downto 0 do
  begin
    Conditions[A].Tuple.Identifier := '';
    Conditions[A].Tuple.Value := '';
    Conditions[A].ConditionFlag := False;
  end; { for }
  CondNum := 0;
  TObject.Done;
end; { Done }

end. { RuleHan }