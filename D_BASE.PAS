
{* Database Object *}

unit d_base;

{$O+,F+,D-}

interface

uses Overlay, Objects, expconst, dbview, Views, App;

type

  DBasePtr = ^DBase;
  DBase = object(TObject)
    Db : DbDataType;
    NumItemsInDb : Integer;
    constructor Init;
    destructor Done; virtual;
    procedure ResetDatabase;
    procedure Fire(Consequences : ConsArray);
    procedure LoadDb(Question : Boolean; Id : String; Valu : String);
    procedure DestroyPreviousValue(Identifier : Ident);
    function ItemsInDb: Integer;
    function FindSpaceOnDb(var Sub : Integer) : Boolean;
    procedure UpDateDbWin;
    procedure ViewDb;
  end; { DBase }

implementation

{****************************************************************************}
{*                                                                          *}
{*                    Start of implementation section                       *}
{*                                                                          *}
{****************************************************************************}
uses Drivers;

constructor DBase.Init;
{* Initialise database *}
var
  X : Integer;
begin
  for X := 0 to MaxDbItems-1 do
    Db[X].Init;
  NumItemsInDb := 0;
end; { Init }

destructor DBase.Done;
{* Dispose of the database *}
var
  X : Integer;
begin
  for X := 0 to MaxDbItems-1 do
    Db[X].Done;
  NumItemsInDb := 0;
end; { Done }
  
function GetDataBaseWin : PDbViewer;
var
  Z : PDbViewer;
begin
  Z := Message(DeskTop, evBroadcast, cmDummy, nil);
  GetDataBaseWin := Z;
end;

procedure DBase.UpdateDbWin;
var
  D : PDbViewer;
  E : PView;
begin
  D := GetDataBaseWin;
  if D <> nil then { ie there is a database viewer window }
  begin
    E := D^.First;  { get the window interior }
    PInterior(E)^.DbData := Db;
    PInterior(E)^.DbItemNum := NumItemsInDb;
    E^.Draw; { redraw the interior }
  end;
end;

procedure DBase.ViewDb;
{* Temporary solution to see internals of the database *}
var
  DataBaseWin : PDbViewer;
  R : TRect;
  DBContents : DbDataType;
  Count : Integer;
begin
  R.Assign(0, 0, 80, 5);
  New(DataBaseWin, Init(R, 'Database Viewer', 1, Db, NumItemsInDb));
  {Options := Options or ofTileable;}
  DeskTop^.Insert(DataBaseWin);
end;

function DBase.FindSpaceOnDb(var Sub : Integer):  Boolean;
{* Find the first free space on the database and place in Sub
   else return False *}
var
  Count : Integer;
begin
  for Count := 0 to MaxDbItems-1 do
    if Db[Count].Identifier = '' then
      begin
      Sub := Count;
      FindSpaceOnDb := True;
      Exit;
      end;
  FindSpaceOnDb := False;
end; { FindSpaceOnDb }

procedure DBase.ResetDatabase;
{* Deallocate the whole database *}
var
  Z : Integer;
begin
  for Z := 0 to MaxDbItems-1 do
    Db[Z].Done;
  NumItemsInDb := 0;
end; { ResetDatabase }
 
procedure DBase.Fire(Consequences : ConsArray);
{* Place all consequences of given rule onto the database *}
var
  ConsCount : Integer;
begin
  for ConsCount := 0 to MaxCons-1 do
    if not(Consequences[ConsCount].Identifier = '') then
      LoadDb(False, Consequences[ConsCount].Identifier,
                    Consequences[ConsCount].Value);
end; { Fire }

procedure DBase.LoadDb(Question : Boolean; Id : String; Valu : String);
{* Place given data at the end of the database *}
var
  Sub : Integer;
begin
  DestroyPreviousValue(Id);
  if FindSpaceOnDb(Sub) then
  begin
    Db[Sub].Initialise(Id, Valu, Question);
    Inc(NumItemsInDb);
    UpdateDbWin;
  end;
end; { LoadDb }

procedure ResetDbItem(DbItem : Integer);
{* Given a database subscript, reset all fields *}

begin

end; { ResetDbItem }

procedure DBase.DestroyPreviousValue(Identifier : Ident);
{* Given an identifier, go through the database and remove all
   occurrences of it *}
var
  Count : Integer;
begin
  for Count := 0 to MaxDbItems-1 do
    if Db[Count].Identifier = Identifier then
      begin
      Db[Count].Done;
      Dec(NumItemsInDb);
      Exit;
      end;
end; { DestroyPreviousValue }

function DBase.ItemsInDb: Integer;
{* Return the number of items in the database *}
begin
  ItemsInDb := NumItemsInDb;
end; { ItemsInDb }

end. { d_base }