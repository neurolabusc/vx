/*
*This is a minimal volume rendering tool
*
*Volume renderings using either 2D texture slicing, 3D texture slicing, or ray casting
*For details on these methods, see
* http://www.real-time-volume-graphics.org
* http://http.developer.nvidia.com/GPUGems/gpugems_ch39.html
*
*This code leverages these open source projects
* VolumeRendering: Divine Augustine (view-aligned 3D, 32 bytes per voxel)
*  http://www.codeproject.com/Articles/352270/Getting-started-with-Volume-Rendering
* Vox: Yusuf Attarwala (slice-aligned 3D, 16 bytes per voxel)
*  ftp://ftp.sgi.com/sgi/demos/
* Volume from the Advanced97 glut demos (view-aligned 3D, 32 bytes per voxel)
*  https://www.cosc.brocku.ca/Offerings/3P98/course/OpenGL/glut-3.7/progs/advanced97/volume.c
* MRIcroGL: Chris Rorden (ray casting, 64 bytes per voxel)
*  http://www.mccauslandcenter.sc.edu/mricrogl/
* NIFTI header
*  http://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h
* Leandro R Barbagallo's WebGL ray casting 
*  http://lebarba.com/blog/
* 
*Methods
* 2D Texture Slicing: 
*	+ Runs well on ancient hardware (e.g. SGI O2)
*	- Requires a lot of texture memory (12 bytes per voxel)
*	- Artefacts when objects viewed off-axis
* 3D Texture Slicing: 
*	+ Simple code
*	+ Uses less memory than 2D textures (4 bytes per voxel)
* Ray Casting: 
*	+ Hides 'wood grain' artefacts for low resolution images
*	+ Uses least memory (1 bytes per voxel)
*	- Requires modern hardware (programmable shaders)
*
*Compiling
* For OSX  
*  gcc vx.c -o vx -framework OpenGL -framework GLUT -Wno-deprecated-declarations
* For Linux (or gcc on SGI)
*  gcc vx.c -o vx -lglut -lGLU -lGL -lXext -lX11 -lm
* For SGI (using SGI's MIPSpro)
*  cc vx.c -o vx /usr/lib/libglut.a -lGLU -lGL -lXmu -lXext -lX11 -lm
* Or simply 
*  cc vx.c -o vx -lglut -lGLU -lGL -lXmu -lXext -lX11 -lm
*
*Limitations/ToDo
* 1.) Only supports 8-bit NIfTI images saved as a single file (.nii or .nii.gz)
*      Would be nice to support different precision (e.g. 16 bit) and .hdr/img files
* 2.) Some older graphics (pre 2006) assume each dimension is a power of two
*      Therefore, a 256x256x109 voxel volume must be padded to 256x256x256
* 3.) Ignores the NIfTI spatial rotation matrix.
*      Rotation assumes roughtly canonical orientation (with spatial matrix like [1 0 0; 0 1 0; 0 0 1])
* 4.) Limited opacity correction: thinner slices (e.g. higher quality) should be more opaque
*/

/* include critical libraries */
#include <stdio.h> 
#include <stdlib.h> 
#include <string.h>
#include <sys/stat.h> 
#include <math.h> 
#ifdef __APPLE__
 #include <mach/clock.h>
 #include <mach/mach.h>
 #include <OpenGL/gl.h>
 #include <GLUT/glut.h>
 #define GL_TEXTURE_3D_EXT GL_TEXTURE_3D
 #define  glTexImage3DEXT  glTexImage3D
#else
 #include <GL/gl.h> 
 #include <GL/glu.h>   
 #include <GL/glut.h>
 #include <time.h>
#endif
/* pop up menu entries */
#define SPIN_ON   1
#define SPIN_OFF  2
#define MENU_HELP 3
#define MENU_EXIT 4
#define maxColorTable 14  /* color tables are from 0..14 [grayscale..blue] */
#ifdef __sgi
 #define maxDrawMode 1 /* 0=2DTexture, 1=3DTexture, 2=Ray cast */
#else
 #define maxDrawMode 2 /* 0=2DTexture, 1=3DTexture, 2=Ray cast */
#endif 

/* global variables */
typedef uint32_t tRGBAlut[256];
tRGBAlut gRGBAlut; 
int gDrawMode = 0; /* 0=2DTexture, 1=3DTexture, 2=Ray cast */
int gColorTable = 0;
int gWindowWidth = 192;
int gWindowCenter = 128;
time_t gStartClock = 0;
int gQuality = 1; /*1=best, 2=fast/mid-quality (half sampling), 4=fastest/poor-quality (quarter sampling)*/
int gAnimationCount = 0;
int gWhiteClearColor = 0;   
float gAzimuth = 90;
float gElevation = 0;
int gIsClipPlane = 0;
int gMousePosX = -1;
int gMousePosY = -1;
int gDimXYZ[4]; //4th value is max of previous 3
float gScaleRayXYZ[3];
float gScale3DXYZ[3]; /* for anisotropic images */
float gScale2DXYZ[3]; /* for anisotropic images */
int gScrnWid = 580;
int gScrnHt = 400;
unsigned char *vptr;

struct nifti_1_header { /* NIFTI-1 usage         */  /* ANALYZE 7.5 field(s) */
 int   sizeof_hdr;    /*!< MUST be 348           */  /* int sizeof_hdr;      */
 char  data_type[10]; /*!< ++UNUSED++            */  /* char data_type[10];  */
 char  db_name[18];   /*!< ++UNUSED++            */  /* char db_name[18];    */
 int   extents;       /*!< ++UNUSED++            */  /* int extents;         */
 short session_error; /*!< ++UNUSED++            */  /* short session_error; */
 char  regular;       /*!< ++UNUSED++            */  /* char regular;        */
 char  dim_info;      /*!< MRI slice ordering.   */  /* char hkey_un0;       */
 short dim[8];        /*!< Data array dimensions.*/  /* short dim[8];        */
 float intent_p1 ;    /*!< 1st intent parameter. */  /* short unused8;       */
 float intent_p2 ;    /*!< 2nd intent parameter. */  /* short unused10;      */
 float intent_p3 ;    /*!< 3rd intent parameter. */  /* short unused12;      */
 short intent_code ;  /*!< NIFTI_INTENT_* code.  */  /* short unused14;      */
 short datatype;      /*!< Defines data type!    */  /* short datatype;      */
 short bitpix;        /*!< Number bits/voxel.    */  /* short bitpix;        */
 short slice_start;   /*!< First slice index.    */  /* short dim_un0;       */
 float pixdim[8];     /*!< Grid spacings.        */  /* float pixdim[8];     */
 float vox_offset;    /*!< Offset into .nii file */  /* float vox_offset;    */
 float scl_slope ;    /*!< Data scaling: slope.  */  /* float funused1;      */
 float scl_inter ;    /*!< Data scaling: offset. */  /* float funused2;      */
 short slice_end;     /*!< Last slice index.     */  /* float funused3;      */
 char  slice_code ;   /*!< Slice timing order.   */
 char  xyzt_units ;   /*!< Units of pixdim[1..4] */
 float cal_max;       /*!< Max display intensity */  /* float cal_max;       */
 float cal_min;       /*!< Min display intensity */  /* float cal_min;       */
 float slice_duration;/*!< Time for 1 slice.     */  /* float compressed;    */
 float toffset;       /*!< Time axis shift.      */  /* float verified;      */
 int   glmax;         /*!< ++UNUSED++            */  /* int glmax;           */
 int   glmin;         /*!< ++UNUSED++            */  /* int glmin;           */
 char  descrip[80];   /*!< any text you like.    */  /* char descrip[80];    */
 char  aux_file[24];  /*!< auxiliary filename.   */  /* char aux_file[24];   */
 short qform_code ;   /*!< NIFTI_XFORM_* code.   */  /*-- all ANALYZE 7.5 ---*/
 short sform_code ;   /*!< NIFTI_XFORM_* code.   */  /*   fields below here  */
 float quatern_b ;    /*!< Quaternion b param.   */
 float quatern_c ;    /*!< Quaternion c param.   */
 float quatern_d ;    /*!< Quaternion d param.   */
 float qoffset_x ;    /*!< Quaternion x shift.   */
 float qoffset_y ;    /*!< Quaternion y shift.   */
 float qoffset_z ;    /*!< Quaternion z shift.   */
 float srow_x[4] ;    /*!< 1st row affine transform.   */
 float srow_y[4] ;    /*!< 2nd row affine transform.   */
 float srow_z[4] ;    /*!< 3rd row affine transform.   */
 char intent_name[16];/*!< 'name' or meaning of data.  */
 char magic[4] ;      /*!< MUST be "ni1\0" or "n+1\0". */
} ;                   /**** 348 bytes total ****/

float swapFloat(float in ){ /*convert endian of 32-bit single precision float*/
	float out;
	char *inChar = ( char* ) &in;
	char *outChar = ( char* ) &out;
	outChar[0] = inChar[3];
	outChar[1] = inChar[2];
	outChar[2] = inChar[1];
	outChar[3] = inChar[0];
	return out;
}

int swapInt(int in ){ /*convert endian of 32-bit integer*/
	int out;
	char *inChar = ( char* ) &in;
	char *outChar = ( char* ) &out;
	outChar[0] = inChar[3];
	outChar[1] = inChar[2];
	outChar[2] = inChar[1];
	outChar[3] = inChar[0];
	return out;
}

short swapShort(short in ){ /*convert endian of 16-bit integer*/
	short out;
	char *inChar = ( char* ) &in;
	char *outChar = ( char* ) &out;
	outChar[0] = inChar[1];
	outChar[1] = inChar[0];
	return out;
}

int isPowerOfTwo (unsigned int x) { /*is input a PoT (2,4,8,16,32...)?*/
  return ((x != 0) && !(x & (x - 1)));
}

int isGz (char ** argv) { /*detect if file is gzip format, e.g. file.nii.gz*/
	int found = 0;
	char *p = strrchr(argv[1], '.');
	if (p)
		found = strcmp(p, ".gz") == 0;
	return found;
}

void readHeader(char** argv, struct nifti_1_header *hdr) { /*read NIfTI format header*/
	int i;	
	FILE *fp;
	float FOVxyz[3]; /* field of view for each dimension */
	float FOVmax;
	char command[1024];
	if (isGz(argv)) {	
		sprintf(command, "gunzip -c %s", argv[1]);
		fp = popen(command, "r");
	} else
		fp = fopen(argv[1],"rb");
	if (fp == NULL)  {
    	fprintf(stderr,"cannot open input file %s\n", argv[1]);
        exit(-1);
    }
    fread(hdr, sizeof(struct nifti_1_header), 1, fp);
	if (isGz(argv))
		pclose ( fp );
	else
		fclose( fp );
	if ( swapInt(hdr->sizeof_hdr) == 348) {
        printf("Converting header to native endian.\n");
        hdr->sizeof_hdr = swapInt(hdr->sizeof_hdr);
        hdr->datatype = swapShort(hdr->datatype);
        hdr->bitpix = swapShort(hdr->bitpix);
        hdr->vox_offset = swapFloat(hdr->vox_offset );
        for (i = 0; i < 8; i++) {
        	hdr->pixdim[i] = swapFloat(hdr->pixdim[i] );
        	hdr->dim[i] = swapShort(hdr->dim[i] );
        }
        if (hdr->bitpix != 8) 
        	printf("Support for foreign-endian images with >8bpp will require swapping the image data\n");
	}
	if (hdr->sizeof_hdr != 348) {
        fprintf(stderr,"This does not appear to be a NIfTI header.\n");
        exit(-1);	
	}
	if ((hdr->datatype != 2) || (hdr->bitpix != 8)) {
		printf("Please convert this NIfTI image to 8-bit (current datatype %d bitpix %d)\n", hdr->datatype, hdr->bitpix); 
        exit(-1);	
	}
	printf("dimensions %dx%dx%d voxels\n", hdr->dim[1], hdr->dim[2], hdr->dim[3]);
	if ((hdr->dim[1] < 2) ||(hdr->dim[2] < 2) || (hdr->dim[3] < 2) ) {
		fprintf(stderr,"3D data required.\n");
        exit(-1);	
	}
	hdr->pixdim[1] = (hdr->pixdim[1] == 0.0) ? 1.0 : fabs(hdr->pixdim[1]);
	hdr->pixdim[2] = (hdr->pixdim[2] == 0.0) ? 1.0 : fabs(hdr->pixdim[2]);
	hdr->pixdim[3] = (hdr->pixdim[3] == 0.0) ? 1.0 : fabs(hdr->pixdim[3]);
	printf("spacing %gx%gx%g mm\n", hdr->pixdim[1], hdr->pixdim[2], hdr->pixdim[3]);
	

	 
	FOVxyz[0] = hdr->pixdim[1] * hdr->dim[1];
	FOVxyz[1] = hdr->pixdim[2] * hdr->dim[2];
	FOVxyz[2] = hdr->pixdim[3] * hdr->dim[3];
	FOVmax = FOVxyz[0];
	if (FOVxyz[1] > FOVmax) FOVmax = FOVxyz[1];
	if (FOVxyz[2] > FOVmax) FOVmax = FOVxyz[2];
	for (i = 0; i < 3; i++) gScale2DXYZ[i] = FOVxyz[i]/FOVmax;	
	for (i = 0; i < 3; i++) gScale3DXYZ[i] = FOVmax/FOVxyz[i];	
	
	for (i = 0; i < 3; i++) gScaleRayXYZ[i] = (2.0f*FOVxyz[i])/FOVmax;	
	
	printf("scaling %gx%gx%g \n", gScale3DXYZ[0], gScale3DXYZ[1],gScale3DXYZ[2]); 
	#ifndef __APPLE__ /*Older hardware (SGI?) has problems with NPOT textures*/
	if (!isPowerOfTwo(hdr->dim[1]) || !isPowerOfTwo(hdr->dim[2]) || !isPowerOfTwo(hdr->dim[3]) )
		printf("image dimensions are not a power of two. Older graphics will not support this! Solution: pad image.\n");	
	#endif
	gDimXYZ[0] = hdr->dim[1]; gDimXYZ[1] = hdr->dim[2]; gDimXYZ[2] = hdr->dim[3];
	//set dim[3] to max of previous 3
	gDimXYZ[3] = gDimXYZ[0];
	if (gDimXYZ[1] > gDimXYZ[3]) gDimXYZ[3] = gDimXYZ[1];
	if (gDimXYZ[2] > gDimXYZ[3]) gDimXYZ[3] = gDimXYZ[2];
}

void scrnsize(int w, int h) {
	/* Draw in square regardless of a window's aspect ratio */
	GLdouble AspectRatio = ( GLdouble )(w) / ( GLdouble )(h ); 
	glViewport( 0, 0, w, h );
	glMatrixMode( GL_PROJECTION );
	glLoadIdentity();	 
	if( AspectRatio < 1.0f )
	 glOrtho( -1.1f, 1.1f, -1.1f/ AspectRatio ,1.1f / AspectRatio, -12.0f, 4.0f);
	else
	 glOrtho(AspectRatio* -1.1f, AspectRatio*1.1, -1.1f, 1.1f, -12.0f, 4.0f);
	//printf("%d  %d\n", w, h);	
}

#ifndef __sgi
 #include "texRay.inc"
#endif
#include "tex3d.inc"
#include "tex2d.inc"

void drawGL() { /* volume render using a single 3D texture */
	if (gDrawMode == 1)
		drawGL3D();
#ifndef __sgi
	else if (gDrawMode == 2)	
		drawGLRay();
#endif
	else
		drawGL2D();
}

void loadTex(unsigned char *vptr, int isInit) { /* volume render using a single 3D texture */
	if (gDrawMode == 1)
		loadTex3D(vptr, isInit);
#ifndef __sgi
	else if (gDrawMode == 2)	
		loadTexRay(vptr, isInit);
#endif
	else
		loadTex2D(vptr, isInit);
}

void changeMode() {
	if (gDrawMode == 1)
		freeTex3D();
#ifndef __sgi
	else if (gDrawMode == 2)	
		freeTexRay();
#endif 
	else
		freeTex2D();
	gDrawMode += 1;
/* Next turn off features specific to different rendering modes */
	glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glMatrixMode( GL_TEXTURE );
    glLoadIdentity();	
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_TEXTURE_3D);
    glColor3f(1.0f,1.0f,1.0f);
	if (gDrawMode > maxDrawMode) gDrawMode = 0; 
	printf("Draw mode set to %d (0=2D, 1=3D, 2=RayCast)\n", gDrawMode);
	scrnsize(gScrnWid,gScrnHt);
	loadTex(vptr, 1);
}

#include "palette.inc"

void resize(int w, int h) {
	gScrnWid = w;
	gScrnHt = h;
	#ifndef __sgi
	setupRenderRay();
	#endif	
	scrnsize(w,h);
}

void readVoxelData(char** argv) {/*load image data*/
	struct nifti_1_header hdr;
	FILE *fp;
	int fsize, nBytes;
	char command[1024];
	readHeader(argv, &hdr);
	#if !( __APPLE__) /* runtime check useless on modern OSX http://www.alecjacobson.com/weblog/?p=959 */
	if (!glutExtensionSupported("GL_EXT_texture3D")) {
	  printf("Fatal error: GL_EXT_texture3D not supported\n");
	  exit(0);
	}
	#endif
	nBytes = hdr.dim[1] *hdr.dim[2]*hdr.dim[3];
	vptr = (unsigned char *) malloc(  nBytes);
	if (isGz(argv)) {
		if (hdr.vox_offset > nBytes) {
			printf("please uncompress this image %s\n", argv[1]);
        	exit(-1);	    
    	}
		sprintf(command, "gunzip -c %s", argv[1]);
		fp = popen(command, "r");
		fread(vptr, (int)hdr.vox_offset, 1, fp);
		fread(vptr, nBytes, 1, fp);
		pclose ( fp );
	} else {
		fp = fopen(argv[1],"rb");
		fseek(fp, 0, SEEK_END); 
    	fsize = ftell(fp);
    	if (fsize < (nBytes + hdr.vox_offset) ) {
			printf("expected image to have at least %d bytes (filesize: %d)\n",nBytes + (int)hdr.vox_offset, fsize);
        	exit(-1);	    
    	}
    	fseek(fp, hdr.vox_offset, SEEK_SET);
		fread(vptr, nBytes, 1, fp);
		fclose(fp);
	}
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	changeLUT(0,0,0,1);
}

void drawScene(void) {
    if (gIsClipPlane)
    	glEnable(GL_CLIP_PLANE0);
    else
    	glDisable(GL_CLIP_PLANE0);
    while (gAzimuth < 0)
        gAzimuth += 360;   
    while (gAzimuth >= 360)
        gAzimuth -= 360;
    while (gElevation > 90)
        gElevation = 90;
    while (gElevation < -90)
        gElevation = -90;
    glClear( GL_COLOR_BUFFER_BIT  | GL_DEPTH_BUFFER_BIT );
    glAlphaFunc( GL_GREATER, 0.03f );
    glEnable(GL_BLEND);
    glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
    drawGL(); 
	glutSwapBuffers();
}

void mouseDown(int button, int state, int x, int y) {
		gMousePosX = x;
		gMousePosY = y;
}

void mouseMove(int mx, int my) {
	int thresh = 5;
	int dx = (mx-gMousePosX) / thresh;
	int dy = (my-gMousePosY) / thresh;
	if ((dx != 0) || (dy != 0)) {
		gAzimuth = gAzimuth - dx;
		gElevation = gElevation + dy;
		gMousePosX += dx * thresh;
		gMousePosY += dy * thresh;
		drawScene();
	}
}

double getUnixTime(void) {
    struct timespec ts;
	 #ifdef  __APPLE__ /* OS X does not have clock_gettime, use clock_get_time */
	clock_serv_t cclock;
	mach_timespec_t mts;
	host_get_clock_service(mach_host_self(), CALENDAR_CLOCK, &cclock);
	clock_get_time(cclock, &mts);
	mach_port_deallocate(mach_task_self(), cclock);
	ts.tv_sec = mts.tv_sec;
	ts.tv_nsec = mts.tv_nsec;
	#else
	clock_gettime(CLOCK_REALTIME, &ts);
	#endif   
    return (((double) ts.tv_sec) + (double) (ts.tv_nsec / 1000000000.0));
}

void animate(void) {
/* rotate object and report performance */
	double sec;
	#ifdef __sgi
		#define animationReportFrames 10
	#else
		#define animationReportFrames 100
	#endif
	if ((gStartClock == 0) || (gAnimationCount >= animationReportFrames)) {
		sec = (getUnixTime() - gStartClock);
		if ((gStartClock != 0) && (sec > 0.0))
			printf("frames per second: %g\n",  animationReportFrames /sec);
		gAnimationCount = 0;
		gStartClock = getUnixTime();
	}
	gAnimationCount++;
    gAzimuth += 5.0;
    glutPostRedisplay();
}

void specialInput(int key, int x, int y) {
/* respond to arrow keys */
	switch(key) {
	case GLUT_KEY_UP:
		gElevation -= 5.0;
		break;	
	case GLUT_KEY_DOWN:
		gElevation += 5.0;
		break;
	case GLUT_KEY_LEFT:
		gAzimuth += 5.0;
		break;
	case GLUT_KEY_RIGHT:
		gAzimuth -= 5.0;
		break;
	}
	drawScene();
}

void keyboard(unsigned char c, int x, int y) {
/* respond to key presses */
    switch(c) {
    case 27 :
        exit(0);
        break;
	case '1' :
		changeLUT(-8,0,0,0);
		break;
	case '2' :
		changeLUT(8,0,0,0);
		break;
	case '3' :
		changeLUT(0,-8,0,0);
		break;
	case '4' :
		changeLUT(0,8,0,0);
		break;
	case '5' :
		changeLUT(0,0,-1,0);
		break;
	case '6' :
		changeLUT(0,0,1,0);
		break;
    case 'm' :
		changeMode();
		break;
	case 'c' :
		gIsClipPlane = !gIsClipPlane;
		break;
	case 'q' : 
		if (gQuality == 1) {
			gQuality = 4;
			printf("Set for poorer quality (faster) graphics\n");
		} else {
			gQuality = 1;
			printf("Set for better quality (slower) graphics\n");
		}
		changeLUT(0,0,0,0);
		break;
    case 'b' :
    	gWhiteClearColor = !gWhiteClearColor;
    	if (gWhiteClearColor)
			glClearColor(1.0f, 1.0f, 1.0f, 0.0f);
		else
			glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
		break;
    default:
        break;
    }
	drawScene();
}

void printHelp() {
    printf("OpenGL 3d volume rendering\n\n");
    printf("Keyboard shortcuts\n");
    printf("arrow keys     : rotate object\n");
    printf("b key          : background color change\n");
    printf("c key          : clip plane on/off\n");
    printf("m key          : method (2D/3D/RayCast)\n");
    printf("q key          : quality better/worse\n");
    printf("1/2 keys       : change brightness\n");
    printf("3/4 keys       : change contrast\n");
    printf("5/6 keys       : change color table\n");
    printf("esc key        : quit\n");
}

void menu(int choice) {
    /* simple GLUT popup menu stuff */
    switch (choice) {
    case SPIN_ON :
	glutChangeToMenuEntry(1,"Random Spin OFF",SPIN_OFF);
	gStartClock = 0;
	glutIdleFunc(animate);
	break;
    case SPIN_OFF :
	glutChangeToMenuEntry(1,"Random Spin ON",SPIN_ON);
	glutIdleFunc(NULL);
	break;
    case MENU_HELP :
	printHelp();
	break;
    case MENU_EXIT :
	exit(0); 
	break;
    }
}

int main(int argc, char** argv) {
	if(argc == 1) {/*no image specified: read default image*/
		char literal[] = "vx.nii.gz";
		argv[1] = literal;
	}
	printf("Minimal NIfTI volume rendering\n");
	printf(" usage: %s <file>\n", argv[0]);
	glutInit(&argc, argv);
	glutInitWindowSize(gScrnWid, gScrnHt);
	glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE);
	glutCreateWindow("Volume Render");
	/* read texture data from a file */
	readVoxelData(argv);
	/* register specific routines to glut */
	glutDisplayFunc(drawScene);
	glutReshapeFunc(resize);
	glutKeyboardFunc(keyboard);
	glutMouseFunc(mouseDown);
	glutMotionFunc(mouseMove);
	glutSpecialFunc(specialInput);
	/* create popup menu for glut */
	glutCreateMenu(menu);
	glutAddMenuEntry("Random Spin ON", SPIN_ON  );
	glutAddMenuEntry("Help", MENU_HELP);
	glutAddMenuEntry("Exit", MENU_EXIT);
	glutAttachMenu(GLUT_RIGHT_BUTTON);
	/* loop forever */
	glutMainLoop();
	return 0;
}
