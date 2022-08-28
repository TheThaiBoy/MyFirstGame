(* project settings:
  {#include
    source = "$(project_root)source"
  #}
*)
program Myproject1;

uses
  Gen2MP,
  GameUnit;

begin
  Game := TGame.Create;
  g2.Start;
end.