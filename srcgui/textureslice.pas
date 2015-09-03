unit textureslice;
{$IFDEF FPC}{$mode objfpc}{$H+}{$ENDIF}
//   Inspired by Peter Trier http://www.daimi.au.dk/~trier/?page_id=98
//   Philip Rideout http://prideout.net/blog/?p=64
//   and Doyub Kim Jan 2009 http://www.doyub.com/blog/759
//   Ported to Pascal by Chris Rorden Apr 2011
//   Tips for Shaders from
//      http://pages.cs.wisc.edu/~nowak/779/779ClassProject.html#bound
interface
{$H+}
uses
    colorTable, dglOpenGL, sysutils,loadNifti;
const
  kDefaultDistance = 2.25;
  kMaxDistance = 40;
var
  ScaleDim : TScale;
  ClearColor : array [1..3] of single = (0,0,0);
  Distance : single = kDefaultDistance;
  Azimuth : integer = 110;
  Elevation : integer = 15;
  stepSize : single= 0.005;
  IsRGBA : integer = 0;
  WindowWidth,WindowHeight : integer;
  intensityTexture3D : GLuint = 0;
  gradientTexture3D : GLuint = 0;
procedure DisplayGL;
function  InitGL (lFilename: String; WidthPx, HeightPx: integer): boolean;

implementation
var
  gInit : boolean = false;
procedure ReportErrorGL(s: string);
var
 err : GLint;
begin
    err := glGetError ();
    if err > 0 then
       showDebug('OpenGL error '+s+' : '+inttostr(err));
end;

function  InitGL (lFilename: String; WidthPx, HeightPx: integer): boolean;
begin
    result := true;
    WindowWidth := WidthPx;
    WindowHeight := HeightPx;
    if not gInit then begin
      InitOpenGL;
      ReadExtensions;
      ReadImplementationProperties;
    end;
    if (lFilename <> '-') then
      result := Load3DTextures(lFilename,gradientTexture3D,intensityTexture3D, isRGBA, ScaleDim,false);

    //  result := Load3DTextures(lFilename,gradientTexture3D,intensityTexture3D, isRGBA, ScaleDim, false);
    ReportErrorGL('InitGL');
    gInit := true;
end;

procedure setScale;
var
   x,y,z,mn,dx: single;
begin
    mn := ScaleDim[1];
    if ScaleDim[2] < mn then mn := ScaleDim[2];
    if ScaleDim[3] < mn then mn := ScaleDim[3];
    if mn <= 0 then exit;
    dx := Distance* 0.7;
    x := (mn/ ScaleDim[1]) * dx;
    y := (mn/ ScaleDim[2]) * dx;
    z := (mn/ ScaleDim[3]) * dx;
    glScalef(x, y, z);
end;

procedure drawScene;
var
   fz, tz, vz: single;
begin
    glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
    glEnable(GL_BLEND);
    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
    glMatrixMode( GL_TEXTURE );
    glLoadIdentity();
    glTranslatef( 0.5, 0.5, 0.5 );
    setScale;
    while (Azimuth < 0) do
        Azimuth := Azimuth + 360;
    while (Azimuth > 360) do
        Azimuth := Azimuth - 360;
    while (elevation > 90) do
        elevation := 90;
    while (elevation < -90) do
        elevation := -90;
    glRotatef(90,1,0,0);
  	glRotatef(-azimuth,0,1,0);
  	glRotatef(-elevation,1,0,0);
    glTranslatef( -0.5,-0.5, -0.5 );
    glEnable(GL_TEXTURE_3D);
    fz := -0.5;
    while ( fz <= 0.5 ) do begin
    	tz := fz + 0.5; //texture depth
    	vz := fz - 0.2; //view depth
        glBegin(GL_QUADS);
	      glTexCoord3f(0.0, 0.0,tz);
	      glVertex3f(0.0,0.0,vz);
	      glTexCoord3f(1.0, 0.0, tz);
	      glVertex3f(1.0,0.0,vz);
	      glTexCoord3f(1.0, 1.0,tz);
	      glVertex3f(1.0,1.0,vz);
	      glTexCoord3f(0.0, 1.0,tz);
	      glVertex3f(0.0,1.0,vz);
        glEnd();
        fz := fz + stepSize;
    end;
end;

procedure resize(w,h: integer);
  var
  AspectRatio: single;
begin
  if (h = 0) then exit;
  AspectRatio := w / h;
  glViewport( 0, 0, w, h );
  glMatrixMode( GL_PROJECTION );
  glLoadIdentity();
  if( w <= h ) then
      glOrtho( -0.1, 1.1, -0.1 ,1.1 / AspectRatio, -4.0, 4.0)
  else
      glOrtho(-0.1, AspectRatio*1.1, -0.1, 1.1, -4.0, 4.0);
  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity();
end;

procedure DisplayGL;  //Redraw image
begin
  glClearColor(ClearColor[1],ClearColor[2],ClearColor[3], 0);
  resize(WindowWidth, WindowHeight);
      glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
  drawScene;
end;

end.

