/* Global variables specific to raycasting */
GLuint glslprogramInt, renderBuffer, frameBuffer,backFaceBuffer, finalImage, intensityTexture3D, transferTexture; 

void freeTexRay () {
	//release textures used by Ray Casting
	glDeleteTextures(1, &backFaceBuffer);
	glDeleteTextures(1, &backFaceBuffer);
	glDeleteTextures(1, &finalImage);
	glDeleteTextures(1, &intensityTexture3D);
	glDeleteTextures(1, &transferTexture);	
	glDeleteProgram(glslprogramInt);
	glDeleteFramebuffersEXT(1, &frameBuffer);
	glDeleteRenderbuffersEXT(1, &renderBuffer);
   //Bind 0, which means render to back buffer: framebuffer is unbound
   glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

const char *vert_default =
"void main() {\n"
" gl_TexCoord[1] = gl_MultiTexCoord1;\n"
" gl_Position = ftransform();\n"
"}";


const char *frag_default =
"uniform float stepSize, sliceSize, viewWidth, viewHeight;\n"
"uniform sampler3D intensityVol;\n"
"uniform sampler2D backFace;\n"
"uniform sampler1D transferTexture;\n"
"uniform vec3 clearColor,lightPosition, clipPlane;\n"
"uniform float clipPlaneDepth;\n"
"void main() {\n"
" vec2 pixelCoord = gl_FragCoord.st;\n"
" pixelCoord.x /= viewWidth;\n"
" pixelCoord.y /= viewHeight;\n"
" vec3 start = gl_TexCoord[1].xyz;\n"
" vec3 backPosition = texture2D(backFace,pixelCoord).xyz;\n"
" vec3 dir = backPosition - start;\n"
" float len = length(dir);\n"
" dir = normalize(dir);\n"
" if (clipPlaneDepth > -0.5) {\n"
"  gl_FragColor.rgb = vec3(1.0,0.0,0.0);\n"
"  bool frontface = (dot(dir , clipPlane) > 0.0);\n"
"  float dis = dot(dir,clipPlane);\n"
"  if (dis != 0.0  )  dis = (-clipPlaneDepth - dot(clipPlane, start.xyz-0.5)) / dis;\n"
"  if ((frontface) && (dis > len)) len = 0.0;\n"
"  if ((!frontface) && (dis < 0.0)) len = 0.0;\n"
"  if ((dis > 0.0) && (dis < len)) {\n"
"   if (frontface) {\n"
"    start = start + dir * dis;\n"
"   } else {\n"
"    backPosition =  start + dir * (dis);\n"
"   }\n"
"   dir = backPosition - start;\n"
"   len = length(dir);\n"
"  dir = normalize(dir);\n"
"  }\n"
" }\n"
" vec3 deltaDir = dir * stepSize;\n"
" vec4 colorSample,colAcc = vec4(0.0,0.0,0.0,0.0);\n"
" float lengthAcc = 0.0;\n"
" float opacityCorrection = stepSize/sliceSize;\n"
" vec3 samplePos = start.xyz + deltaDir* (fract(sin(gl_FragCoord.x * 12.9898 + gl_FragCoord.y * 78.233) * 43758.5453));\n"
" for(int i = 0; i < int(len / stepSize); i++) {\n"
"  //colorSample = texture3D(intensityVol,samplePos);\n"
"  colorSample.a = texture3D(intensityVol,samplePos).a;\n"
"  colorSample= texture1D(transferTexture, colorSample.a).rgba;\n"
"  if ((lengthAcc <= stepSize) && (colorSample.a > 0.01) ) colorSample.a = sqrt(colorSample.a);\n"
"  colorSample.a = 1.0-pow((1.0 - colorSample.a), opacityCorrection);\n"
"  colorSample.rgb *= colorSample.a;\n"
"  colAcc= (1.0 - colAcc.a) * colorSample + colAcc;\n"
"  samplePos += deltaDir;\n"
"  lengthAcc += stepSize;\n"
"  if ( lengthAcc >= len || colAcc.a > 0.95 )\n"
"   break;\n"
" }\n"
" colAcc.a = colAcc.a/0.95;\n"
" if ( colAcc.a < 1.0 )\n"
"  colAcc.rgb = mix(clearColor,colAcc.rgb,colAcc.a);\n"
" gl_FragColor = colAcc;\n"
"}\n";

GLuint initVertFrag(const char *vert, const char *frag)
{
    GLuint fr = glCreateShader(GL_FRAGMENT_SHADER);
    if (!fr)
        return 0;
    glShaderSource(fr, 1, &frag, NULL);
    glCompileShader(fr);
    GLint status = 0;
    glGetShaderiv(fr, GL_COMPILE_STATUS, &status);
    if(!status) { //report compiling errors.
        char str[4096];
        glGetShaderInfoLog(fr, sizeof(str), NULL, str);
        printf("GLSL fragment error: %s\n", str);
        glDeleteShader(fr);
        return 0;
    }
    GLuint ProgramID = glCreateProgram();
    glAttachShader(ProgramID, fr);
    GLuint vt = 0;
    if (strlen(vert) > 0) {
        vt = glCreateShader(GL_VERTEX_SHADER);
        if (!vt)
            return 0;
        glShaderSource(vt, 1, &vert, NULL);
        glCompileShader(vt);
        glGetShaderiv(vt, GL_COMPILE_STATUS, &status);
        if(!status) { //report compiling errors.
            char str[4096];
            glGetShaderInfoLog(vt, sizeof(str), NULL, str);
            printf("GLSL compile error: %s\n", str);
            glDeleteShader(vt);
            return 0;
        }
        glAttachShader(ProgramID, vt);
    }
    glLinkProgram(ProgramID);
    glUseProgram(ProgramID);
    glDetachShader(ProgramID, fr);
    glDeleteShader(fr);
    if (strlen(vert) > 0) {
        glDetachShader(ProgramID, vt);
        glDeleteShader(vt);
    }
    glUseProgram(0);
    return ProgramID;   
}

void initShaderWithFile () {
    glslprogramInt=  initVertFrag(vert_default, frag_default);
}

#ifndef NIL
 #define NIL 0
#endif 

void  setupRenderRay ()  {
    // Load the vertex and fragment raycasting programs
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, frameBuffer);
    glBindTexture(GL_TEXTURE_2D,  backFaceBuffer);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, gScrnWid, gScrnHt, 0, GL_RGBA, GL_FLOAT, NIL);
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, backFaceBuffer, 0);
    glBindTexture(GL_TEXTURE_2D, finalImage);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
    glTexImage2D(GL_TEXTURE_2D, 0,GL_RGBA16F_ARB, gScrnWid, gScrnHt, 0, GL_RGBA, GL_FLOAT, NIL);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderBuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, gScrnWid, gScrnHt);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, renderBuffer);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glBindFramebufferEXT (GL_FRAMEBUFFER_EXT, frameBuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderBuffer);
}

void updateTransferFunction () {
	glBindTexture(GL_TEXTURE_1D,transferTexture);
	glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexImage1D(GL_TEXTURE_1D, 0, GL_RGBA, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, gRGBAlut);
} 

void loadTexRay(unsigned char *vptr, int isInit) { /* create single 3D texture */
	int i, nBytes = gDimXYZ[0] * gDimXYZ[1] * gDimXYZ[2];
	static const GLdouble equation[] = {0.0, -0.707, -0.3, 0.2};
	glTexParameteri(GL_TEXTURE_3D,GL_TEXTURE_BASE_LEVEL,0);
	glTexParameteri(GL_TEXTURE_3D,GL_TEXTURE_MAX_LEVEL,0);
	glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
	glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
	glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	if (isInit) {
		printf("Raycast requires %gmb (1 byte per voxel)\n", (double)nBytes/1048576.0);
		initShaderWithFile();
		glGenTextures(1, &backFaceBuffer);
		glGenFramebuffersEXT(1, &frameBuffer);
    	glGenTextures(1, &backFaceBuffer);
    	glGenTextures(1, &finalImage);
    	glGenRenderbuffersEXT(1, &renderBuffer);
		glPixelStorei(GL_UNPACK_ALIGNMENT,1);
		glGenTextures(1, &intensityTexture3D);
		glBindTexture(GL_TEXTURE_3D, intensityTexture3D);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);//?
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);//?
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);//?
		glTexImage3D(GL_TEXTURE_3D, 0,GL_ALPHA8, gDimXYZ[0], gDimXYZ[1], gDimXYZ[2],0, GL_ALPHA, GL_UNSIGNED_BYTE,vptr);
	  	glGenTextures(1, &transferTexture);
  		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	}
    setupRenderRay ();
    updateTransferFunction ();
} /* loadTex() */

void drawVertex(float x, float y, float z) {
    glColor3f(x,y,z);
    glMultiTexCoord3f(GL_TEXTURE1, x, y, z);
    glVertex3f(x,y,z);
}

void drawQuads( float x, float y, float z)
//x,y,z typically 1.
// useful for clipping
// If x=0.5 then only left side of texture drawn
// If y=0.5 then only posterior side of texture drawn
// If z=0.5 then only inferior side of texture drawn
{
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
}

void rayCastingOrig () {
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, finalImage, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glUseProgram(glslprogramInt);
    glActiveTexture( GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_3D, intensityTexture3D);
    glActiveTexture( GL_TEXTURE0 );
    glBindTexture(GL_TEXTURE_2D, backFaceBuffer);
    glUniform1i(glGetUniformLocation(glslprogramInt, "backFace"), 0); // backFaceBuffer -> texture0
  	if (gWhiteClearColor)
		glUniform3f(glGetUniformLocation(glslprogramInt, "clearColor"),1.0f,1.0f,1.0f);
	else
		glUniform3f(glGetUniformLocation(glslprogramInt, "clearColor"),0.0f,0.0f,0.0f);
    glUniform1i(glGetUniformLocation(glslprogramInt, "intensityVol"), 1 );
    glUniform1f(glGetUniformLocation(glslprogramInt, "sliceSize"), 1.0/256 ); /* xxxx */
    glUniform1f(glGetUniformLocation(glslprogramInt, "stepSize"), 0.1 );
    glUniform1f(glGetUniformLocation(glslprogramInt, "viewHeight"), gScrnHt); /*xxx*/
    glUniform1f(glGetUniformLocation(glslprogramInt, "viewWidth"), gScrnWid ); /*xxxx*/
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glMatrixMode(GL_MODELVIEW);
    glScalef(1.0,1.0,1.0);
    drawQuads(1.0,1.0,1.0);
    glDisable(GL_CULL_FACE);
    glUseProgram(0);
    glActiveTexture( GL_TEXTURE0 );
}

void reshapeOrtho(int w, int h) {
  if (h == 0) h = 1;
  glViewport(0, 0,w, h);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluOrtho2D(0, 1, 0, 1.0);
  glMatrixMode(GL_MODELVIEW);//? 
}

void drawUnitQuad ()
//stretches image in view space.
{
    glDisable(GL_DEPTH_TEST);
    glBegin(GL_QUADS);
        glTexCoord2f(0.0, 0.0);
        glVertex2f(0.0, 0.0);
        glTexCoord2f(1.0 ,0.0);
        glVertex2f(1.0, 0.0);
        glTexCoord2f(1.0, 1.0);
        glVertex2f(1.0, 1.0);
        glTexCoord2f(0.0, 1.0);
        glVertex2f(0.0, 1.0);
    glEnd();
    glEnable(GL_DEPTH_TEST); 
}

// display the final image on the screen
void renderBufferToScreen () {
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glLoadIdentity();
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D,finalImage);
    //use next line instead of previous to illustrate one-pass rendering
    //glBindTexture(GL_TEXTURE_2D,backFaceBuffer);
	reshapeOrtho(gScrnWid, gScrnHt);
	drawUnitQuad();
    glDisable(GL_TEXTURE_2D);
}

void renderBackFace() {
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, backFaceBuffer, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glEnable(GL_CULL_FACE);
    glCullFace(GL_FRONT);
    glMatrixMode(GL_MODELVIEW);
    glScalef(gScaleRayXYZ[0], gScaleRayXYZ[1], gScaleRayXYZ[2]); 
    drawQuads(1.0,1.0,1.0);
    glDisable(GL_CULL_FACE);
}

void rayCasting() {
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, finalImage, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
	glActiveTexture(GL_TEXTURE2);
	glBindTexture(GL_TEXTURE_1D, transferTexture);
	glActiveTexture( GL_TEXTURE1 );
	glBindTexture(GL_TEXTURE_3D,intensityTexture3D);
	glActiveTexture( GL_TEXTURE0 );
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, backFaceBuffer);
	glUseProgram(glslprogramInt);
	glUniform1i(glGetUniformLocation(glslprogramInt, "backFace"), 0); // backFaceBuffer -> texture0
	glUniform1i(glGetUniformLocation(glslprogramInt, "intensityVol"), 1 );
	glUniform1i(glGetUniformLocation(glslprogramInt, "transferTexture"), 2);   
	glUniform3f(glGetUniformLocation(glslprogramInt, "clearColor"),1.0f,1.0f,1.0f);
	glUniform1f(glGetUniformLocation(glslprogramInt, "sliceSize"), 1.0f/gDimXYZ[3] ); /* 4th dim is MAX */
	glUniform1f(glGetUniformLocation(glslprogramInt, "stepSize"), ((float)gQuality * 1.0)/gDimXYZ[3] );
	glUniform1f(glGetUniformLocation(glslprogramInt, "viewHeight"), gScrnHt); /*xxx*/
	glUniform1f(glGetUniformLocation(glslprogramInt, "viewWidth"), gScrnWid ); /*xxxx*/
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	glMatrixMode(GL_MODELVIEW);
	//glScalef(1.0,1.0,1.0);
	drawQuads(1.0,1.0,1.0);
	glDisable(GL_CULL_FACE);
	glUseProgram(0);
	//glActiveTexture( GL_TEXTURE0 );
}

void drawGLRay() { /* volume render using a single 3D texture */
  //glClearColor(0.0f, 0.0f, 0.1f, 0.0f);   
  scrnsize(gScrnWid, gScrnHt);
  glBindFramebufferEXT (GL_FRAMEBUFFER_EXT, frameBuffer);
  glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderBuffer);
  glTranslatef(0.0f,0.0f,-2.25); //2.25 = distance
  glRotatef(90.0f-gElevation,-1,0,0);
  glRotatef(-gAzimuth,0,0.0f,1.0f);
  glTranslatef(-gScaleRayXYZ[0]/2.0f,-gScaleRayXYZ[1]/2.0f,-gScaleRayXYZ[2]/2.0f);
  renderBackFace();
  rayCasting();
  glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);//disable framebuffer
  renderBufferToScreen(); 
}

