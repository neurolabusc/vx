unit main;
{$IFDEF FPC}
{$mode Delphi}
{$H+}
{$ENDIF}

interface

 {In Lazarus you may have to add OpenGLContext to your build:   objfpc
   1.) Choose menu item Package/InstallUnistallPackages
   2.) Double-click "LazOpenGLContext" from "Available to install"
   3.) Click button "Save and rebuild IDE"
}

//define TEXTURESLICE for viewer-aligned texture slicing (old), comment this out for (better) raycasting
//{$DEFINE TEXTURESLICE}

uses
  {$IFDEF FPC}fpimage, intfgraphics,GraphType, LResources, LCLProc,  LCLIntf, lcltype,OpenGLContext,{$ELSE} Windows,glpanel, {$ENDIF}
  Graphics, Classes, SysUtils, FileUtil, Forms, Buttons, Dialogs, Menus,
  Controls, ExtCtrls, colorTable, dglOpenGL,  Clipbrd,  {$IFDEF TEXTURESLICE}  textureslice {$ELSE} raycast {$ENDIF};
type
  { TForm1 }
  TForm1 = class(TForm)
    ColorDialog1: TColorDialog;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Color1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    Gradient1: TMenuItem;
    OpenNoGradients1: TMenuItem;
    Boundary1: TMenuItem;
    Perspective1: TMenuItem;
    Shade1: TMenuItem;
    OpenDialog1: TOpenDialog;
    Exit1: TMenuItem;
    Open1: TMenuItem;
    ErrorTimer1: TTimer;
    MenuRaycast: TMenuItem;
    MenuView: TMenuItem;
    MenuBackColor: TMenuItem;
    MenuQuality: TMenuItem;
    MenuSwitchMode: TMenuItem;
    Edit1: TMenuItem;
    Copy1: TMenuItem;
    procedure About1Click(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure ErrorTimerOnTimer(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure MenuQualityClick(Sender: TObject);
    procedure OpenNoGradients1Cick(Sender: TObject);
    procedure Boundary1Click(Sender: TObject);
    procedure GLboxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLboxMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure Gradient1Click(Sender: TObject);
    procedure Backcolor1Click(Sender: TObject);
    procedure Perspective1Click(Sender: TObject);
    procedure Shade1Click(Sender: TObject);
    procedure ShowSet;
    procedure Exit1Click(Sender: TObject);
    procedure ExitButton1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure GLboxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLboxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure GLboxPaint(Sender: TObject);
    procedure GLboxResize(Sender: TObject);
    procedure Color1Click(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    function ScreenShot: TBitmap;
    procedure SwitchModeClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;
var
  Form1: TForm1;

implementation

var
   MousePt: TPoint;
   updateGL : boolean = false;
   reloadGL : boolean = true;
{$IFDEF FPC}
        GLbox: TOpenGLControl;
        {$R *.lfm}
{$ELSE}
       GLbox : TGLPanel;
       {$R *.dfm}
{$ENDIF}

procedure TForm1.ExitButton1Click(Sender: TObject);
begin
     Close;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  {$IFDEF FPC}
  GLbox:= TOpenGLControl.Create(Form1);
  GLBox.OnMouseWheel:= GLboxMouseWheel;
  {$ELSE}
  GLBox := TGLPanel.Create(Form1);
  {$ENDIF}
  GLBox.OnResize:= GLboxResize;
  GLBox.OnPaint := GLboxPaint;
  GLBox.OnMouseDown := GLboxMouseDown;
  GLBox.OnMouseUp := GLboxMouseUp;
  GLBox.OnMouseMove := GLboxMouseMove;
  GLBox.Parent := Form1;
  GLBox.Align := alClient;
  GLBox.Parent := Form1;
  GLBox.Align := alClient;
  {$IFDEF Darwin}  //OSX users expect command not control key for shortcuts
    Open1.Shortcut := ShortCut(VK_O, [ssMeta]);
    OpenNoGradients1.Shortcut := ShortCut(VK_B, [ssMeta]);
    Exit1.Shortcut := ShortCut(VK_X, [ssMeta]);
    Color1.Shortcut := ShortCut(VK_T, [ssMeta]);
    Copy1.Shortcut := ShortCut(VK_C, [ssMeta]);
    Shade1.Shortcut := ShortCut(VK_S, [ssMeta]);
    Boundary1.Shortcut := ShortCut(VK_G, [ssMeta]);
    Perspective1.Shortcut := ShortCut(VK_P, [ssMeta]);
    MenuBackColor.Shortcut := ShortCut(VK_K, [ssMeta]);
  {$ENDIF}
  MousePt.X := -1;
  {$IFDEF TEXTURESLICE}
  MenuRaycast.visible := false;
  MenuQuality.Visible := false;
  MenuSwitchMode.Visible := false;
  {$ELSE}
  Shade1.Checked := not (edgeThresh = 1.0);
  {$ENDIF}
end;

procedure TForm1.GLboxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MousePt.X := X;
  MousePt.Y := Y;
end;

procedure Bound (var Val: integer; Min,Max: integer);
begin
     if Val < Min then
        Val := Min;
     if Val > Max then
        Val := Max;
end;

procedure TForm1.GLboxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
//left-drag: change viewpoint
//right-drag or shift-drag: change contrast/brightness
begin
  if MousePt.X < 1 then //only change if dragging mouse
     exit; //mouse button not down
  If (ssRight in Shift) or (ssShift in Shift) then begin //update color table
     {$IFNDEF TEXTURESLICE}
     if Gradient1.checked then begin
      Caption := 'Unable to change contrast/brightness when viewing gradients.';
      exit;
     end;
     LUTCenter := LUTCenter + (X-MousePt.X);
     Bound(LUTCenter,1,255);
     LUTWidth := LUTWidth + (MousePt.Y-Y);
     Bound(LUTWidth,1,255);
     UpdateTransferFunction (LUTindex,LUTCenter,LUTWidth, TransferTexture);
       {$ENDIF}
  end else begin
     Azimuth := (Azimuth + (X-MousePt.X)) mod 360;
     Elevation := Elevation + (Y-MousePt.Y);
     Bound(Elevation,-90,90);
  end;
  ShowSet;
  MousePt.X := X;
  MousePt.Y := Y;
  GLbox.Invalidate;
end;

procedure TForm1.ShowSet;
begin
    {$IFDEF TEXTURESLICE}
        Caption := 'Azimuth='+inttostr(Azimuth)+' Elevation='+inttostr(Elevation)+' Distance='+FloatToStrF(Distance, ffGeneral, 4, 1);
    {$ELSE}
     Caption := 'Contrast='+inttostr(LUTWidth)+' Brightness='+inttostr(LUTCenter)
     +' Distance='+FloatToStrF(Distance, ffGeneral, 4, 1)+' Azimuth='+inttostr(Azimuth)+' Elevation='+inttostr(Elevation);
    {$ENDIF}
end;

procedure TForm1.GLboxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MousePt.X := -1;
end;

procedure TForm1.About1Click(Sender: TObject);
const
  kSamp = 36;
var
  s: dword;
  i: integer;
begin
  s := gettickcount;
  for i := 1 to kSamp do begin
     Azimuth := (Azimuth + 10) mod 360;
    GLbox.Repaint;
  end;
  Showmessage('VXgui renderer 9/2015: drag to rotate, right-drag to change contrast, scrollwheel to zoom. FPS='+floattostr((kSamp*1000)/(gettickcount-s)) );
end;

procedure TForm1.ErrorTimerOnTimer(Sender: TObject);
begin
  ErrorTimer1.enabled := false;
  if length(Form1.Hint) > 0 then
     Showmessage(Form1.Hint)
  else
      Showmessage('Error: perhaps you need to upgrade your video card or driver');
end;

procedure TForm1.FormDropFiles(Sender: TObject; const FileNames: array of String);
begin
  OpenDialog1.filename := FileNames[Low(FileNames)];
  reloadGL := true;
 GLbox.Invalidate;
end;

procedure TForm1.MenuQualityClick(Sender: TObject);
begin
{$IFNDEF TEXTURESLICE}
  isQuality := not isQuality;
  MenuQuality.Checked := isQuality;
  GLbox.Invalidate;
{$ENDIF}
end;

procedure TForm1.OpenNoGradients1Cick(Sender: TObject);
begin
  {$IFNDEF TEXTURESLICE}
  if not OpenDialog1.execute then
    OpenDialog1.filename := '';
 loadGradients := false;
 reloadGL := true;
 if Boundary1.Checked then Boundary1.Click;
 if Gradient1.Checked then Gradient1.Click;
 GLbox.Invalidate;
 {$ENDIF}
end;

procedure TForm1.Boundary1Click(Sender: TObject);
begin
  {$IFNDEF TEXTURESLICE}
    if Boundary1.checked then
     boundExp := 1.5
  else
      boundExp := 0.0;
  GLbox.Invalidate;
   {$ENDIF}
end;

procedure TForm1.GLboxMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if Wheeldelta < 0 then
     Distance := Distance -0.1
  else
      Distance := Distance + 0.1;
  if Distance > kMaxDistance then
     Distance := kMaxDistance;
  if Distance < 1 then
     Distance := 1.0;
  Showset;
  GLbox.Invalidate;
end;

procedure TForm1.Gradient1Click(Sender: TObject);
begin
    {$IFNDEF TEXTURESLICE}
    if Gradient1.checked then
     showGradient := 1
  else
      showGradient := 0;
  GLbox.Invalidate;
  {$ENDIF}
end;

function RGB2Color (r,g,b: single) : TColor;
begin
  result := round(r*255)+round(g*255) shl 8 + round(b*255) shl 16;
end;

procedure Color2RGB (Color : TColor; var r,g,b: single);
begin
  r := (Color and $ff)/$ff;
  g := ((Color and $ff00) shr 8)/255;
  b := ((Color and $ff0000) shr 16)/255;
end;

procedure TForm1.Backcolor1Click(Sender: TObject);
begin
  If (ssShift in KeyDataToShiftState(vk_Shift)) then begin
    if ClearColor[1] < 0.5 then
      Color2RGB(RGB2Color(1,1,1),ClearColor[1],ClearColor[2],ClearColor[3])
    else
      Color2RGB(RGB2Color(0,0,0),ClearColor[1],ClearColor[2],ClearColor[3]);
    GLbox.Invalidate;
    exit;
  end;
  ColorDialog1.Color := RGB2Color(ClearColor[1],ClearColor[2],ClearColor[3]);
  if not ColorDialog1.Execute then
    exit;
  Color2RGB(ColorDialog1.Color,ClearColor[1],ClearColor[2],ClearColor[3]);
  GLbox.Invalidate;
end;

procedure TForm1.Perspective1Click(Sender: TObject);
begin
  {$IFNDEF TEXTURESLICE}
  isPerspective := Perspective1.checked;
  GLbox.Invalidate;
  {$ENDIF}
end;

procedure TForm1.Shade1Click(Sender: TObject);
begin
  {$IFNDEF TEXTURESLICE}
  if Shade1.checked then
     edgeThresh := 0.05
  else
      edgeThresh := 1.0;
  GLbox.Invalidate;
  {$ENDIF}
end;

procedure TForm1.Exit1Click(Sender: TObject);
begin
  Close;
end;

procedure TForm1.GLboxPaint(Sender: TObject);
var
   OK: boolean;
begin
  if updateGL or reloadGL then begin
      if reloadGL then
        OK := InitGL (OpenDialog1.filename, GLbox.Width, GLbox.Height)
      else
        OK := InitGL ('-', GLbox.Width, GLbox.Height);
      reloadGL := false;
      updateGL:=false;
      if not OK then ErrorTimer1.enabled := true;  //report error
  end;
  DisplayGL;
  GLbox.SwapBuffers;
end;

procedure TForm1.GLboxResize(Sender: TObject);
begin
    UpdateGL := true;
    GLbox.Invalidate;
end;

procedure TForm1.Color1Click(Sender: TObject);
begin
  {$IFNDEF TEXTURESLICE}
    inc(LUTindex);
    UpdateTransferFunction (LUTindex,LUTCenter,LUTWidth, TransferTexture);
    GLbox.Invalidate;
  {$ENDIF}
end;

procedure TForm1.Open1Click(Sender: TObject);
begin
  if not OpenDialog1.execute then
         OpenDialog1.filename := '';
  {$IFNDEF TEXTURESLICE}loadGradients := true;{$ENDIF}
  ReloadGL := true;
  GLbox.Invalidate;
end;

{$IFDEF FPC}
function TForm1.ScreenShot: TBitmap;
var
  p: array of byte;
  x, y: integer;
  w,h, BytePerPixel: int64;
  z:longword;
  RawImage: TRawImage;
  DestPtr: PInteger;
begin
  GLBox.MakeCurrent;
  GLboxPaint(self);
  w := GLbox.Width;
  h := GLbox.Height;
  Result:=TBitmap.Create;
  Result.Width:=w;
  Result.Height:=h;
  Result.PixelFormat := pf24bit; //if pf32bit the background color is wrong, e.g. when alpha = 0
  RawImage := Result.RawImage;
  //GLForm1.ShowmessageError('GLSL error '+inttostr(RawImage.Description.RedShift)+' '+inttostr(RawImage.Description.GreenShift) +' '+inttostr(RawImage.Description.BlueShift));
  BytePerPixel := RawImage.Description.BitsPerPixel div 8;
  Result.BeginUpdate(False);
  setlength(p, 4*w* h);
  //DisplayGL
  {$IFDEF Darwin} //http://lists.apple.com/archives/mac-opengl/2006/Nov/msg00196.html
  glReadPixels(0, 0, w, h, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8, @p[0]); //OSX-Darwin
  {$ELSE}
  glReadPixels(0, 0, w, h, GL_BGRA, GL_UNSIGNED_BYTE, @p[0]); //Linux-Windows
  {$ENDIF}
  z := 0;
  if BytePerPixel = 4 then begin
     for y:= (h-1) downto 0 do begin //is GetLineStart indexed from 1 or 0? Assuming latter to match Delphi scanline
        DestPtr := PInteger(RawImage.GetLineStart(y));
        System.Move(p[z], DestPtr^, w * BytePerPixel );
        z := z + ( w * 4 );
      end; //for y
    end else begin //below  BytePerPixel <> 4, e.g. Windows
      for y:= (h-1) downto 0  do begin
        DestPtr := PInteger(RawImage.GetLineStart(y));
        for x:=0 to w-1 do begin
          DestPtr^ := (p[z])+(p[z+1] shl 8)+(p[z+2]  shl 16);
          Inc(PByte(DestPtr), BytePerPixel);
          z := z + 4;
        end;
      end; //for y
    end; //if BytePerPixel = 4 else ...
    setlength(p, 0);
  Result.EndUpdate(False);
  GLbox.ReleaseContext;
end;
{$ELSE}
function TForm1.ScreenShot: TBitmap;
var
  p: array of byte;
  w, h, x, y, BytePerPixel: integer;
  z:longword;
  DestPtr: PInteger;
begin
  GLboxPaint(self);
  w := GLbox.Width;
  h := GLbox.Height;
  Result:=TBitmap.Create;
  Result.Width:=w;
  Result.Height:=h;
  Result.PixelFormat := pf24bit;
  BytePerPixel := 3;
  setlength(p, 4*w* h);
  glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, @p[0]);
  z := 0;
  for y:= h-1 downto 0 do begin
      DestPtr := Result.ScanLine[y];
      for x:=0 to w-1 do begin
          DestPtr^ := p[z+2]+(p[z+1] shl 8)+(p[z] shl 16);
          Inc(PByte(DestPtr), BytePerPixel);
          z := z + 4;
      end;
  end;
  setlength(p, 0);
end;
{$ENDIF}

procedure TForm1.SwitchModeClick(Sender: TObject);
begin
  {$IFNDEF TEXTURESLICE}
  isRayCast := not isRayCast;
  MenuSwitchMode.checked := isRayCast;
  MenuRaycast.visible := isRayCast;
  GLbox.Invalidate;
  {$ENDIF}
end;

procedure TForm1.Copy1Click(Sender: TObject);
begin
  Clipboard.Assign(ScreenShot);
end;

end.

