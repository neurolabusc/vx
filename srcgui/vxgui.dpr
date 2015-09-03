program vxgui;

uses
  Forms,
  main in 'main.pas' {Form1},
  glpanel in 'glpanel.pas';

{$R delphi.res}

begin
  Application.Initialize;
  Application.Title := 'vxgui';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
