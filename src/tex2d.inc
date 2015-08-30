/* global variables specific to 2D */
GLuint *gTex2D;

void freeTex2D () {
 //release textures used by 2D texture mapping
 int nTex;
 nTex = gDimXYZ[0] + gDimXYZ[1] + gDimXYZ[1]; //for each of three dimensions, stack of 2D slices aligned to that dim
 glDeleteTextures(nTex, gTex2D);
}

void loadTex2D(unsigned char *vptr, int isInit) { /* load stack of 2D textures */
static const GLdouble clipPlane2D[] = {0.0, -0.707, 0.3, 0.3};
unsigned char *sliceVx, *vp;
uint32_t *rgbaVx;
int sliceBytes, nTex, slice, yoff, i;
	nTex = gDimXYZ[0] + gDimXYZ[1] + gDimXYZ[1]; //for each of three dimensions, stack of 2D slices aligned to that dim
	if (isInit) {
		printf("2D Textures require %gmb (12 bytes per voxel)\n", (3.0f * 4.0f * (float)(gDimXYZ[0]*gDimXYZ[1]*gDimXYZ[2]))/1048576.0);
		gTex2D = (GLuint *) malloc(nTex * sizeof(GLuint *));
		glGenTextures(nTex, gTex2D);
		glClipPlane(GL_CLIP_PLANE0, clipPlane2D);
	}
	//AXIAL load Slices of dimensions [1,2] (AXIAL) - simple as these are in-plane
	sliceBytes = gDimXYZ[0] * gDimXYZ[1];
	rgbaVx = (uint32_t *) malloc(sliceBytes * 4);
	for(i=0; i< gDimXYZ[2]; i++) {
			glBindTexture(GL_TEXTURE_2D, gTex2D[i]);
			yoff = i * sliceBytes;
			for (slice = 0; slice < sliceBytes; slice++)
				rgbaVx[slice] = gRGBAlut[vptr[slice+ yoff] ];
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, gDimXYZ[0], gDimXYZ[1], 0, GL_RGBA, GL_UNSIGNED_BYTE, rgbaVx);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP); 
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	}
	free(rgbaVx);
	//CORONAL load Slices of dimension [1,3]
	sliceBytes = gDimXYZ[0] * gDimXYZ[2];
	sliceVx = (unsigned char *) malloc(sliceBytes);
	rgbaVx = (uint32_t *) malloc(sliceBytes * 4);
	for(i=0; i< gDimXYZ[1]; i++) {
			yoff = i * gDimXYZ[0];
			for (slice = 0; slice < gDimXYZ[2]; slice++) {
				vp = vptr + yoff + (slice*gDimXYZ[0]*gDimXYZ[1]) ;
				memcpy(&sliceVx[gDimXYZ[0]*slice], vp, gDimXYZ[0] * sizeof(unsigned char));
			}
			for (slice = 0; slice < sliceBytes; slice++)
				rgbaVx[slice] = gRGBAlut[sliceVx[slice] ];
			glBindTexture(GL_TEXTURE_2D, gTex2D[i+gDimXYZ[2]]);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, gDimXYZ[0], gDimXYZ[2], 0, GL_RGBA, GL_UNSIGNED_BYTE, rgbaVx);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP); 
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	}
	free(sliceVx);
	free(rgbaVx);
	//SAGITTAL load Slices of dimension [2,3]
	sliceBytes = gDimXYZ[1] * gDimXYZ[2];
	sliceVx = (unsigned char *) malloc(sliceBytes);
	rgbaVx = (uint32_t *) malloc(sliceBytes * 4);
	for(i=0; i< gDimXYZ[0]; i++) {
			for (slice = 0; slice < gDimXYZ[1]*gDimXYZ[2]; slice++) {
				int q = i+ (slice * gDimXYZ[0]);
				sliceVx[slice] =vptr[q];
			}
			for (slice = 0; slice < sliceBytes; slice++)
				rgbaVx[slice] = gRGBAlut[sliceVx[slice] ];
			glBindTexture(GL_TEXTURE_2D, gTex2D[i+gDimXYZ[1]+gDimXYZ[2]]);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, gDimXYZ[1], gDimXYZ[2], 0, GL_RGBA, GL_UNSIGNED_BYTE, rgbaVx);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP); 
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	}
	free(sliceVx);
	free(rgbaVx);
	
} /* loadTex() */

void drawGL2D() { /*see page 52-53 of Engel et al., (2008) Real-time volume graphics */
	/* volume render using a series of 2D textures */
	int nslices, slice, i;
	float fStep, vF, vLR, vUD;
	int sliceStep = 1;
	int orient; /* 0..6: camera with respect to face of cube 0=superior,1=inferior,2=posterior,3=anterior,4=left,5=right */
	glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
  	glRotatef(-gElevation,1,0,0); 
  	glRotatef(gAzimuth,0,1,0);
	glDisable(GL_DEPTH_TEST);
	glEnable(GL_TEXTURE_2D);
	if (gElevation > 45) 
		orient = 0;
	else if (gElevation < -45) 
		orient = 1; 
	else if ((gAzimuth > 315) || (gAzimuth < 45)) 
		orient = 3;
	else if (gAzimuth < 135) 
		orient = 4;
	else if (gAzimuth < 225) 
		orient = 2;
	else
		orient = 5;	
	switch ((int)(orient/2)) {
		case 0:
			/*axial: plane=XY, slices=Z*/
			nslices = gDimXYZ[2];
			slice = 0;
			vLR = gScale2DXYZ[0]; 	
			vUD = gScale2DXYZ[1];
			vF = -gScale2DXYZ[2]; 
			break;
		case 1:
			/*coronal: plane=XZ, slices=Y*/
			nslices = gDimXYZ[1];
			slice = gDimXYZ[2];
			vLR = gScale2DXYZ[0]; 	
			vF = -gScale2DXYZ[1]; 
			vUD = gScale2DXYZ[2];
			break;
		default:
			/*sagittal: plane=YZ, slices=X*/
			nslices = gDimXYZ[0];
			slice = gDimXYZ[2]+gDimXYZ[1];
			vUD = gScale2DXYZ[2]; 
			vLR= gScale2DXYZ[1];
			vF = -gScale2DXYZ[0];
			break;
	}
	fStep = (fabs(vF) * 2)/nslices;
	if (orient & 1) {
		slice = slice+nslices-1;
		sliceStep = -sliceStep;
		fStep = -fStep;
		vF = -vF;
	}
	if (orient > 3) { /*sagittal slice orientation*/
		for (i = 0; i < nslices; i++) {
			if ( i % gQuality == 0 ) {
				glBindTexture(GL_TEXTURE_2D, gTex2D[slice]);
				glBegin(GL_QUADS);
					glTexCoord2f( 0, 0);
					glVertex3d(vF, -vUD, -vLR);
					glTexCoord2f( 1, 0);
					glVertex3d(vF, -vUD,  vLR);
					glTexCoord2f( 1, 1);
					glVertex3d(vF, vUD,  vLR);
					glTexCoord2f( 0, 1);
					glVertex3d(vF, vUD, -vLR);			
				glEnd();
			}
			slice += sliceStep;
			vF += fStep;
		}
		return;
	} else if (orient < 2) { /*axial slice orientation*/
		for (i = 0; i < nslices; i++) {
			if ( i % gQuality == 0 ) {
				glBindTexture(GL_TEXTURE_2D, gTex2D[slice]);
				glBegin(GL_QUADS);
					glTexCoord2f( 0, 0);
					glVertex3d( -vLR, vF, -vUD);
					glTexCoord2f( 0, 1);
					glVertex3d(-vLR, vF, vUD);
					glTexCoord2f( 1, 1);
					glVertex3d(vLR, vF, vUD);
					glTexCoord2f( 1, 0);
					glVertex3d(vLR, vF, -vUD);
				glEnd();
			}
			slice += sliceStep;
			vF += fStep;
		}
		return;
	} /*else must be coronal slice orientation...*/
	for (i = 0; i < nslices; i++) {
		if ( i % gQuality == 0 ) {
			glBindTexture(GL_TEXTURE_2D, gTex2D[slice]);
			glBegin(GL_QUADS);
				glTexCoord2f( 0, 0);
				glVertex3d( -vLR, -vUD, vF);
				glTexCoord2f( 0, 1);
				glVertex3d(-vLR, vUD, vF);
				glTexCoord2f( 1, 1);
				glVertex3d(vLR, vUD, vF);
				glTexCoord2f( 1, 0);
				glVertex3d(vLR, -vUD, vF);
			glEnd();
		}
		slice += sliceStep;
		vF += fStep;
	}
} /* drawGL()  */
