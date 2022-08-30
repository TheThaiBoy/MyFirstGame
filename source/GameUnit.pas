unit GameUnit;

interface

uses
  Gen2MP,
  G2Types,
  G2Math,
  G2Utils,
  G2DataManager,
  G2Scene2D,
  Types,
  SysUtils,
  Classes,
  Math;

type
  { TBullet }

  TBullet = class (TG2Scene2DEntity)
  protected
    var LifeTime: TG2Float;
    procedure OnUpdate;
  public
    constructor Create(const OwnerScene: TG2Scene2D); override;
    destructor Destroy; override;
    procedure Start;
    procedure OnContact(const EventData: TG2Scene2DEventData);
  end;

  { TEnemy }

  TEnemy = class (TG2Scene2DEntity)
  private
    var Sensors: Integer;
    var AccelAmount: Single;
    procedure BeginSensor(const EventData: TG2Scene2DEventData);
    procedure EndSensor(const EventData: TG2Scene2DEventData);
    procedure OnUpdate;
  public
    constructor Create(const OwnerScene: TG2Scene2D); override;
    destructor Destroy; override;
    procedure Start;
  end;

  { TGame }

  TGame = class
  protected
  public
    var Scene: TG2Scene2D;
    var Display: TG2Display2D;
    var Box: TG2Scene2DEntity;
    var Gun: TG2Scene2DEntity;
    var Background: TG2Scene2DEntity;
    var GroundTouches: Integer;
    var Font1: TG2Font;
    var Enemy: TEnemy;
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    procedure Finalize;
    procedure Update;
    procedure Render;
    procedure KeyDown(const Key: Integer);
    procedure KeyUp(const Key: Integer);
    procedure MouseDown(const Button, x, y: Integer);
    procedure MouseUp(const Button, x, y: Integer);
    procedure Scroll(const y: Integer);
    procedure Print(const c: AnsiChar);
    procedure WheelBeginTouch(const EventData: TG2Scene2DEventData);
    procedure WheelEndTouch(const EventData: TG2Scene2DEventData);
  end;

var
  Game: TGame;

implementation

{ TEnemy }

procedure TEnemy.BeginSensor(const EventData: TG2Scene2DEventData);
begin
  Sensors += 1;
end;

procedure TEnemy.EndSensor(const EventData: TG2Scene2DEventData);
begin
  Sensors -= 1;
end;

procedure TEnemy.OnUpdate;
  var rb: TG2Scene2DComponentRigidBody;
  var lv: TG2Vec2;
  var av, t: TG2Float;
begin
  rb := TG2Scene2DComponentRigidBody(ComponentOfType[TG2Scene2DComponentRigidBody]);
  if Assigned(rb) then
  begin
    if Sensors > 0 then
    begin
      lv := rb.LinearVelocity;
      if lv.y > -4 then rb.ApplyForceToCenter(G2Vec2(0, -100));
    end;
    t := Power(Rotation.AxisY.Dot(G2Vec2(0, -1)) * 0.5 + 0.5, 3) * Sign(Rotation.AxisY.Dot(G2Vec2(1, 0)));
    av := Abs(rb.AngularVelocity);
    rb.ApplyTorque(G2LerpFloat(t, 0, G2Min(Power(av * 0.2, 5), 1)) * 200);
  end;
end;

constructor TEnemy.Create(const OwnerScene: TG2Scene2D);
begin
  inherited Create(OwnerScene);
  g2.CallbackUpdateAdd(@OnUpdate);
  Sensors := 0;
  AccelAmount := 0;
end;

destructor TEnemy.Destroy;
begin
  g2.CallbackUpdateRemove(@OnUpdate);
  inherited Destroy;
end;

procedure TEnemy.Start;
  var i: Integer;
  var rb: TG2Scene2DComponentRigidBody;
begin
  rb := TG2Scene2DComponentRigidBody(ComponentOfType[TG2Scene2DComponentRigidBody]);
  if Assigned(rb) then
  begin
    rb.Enabled := True;
  end;
  for i := 0 to ComponentCount - 1 do
  if Components[i] is TG2Scene2DComponentCollisionShapeBox then
  begin
    Components[i].AddEvent('OnBeginContact', @BeginSensor);
    Components[i].AddEvent('OnEndContact', @EndSensor);
  end;
end;

{ TBullet }

procedure TBullet.OnUpdate;
begin
  LifeTime += g2.DeltaTimeSec;
  if LifeTime > 4 then
  begin
    Enabled := False;
    Free;
  end;
end;

constructor TBullet.Create(const OwnerScene: TG2Scene2D);
begin
  inherited Create(OwnerScene);
  LifeTime := 0;
  g2.CallbackUpdateAdd(@OnUpdate);
end;

destructor TBullet.Destroy;
begin
  g2.CallbackUpdateRemove(@OnUpdate);
  inherited Destroy;
end;

procedure TBullet.Start;
  var rb: TG2Scene2DComponentRigidBody;
  var c: TG2Scene2DComponentCollisionShape;
begin
  rb := TG2Scene2DComponentRigidBody(ComponentOfType[TG2Scene2DComponentRigidBody]);
  if Assigned(rb) then
  begin
    rb.Enabled := True;
    rb.GravityScale := 0;
    rb.IsBullet := True;
    rb.ApplyForceToCenter(Rotation.AxisX * 100);
  end;
  AddEvent('OnBeginContact', @OnContact);
end;

procedure TBullet.OnContact(const EventData: TG2Scene2DEventData);
  var e: TG2Scene2DEntity;
  var p: TG2Scene2DComponentEffect;
  var Data: TG2Scene2DEventBeginContactData;
  var xf: TG2Transform2;
begin
  Data := TG2Scene2DEventBeginContactData(EventData);
  LifeTime := 100;
  xf := Transform;
  xf.p := Data.GetContactPoint;
  e := Scene.CreatePrefab('Damage.g2prefab2d', xf);
  p := TG2Scene2DComponentEffect(e.ComponentOfType[TG2Scene2DComponentEffect]);
  if Assigned(p) then
  begin
    p.Scale := 0.2;
    p.Speed := 2;
    p.AutoDestruct := True;
  end;
end;

//TGame BEGIN
constructor TGame.Create;
begin
  g2.CallbackInitializeAdd(@Initialize);
  g2.CallbackFinalizeAdd(@Finalize);
  g2.CallbackUpdateAdd(@Update);
  g2.CallbackRenderAdd(@Render);
  g2.CallbackKeyDownAdd(@KeyDown);
  g2.CallbackKeyUpAdd(@KeyUp);
  g2.CallbackMouseDownAdd(@MouseDown);
  g2.CallbackMouseUpAdd(@MouseUp);
  g2.CallbackScrollAdd(@Scroll);
  g2.CallbackPrintAdd(@Print);
  g2.Params.MaxFPS := 100;
  g2.Params.Width := 1024;
  g2.Params.Height := 768;
  g2.Params.ScreenMode := smMaximized;
end;

destructor TGame.Destroy;
begin
  g2.CallbackInitializeRemove(@Initialize);
  g2.CallbackFinalizeRemove(@Finalize);
  g2.CallbackUpdateRemove(@Update);
  g2.CallbackRenderRemove(@Render);
  g2.CallbackKeyDownRemove(@KeyDown);
  g2.CallbackKeyUpRemove(@KeyUp);
  g2.CallbackMouseDownRemove(@MouseDown);
  g2.CallbackMouseUpRemove(@MouseUp);
  g2.CallbackScrollRemove(@Scroll);
  g2.CallbackPrintRemove(@Print);
  inherited Destroy;
end;

procedure TGame.Initialize;
  var Entity: TG2Scene2DEntity;
begin
  Font1 := TG2Font.Create;
  Font1.Make(16);
  Scene := TG2Scene2D.Create;
  Scene.Load('floaty world with clouds.g2s2d');
  Display := TG2Display2D.Create;
  Display.Position := G2Vec2;
  Display.Width := 10;
  Display.Height := 10;
  Display.Zoom := 0.5;
  Background := Scene.FindEntityByName('background');
  Box := Scene.FindEntityByName('box');
  Gun := Scene.FindEntityByName('Gun');
  Entity := Scene.FindEntityByName('Wheel0');
  Entity.AddEvent('OnBeginContact', @WheelBeginTouch);
  Entity.AddEvent('OnEndContact', @WheelEndTouch);
  Entity := Scene.FindEntityByName('Wheel1');
  Entity.AddEvent('OnBeginContact', @WheelBeginTouch);
  Entity.AddEvent('OnEndContact', @WheelEndTouch);
  Scene.Simulate := True;
  Scene.EnablePhysics;
  Entity := Scene.FindEntityByName('EnemySpawner');
  if Assigned(Entity) then
  begin
    TEnemy(Scene.CreatePrefab('EnemyPrefab.g2prefab2d', Entity.Transform, TEnemy)).Start;
  end;
end;

procedure TGame.Finalize;
begin
  Scene.Free;
  Display.Free;
  Font1.Free;
  Free;
end;

procedure TGame.Update;
  var Wheel: TG2Scene2DEntity;
  var rb: TG2Scene2DComponentRigidBody;
  var Speed: TG2Float;
  var rot: TG2Rotation2;
  const Velocity = 10;
begin
  Display.Position := Box.Position;
  Background.Position := Display.Position;
  rot.AxisX := (Display.CoordToDisplay(g2.MousePos) - Gun.Position).Norm;
  Gun.Rotation := rot;
  if g2.KeyDown[G2K_a] then
  begin
    Speed := -Velocity;
  end
  else if g2.KeyDown[G2K_d] then
  begin
    Speed := Velocity;
  end
  else
  begin
    Speed := 0;
  end;
  if Abs(Speed) > 0.1 then
  begin
    Wheel := Scene.FindEntityByName('Wheel1');
    rb := TG2Scene2DComponentRigidBody(Wheel.ComponentOfType[TG2Scene2DComponentRigidBody]);
    rb.ApplyTorque(Speed);
    Wheel := Scene.FindEntityByName('Wheel0');
    rb := TG2Scene2DComponentRigidBody(Wheel.ComponentOfType[TG2Scene2DComponentRigidBody]);
    rb.ApplyTorque(Speed);
  end;
end;

procedure TGame.Render;
begin
  Scene.Render(Display);
  Font1.Print(10, 10, 'Touches = ' + IntToStr(GroundTouches));
end;

procedure TGame.KeyDown(const Key: Integer);
  var rb, rbw0, rbw1: TG2Scene2DComponentRigidBody;
  var Start, Wheel0, Wheel1: TG2Scene2DEntity;
  var j: TG2Scene2DRevoluteJoint;
  var Joints: array of TG2Scene2DRevoluteJoint;
  var i: Int32;
begin
  if (Key = G2K_Space) and (GroundTouches > 0) then
  begin
    rb := TG2Scene2DComponentRigidBody(Box.ComponentOfType[TG2Scene2DComponentRigidBody]);
    rb.ApplyForceToCenter(G2Vec2(0, -2000));
  end;
  if (Key = G2K_R) then
  begin
    Start := Scene.FindEntityByName('Start');
    Wheel0 := Scene.FindEntityByName('Wheel0');
    Wheel1 := Scene.FindEntityByName('Wheel1');
    if Assigned(Start) and Assigned(Wheel0) and Assigned(Wheel1) then
    begin
      rb := TG2Scene2DComponentRigidBody(Box.ComponentOfType[TG2Scene2DComponentRigidBody]);
      rbw0 := TG2Scene2DComponentRigidBody(Wheel0.ComponentOfType[TG2Scene2DComponentRigidBody]);
      rbw1 := TG2Scene2DComponentRigidBody(Wheel1.ComponentOfType[TG2Scene2DComponentRigidBody]);
      for i := 0 to Scene.JointCount - 1 do
      if Scene.Joints[i] is TG2Scene2DRevoluteJoint then
      begin
        j := TG2Scene2DRevoluteJoint(Scene.Joints[i]);
        if ((j.RigidBodyA = rbw0) and (j.RigidBodyB = rb))
        or ((j.RigidBodyA = rb) and (j.RigidBodyB = rbw0))
        or ((j.RigidBodyA = rbw1) and (j.RigidBodyB = rb))
        or ((j.RigidBodyA = rb) and (j.RigidBodyB = rbw1)) then
        begin
          SetLength(Joints, Length(Joints) + 1);
          Joints[High(Joints)] := j;
          j.Enabled := False;
        end;
      end;
      rbw0.Enabled := False;
      rbw1.Enabled := False;
      rb.Enabled := False;
      Box.Position := Start.Position;
      Box.Rotation := 0;
      rb.Enabled := True;
      rbw0.Enabled := True;
      rbw1.Enabled := True;
      for i := 0 to High(Joints) do
      begin
        Joints[i].Enabled := True;
      end;
    end;
  end;
end;

procedure TGame.KeyUp(const Key: Integer);
begin

end;

procedure TGame.MouseDown(const Button, x, y: Integer);
  var b: TBullet;
  var xf: TG2Transform2;
begin
  if Button = G2MB_Left then
  begin
    xf := Gun.Transform;
    xf.p := xf.p + Gun.Rotation.AxisX * 0.2;
    b := TBullet(Scene.CreatePrefab('Bullet.g2prefab2d', xf, TBullet));
    b.Start;
  end;
end;

procedure TGame.MouseUp(const Button, x, y: Integer);
begin

end;

procedure TGame.Scroll(const y: Integer);
begin

end;

procedure TGame.Print(const c: AnsiChar);
begin

end;

procedure TGame.WheelBeginTouch(const EventData: TG2Scene2DEventData);
  var Data: TG2Scene2DEventBeginContactData absolute EventData;
begin
  if Data.Entities[1].Name = 'ground' then
  begin
    Inc(GroundTouches);
  end;
end;

procedure TGame.WheelEndTouch(const EventData: TG2Scene2DEventData);
  var Data: TG2Scene2DEventEndContactData absolute EventData;
begin
  if Data.Entities[1].Name = 'ground' then
  begin
    Dec(GroundTouches);
  end;
end;
//TGame END

end.
