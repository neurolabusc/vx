unit raycast;
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
  ScaleDim: TScale;
  ClearColor: array [1..3] of single = (0,0,0);
  isPerspective : boolean = false;
  Distance : single = kDefaultDistance;
  Azimuth : integer = 110;
  Elevation : integer = 15;
  LUTCenter : integer = 128;
  LUTWidth : integer = 255;
  LUTindex : integer = 0;
  showGradient : integer = 0;
  stepSize : single= 0.01;
  edgeThresh : single = 0.05;
  edgeExp : single = 0.5;
  isRGBA : integer = 0;
  isRayCast : boolean = true;
  isQuality : boolean = true;
  loadGradients: boolean = true;
  boundExp : single = 0.0; //Contribution of boundary enhancement calculated opacity and scaling exponent
  WindowWidth,WindowHeight : integer;
  TransferTexture: GLuint = 0;
  gradientTexture3D: GLuint = 0;
  intensityTexture3D: GLuint = 0;
  glslprogram,finalImage,
  renderBuffer, frameBuffer,backFaceBuffer: GLuint;
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

procedure drawVertex(x,y,z: single);
begin
  glColor3f(x,y,z);
  glMultiTexCoord3f(GL_TEXTURE1, x, y, z);
  glVertex3f(x,y,z);
end;

procedure drawQuads(x,y,z: single);
//x,y,z typically 1.
// useful for clipping
// If x=0.5 then only left side of texture drawn
// If y=0.5 then only posterior side of texture drawn
// If z=0.5 then only inferior side of texture drawn
begin
  glBegin(GL_QUADS);
    //* Back side
    glNormal3f(0.0, 0.0, -1.0);
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(0.0, y, 0.0);
    drawVertex(x, y, 0.0);
    drawVertex(x, 0.0, 0.0);
    //* Front side
    glNormal3f(0.0, 0.0, 1.0);
    drawVertex(0.0, 0.0, z);
    drawVertex(x, 0.0, z);
    drawVertex(x, y, z);
    drawVertex(0.0, y, z);
    //* Top side
    glNormal3f(0.0, 1.0, 0.0);
    drawVertex(0.0, y, 0.0);
    drawVertex(0.0, y, z);
    drawVertex(x, y, z);
    drawVertex(x, y, 0.0);
    //* Bottom side
    glNormal3f(0.0, -1.0, 0.0);
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(x, 0.0, 0.0);
    drawVertex(x, 0.0, z);
    drawVertex(0.0, 0.0, z);
    //* Left side
    glNormal3f(-1.0, 0.0, 0.0);
    drawVertex(0.0, 0.0, 0.0);
    drawVertex(0.0, 0.0, z);
    drawVertex(0.0, y, z);
    drawVertex(0.0, y, 0.0);
    //* Right side
    glNormal3f(1.0, 0.0, 0.0);
    drawVertex(x, 0.0, 0.0);
    drawVertex(x, y, 0.0);
    drawVertex(x, y, z);
    drawVertex(x, 0.0, z);
  glEnd();
end;

function TestShader(shader:GLenum): boolean;
var
  status: GLint;
  s : string;
  maxLength : GLint;
begin
     glGetShaderiv(shader, GL_COMPILE_STATUS, @status);
     result := (status <> 0);
     if (not result) then begin //report compiling errors.
       glGetShaderiv(shader, GL_INFO_LOG_LENGTH, @maxLength);
       setlength(s, maxLength);
       glGetShaderInfoLog(shader, maxLength, maxLength, @s[1]);
       s:=trim(s);
       showDebug('GLSL error '+s);
     end;
end;

function initShaderWithFile: GLHandleARB;
const
  fragStr = 'uniform float stepSize;'
+'uniform sampler3D gradientVol;'
+'uniform sampler3D intensityVol;'
+'uniform sampler2D backFace;'
+'uniform sampler1D TransferTexture;'
+'uniform float viewWidth;'
+'uniform float viewHeight;'
+'uniform float edgeThresh, edgeExp;'
+'uniform int showGradient;'
+'uniform float isRGBA;'
+'uniform float boundExp;'
+'uniform vec3 clearColor;'
+'void main() {'
+'vec2 pixelCoord = gl_FragCoord.st;'
+'pixelCoord.x /= viewWidth;'
+'pixelCoord.y /= viewHeight;'
+'vec4 start = gl_TexCoord[1];'
+'vec4 backPosition = texture2D(backFace,pixelCoord);'
+'vec3 dir = vec3(0.0,0.0,0.0);'
+'dir.x = backPosition.x - start.x;'
+'dir.y = backPosition.y - start.y;'
+'dir.z = backPosition.z - start.z;'
+'float len = length(dir.xyz);'
+'dir = normalize(dir);'
+'vec3 deltaDir = dir * stepSize;'
+'vec3 samplePos = start.xyz;'
+'vec4 colorSample,gradientSample,colAcc = vec4(0.0,0.0,0.0,0.0);'
+'float alphaAcc = 0.0;'
+'float lengthAcc = 0.0;'
+'float alphaSample;'
+'float edgeVal;'
+'float dotView;'
+'  float random = fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453);'
+'samplePos  = samplePos + deltaDir* (random);'
+'for(int i = 0; i < 450; i++) {'
+'if (showGradient < 1)'
+'{'
+'if (isRGBA > 0.0)'
+'{'
+'colorSample = texture3D(intensityVol,samplePos);'
+'} else {'
+'colorSample.a = texture3D(intensityVol,samplePos).a;'
+'colorSample= texture1D(TransferTexture, colorSample.a).rgba;'
+'}'
+'} else {'
+'colorSample = texture3D(gradientVol,samplePos);'
+'}'
+'if (edgeThresh < 1.0 || boundExp > 0.0)'
+'{'
+'  gradientSample= texture3D(gradientVol,samplePos);'
+'  if (edgeThresh < 1.0)'
+'  {'
+'gradientSample.rgb = gradientSample.rgb*2.0 - 1.0;'
+'float dotView = dot(dir, gradientSample.rgb);'
+'edgeVal = pow(1.0-abs(dotView),edgeExp);'
+'edgeVal = edgeVal * pow(gradientSample.a,0.3);'
+'    if (edgeVal >= edgeThresh)'
+'    {'
+'colorSample.rgb = mix(colorSample.rgb, vec3(0.0,0.0,0.0), pow((edgeVal-edgeThresh)/(1.0-edgeThresh),4.0));'
+'}'
+'  }'
+'  if (boundExp > 0.0)'
+'colorSample.a = colorSample.a * pow(gradientSample.a,boundExp);'
+'}'
+'colorSample.rgb *= colorSample.a;'
+'alphaSample = 1.0-pow((1.0 - colorSample.a), stepSize);'
+'colAcc= (1.0 - colAcc.a) * colorSample + colAcc;'
+'alphaAcc += alphaSample;'
+'samplePos += deltaDir;'
+'lengthAcc += stepSize;'
+'if ( lengthAcc >= len || alphaAcc > 0.95 )'
+'break;'
+'}'
+'colAcc.rgb = mix(clearColor,colAcc.rgb,colAcc.a);'
+'gl_FragColor = colAcc;'
+'}';
  vertStr = 'void main() {gl_TexCoord[1] = gl_MultiTexCoord1; gl_Position = ftransform();}';
var
  vertex_shader,fragment_shader:GLenum;
  shader_length: integer;
  fragment_src, vertex_src: AnsiString;
begin
  result := 0; //in case we exit early (error)
  //Compile Fragment Shader
  fragment_src := fragStr;//fragment_src := LoadStr( fname);
  fragment_shader := glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB);
  shader_length:= Length(fragment_src);
  glShaderSourceARB(fragment_shader, 1, @fragment_src, @shader_length);
  glCompileShaderARB(fragment_shader);
  if not TestShader(fragment_shader) then
     exit;
  //Compile Vertex Shader
  vertex_src := vertStr;//vertex_src := LoadStr( vname);
  vertex_shader := glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB);
  shader_length:= Length(vertex_src);
  glShaderSourceARB(vertex_shader, 1, @vertex_src, @shader_length);
  glCompileShaderARB(vertex_shader);
  if not TestShader(vertex_shader) then
     exit;
  // Attach The Shader Objects To The Program Object
  result := glCreateProgramObjectARB();
  glAttachObjectARB(result, vertex_shader);
  glAttachObjectARB(result, fragment_shader);
  // Link The Program Object
  glLinkProgramARB(result);
end;

procedure reshapeOrtho(w,h: integer);
begin
  if (h = 0) then h := 1;
  glViewport(0, 0,w,h);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluOrtho2D(0, 1, 0, 1.0);
  glMatrixMode(GL_MODELVIEW);//?
end;

procedure resize(w,h: integer);
  var
  whratio,scale: single;
begin
  if (h = 0) then
     h := 1;
  glViewport(0, 0, w, h);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  if isPerspective and isRayCast then
     gluPerspective(40.0, w/h, 0.01, kMaxDistance)
  else begin
       if Distance = 0 then
          scale := 1
       else
           scale := 1/abs(kDefaultDistance/(Distance+1.0));
       whratio := w/h;
       //glOrtho(whratio*-0.5*scale,whratio*0.5*scale,-0.5*scale,0.5*scale, 0.01, 10* kMaxDistance);
       glOrtho(whratio*-0.5*scale,whratio*0.5*scale,-0.5*scale,0.5*scale, -100, 100);
  end;
  glMatrixMode(GL_MODELVIEW);//?
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
    glGenFramebuffersEXT(1, @frameBuffer);
    glGenRenderbuffersEXT(1, @renderBuffer);
    glGenTextures(1, @backFaceBuffer);
    glGenTextures(1, @finalImage);
  end;
  if (lFilename <> '-') then begin
    result := Load3DTextures(lFilename,gradientTexture3D,intensityTexture3D, isRGBA, ScaleDim, loadGradients);
    UpdateTransferFunction (LUTindex,LUTCenter,LUTWidth, TransferTexture);
    glslprogram := initShaderWithFile;
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
  end;
  glEnable(GL_CULL_FACE);
  glClearColor(ClearColor[1],ClearColor[2],ClearColor[3], 0);
  // Create the to FBO's one for the backside of the volumecube and one for the finalimage rendering
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,frameBuffer);
  glBindTexture(GL_TEXTURE_2D, backFaceBuffer);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
  glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, WindowWidth, WindowHeight, 0, GL_RGBA, GL_FLOAT, nil);
  glBindTexture(GL_TEXTURE_2D, finalImage);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
  glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, WindowWidth, WindowHeight, 0, GL_RGBA, GL_FLOAT, nil);
  ReportErrorGL('InitGL');
  gInit := true;
end;

procedure drawUnitQuad; //stretches image in view space.
begin
  glDisable(GL_DEPTH_TEST);
  glBegin(GL_QUADS);
    glTexCoord2f(0,0);
    glVertex2f(0,0);
    glTexCoord2f(1,0);
    glVertex2f(1,0);
    glTexCoord2f(1, 1);
    glVertex2f(1, 1);
    glTexCoord2f(0, 1);
    glVertex2f(0, 1);
  glEnd();
  glEnable(GL_DEPTH_TEST);
end;

procedure renderBufferToScreen;  // display the final image on the screen
begin
  glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
  glLoadIdentity();
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D,finalImage);
  //use next line instead of previous to illustrate one-pass rendering
  reshapeOrtho(WindowWidth, WindowHeight);
  drawUnitQuad();
  glDisable(GL_TEXTURE_2D);
end;

// render the backface to the offscreen buffer backFaceBuffer
procedure renderBackFace;
begin
  glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, backFaceBuffer, 0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
  glEnable(GL_CULL_FACE);
  glCullFace(GL_FRONT);
  glMatrixMode(GL_MODELVIEW);
  glScalef(ScaleDim[1],ScaleDim[2],ScaleDim[3]);
  drawQuads(1.0,1.0,1.0);
  glDisable(GL_CULL_FACE);
end;

procedure uniform1f( name: AnsiString; value: single );
begin
  glUniform1f(glGetUniformLocation(GLSLprogram, pAnsiChar(Name)), value) ;
end;

procedure uniform1i( name: AnsiString; value: integer);
begin
  glUniform1i(glGetUniformLocation(GLSLprogram, pAnsiChar(Name)), value) ;
end;

procedure uniform3fv( name: AnsiString; v1,v2,v3: single);
begin
  glUniform3f(glGetUniformLocation(GLSLprogram, pAnsiChar(Name)), v1,v2,v3) ;
end;

procedure rayCasting;
begin
  glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, finalImage, 0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
  // backFaceBuffer -> texture0
  glActiveTexture( GL_TEXTURE0 );
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, backFaceBuffer);
  //gradientTexture -> texture1
  glActiveTexture( GL_TEXTURE1 );
  //glEnable(GL_TEXTURE_3D);
  glBindTexture(GL_TEXTURE_3D,gradientTexture3D);
  //TransferTexture -> texture2
  glActiveTexture(GL_TEXTURE2);
  glBindTexture(GL_TEXTURE_1D, TransferTexture);
  //intensityTexture -> texture3
  glActiveTexture( GL_TEXTURE3 );
  glBindTexture(GL_TEXTURE_3D,intensityTexture3D);
  glUseProgram(glslprogram);
  if isQuality then
     uniform1f( 'stepSize', stepSize )
  else
     uniform1f( 'stepSize', stepSize * 4.0);
  uniform1f( 'viewWidth', WindowWidth );
  uniform1f( 'viewHeight', WindowHeight );
  uniform1i( 'backFace', 0 );		// backFaceBuffer -> texture0
  uniform1i( 'TransferTexture',2);
  uniform1i( 'gradientVol', 1 );	// gradientTexture -> texture2
  uniform1i( 'intensityVol', 3 );
  uniform1i( 'showGradient',showGradient);
  if gradientTexture3D = 0 then begin
     uniform1f( 'edgeThresh', 1.0 );
    uniform1f( 'boundExp', 0.0 )
  end else begin
    uniform1f( 'edgeThresh', EdgeThresh );
    uniform1f( 'boundExp', boundExp );
  end;
  uniform1f( 'edgeExp', EdgeExp );
  uniform3fv('clearColor',ClearColor[1],ClearColor[2],ClearColor[3]);
  uniform1f( 'isRGBA', isRGBA);
  glEnable(GL_CULL_FACE);
  glCullFace(GL_BACK);
  glMatrixMode(GL_MODELVIEW);
  //glScalef(1.0,1.0,1.0);
  drawQuads(1.0,1.0,1.0);
  glDisable(GL_CULL_FACE);
  glUseProgram(0);
  glActiveTexture( GL_TEXTURE0 );
  glDisable(GL_TEXTURE_2D);
end;

procedure DisplayGLray;  //Redraw image using ray casting
begin
  //these next lines only required when switching from texture slicing
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,frameBuffer);
  glMatrixMode( GL_TEXTURE );
  glLoadIdentity();
  glDisable(GL_TEXTURE_3D);
  //raycasting follows
  glClearColor(ClearColor[1],ClearColor[2],ClearColor[3], 0);
  resize(WindowWidth, WindowHeight);
  glBindFramebufferEXT (GL_FRAMEBUFFER_EXT, frameBuffer);
  glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderBuffer);
  glTranslatef(0,0,{-Distance}-Distance);
  glRotatef(90-Elevation,-1,0,0);
  glRotatef(Azimuth,0,0,1);
  glTranslatef(-ScaleDim[1]/2,-ScaleDim[2]/2,-ScaleDim[3]/2);
  //glScalef(Zoom,Zoom,Zoom);
  renderBackFace();
  rayCasting();
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);//disable framebuffer
  renderBufferToScreen();
  //next, you will need to execute SwapBuffers
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

procedure DisplayGLtex;  //Redraw image using Texture Slicing
var
   fz, tz, vz, renderQuality: single;
begin
   glDisable(GL_DEPTH_TEST);
  //next lines only required when switching from raycasting
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
     glActiveTexture( GL_TEXTURE0 );
     glBindTexture(GL_TEXTURE_3D,intensityTexture3D);
  //texture slicing follows
  glClearColor(ClearColor[1],ClearColor[2],ClearColor[3], 0);
  resize(WindowWidth, WindowHeight);
  glClear( GL_COLOR_BUFFER_BIT  or GL_DEPTH_BUFFER_BIT );
  glAlphaFunc( GL_GREATER, 0.03 );
  glEnable(GL_BLEND);
  glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
  glMatrixMode( GL_TEXTURE );
  glLoadIdentity();
  glTranslatef( 0.5, 0.5, 0.5 );
  setScale;
  glScalef(1.3, 1.3, 1.3);
  glRotatef(90,1,0,0);
  glRotatef(-Azimuth,0,1,0);
  glRotatef(-Elevation,1,0,0);
  glTranslatef( -0.5, -0.5, -0.5);
  glEnable(GL_TEXTURE_3D);
  if isQuality then
     renderQuality := 1/256
  else
      renderQuality := 1/64;
  fz := -0.5;
  while (fz <= 0.5) do begin
    tz := fz + 0.5;
    vz := (fz*2.0) - 0.2;
    glBegin(GL_QUADS);
    glTexCoord3f(0.0, 0.0,tz);
    glVertex3f(-1.0,-1.0,vz);
    glTexCoord3f(1.0, 0.0, tz);
    glVertex3f(1.0,-1.0,vz);
    glTexCoord3f(1.0, 1.0,tz);
    glVertex3f(1.0,1.0,vz);
    glTexCoord3f(0.0, 1.0,tz);
    glVertex3f(-1.0,1.0,vz);
    glEnd();
    fz := fz + renderQuality
  end;
end;

procedure DisplayGL;  //Redraw image
begin
     if isRayCast then
        DisplayGLray
     else
         DisplayGLtex;
end;

end.

