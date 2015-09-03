program vxgui;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, 
  Forms, lazopenglcontext, main, colorTable
  { you can add units after this };

{$IFNDEF UNIX}{$R vxgui.res}{$ENDIF}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

