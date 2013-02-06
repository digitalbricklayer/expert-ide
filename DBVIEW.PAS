unit dbview;
{* Temporary window for displaying the contents of the database *}

{$O+,D-}

interface
uses Overlay, Objects, Drivers, Views, Menus, App, expconst;

type
  PDbViewer = ^TDbViewer;
  TDbViewer = object(TWindow)
    constructor Init(Bounds: TRect; WinTitle: String; WindowNo: Word; DataBaseData : DbDataType; Num : Integer);
    procedure HandleEvent(var Event : TEvent); virtual;
  end;


  PInterior = ^TInterior;
  TInterior = object(TView)
    DbData : DbDataType;
    DbItemNum : Integer;
    constructor Init(var Bounds: TRect);
    procedure Draw; virtual;
    procedure HandleEvent(var Event : TEvent); virtual;
  end;

implementation

{ TInterior }
constructor TInterior.Init(var Bounds: TRect);
begin
  TView.Init(Bounds);
  GrowMode := gfGrowHiX + gfGrowHiY;
  Options := Options or ofFramed;
end;

procedure TInterior.HandleEvent(var Event : TEvent);
begin
  TView.HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmDummy) then
    ClearEvent(Event);
end;

procedure TInterior.Draw;
var
  Color: Byte;
  X: Integer;
  B: TDrawBuffer;
begin
  TView.Draw;
  Color := 2;
  for X := 0 to DbItemNum-1 do
  begin
    WriteStr(1, X, 'Identifier ', Color);
    WriteStr(12, X, DbData[X].Identifier, Color);
    WriteStr(30, X, 'Value ', Color);
    WriteStr(36, X, DbData[X].Value, Color);
  end;
end;

{ TDemoWindow }
constructor TDbViewer.Init(Bounds: TRect; WinTitle: String; WindowNo: Word; DataBaseData : DbDataType; Num : Integer);
var
  S: string[3];
  Interior: PInterior;
begin
  Str(WindowNo, S);
  TWindow.Init(Bounds, 'DataBase Viewer', wnNoNumber);
  GetClipRect(Bounds);
  Bounds.Grow(-1, -1);
  Interior := New(PInterior, Init(Bounds));
  Interior^.DbData := DataBaseData;
  Interior^.DbItemNum := Num;
  Insert(Interior);
end;

procedure TDbViewer.HandleEvent(var Event : TEvent);
begin
  TWindow.HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Command = cmDummy) then
    ClearEvent(Event);
end;

end. { dbview }