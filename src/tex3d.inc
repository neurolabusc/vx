GLuint gTex3D;

void freeTex3D () {
 //release textures used by 3D texture mapping
 glDeleteTextures(1, &gTex3D);
}

void loadTex3D(unsigned char *vptr, int isInit) { /* create single 3D texture */
	unsigned char *voxels,  *vp;
	uint32_t *rgba;
	int i, nBytes = gDimXYZ[0] * gDimXYZ[1] * gDimXYZ[2];
	static const GLdouble equation[] = {0.0, -0.707, -0.3, 0.2};
	voxels = (unsigned char *) malloc((4*nBytes));
	if (isInit) {
		printf("3D Texture requires %gmb (4 bytes per voxel)\n", 4.0*(double)nBytes/1048576.0);
		glClipPlane(GL_CLIP_PLANE0, equation);
		gTex3D = 0;
		glGenTextures(1, &gTex3D);
		glBindTexture(GL_TEXTURE_3D, gTex3D);
		glTexParameteri(GL_TEXTURE_3D,GL_TEXTURE_BASE_LEVEL,0);
		glTexParameteri(GL_TEXTURE_3D,GL_TEXTURE_MAX_LEVEL,0);
		glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		#ifdef __sgi
		  glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP);
		  glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP);
		  glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP);		
		#else
		  glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		  glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		  glTexParameteri(GL_TEXTURE_3D_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);
		#endif
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		
	}
	rgba = (uint32_t *) voxels;
	vp = vptr;
	for (i=0;i<nBytes;i++)
			*rgba++ = gRGBAlut[*vp++];
	glTexImage3DEXT(GL_TEXTURE_3D_EXT, 0, GL_RGBA8, gDimXYZ[0], gDimXYZ[1], gDimXYZ[2],0, GL_RGBA, GL_UNSIGNED_BYTE, voxels);
	free(voxels);
} /* loadTex3D() */

void drawGL3D() { /* volume render using a single 3D texture */
 //printf("Draw3D\n");
 float fz, renderQuality;    
	glMatrixMode( GL_TEXTURE );
    glLoadIdentity();
    glTranslatef( 0.5f, 0.5f, 0.5f );
    //glScalef(gScaleXYZ[0], gScaleXYZ[1], gScaleXYZ[2]);
    glScalef(gScale3DXYZ[0], gScale3DXYZ[1], gScale3DXYZ[2]);
    glRotatef(90,1,0,0);
  	glRotatef(gAzimuth,0,1,0);  
  	glRotatef(-gElevation,1,0,0);  
    glTranslatef( -0.5f,-0.5f, -0.5f );
    glEnable(GL_TEXTURE_3D);
    renderQuality = 1.7f * 1.0f/((float)gDimXYZ[0]+(float)gDimXYZ[1]+(float)gDimXYZ[2]) * gQuality;
    for (  fz = -0.5f; fz <= 0.5f; fz+=renderQuality ) {
    	float tz = fz + 0.5f; 
    	float vz = (fz*2.0f) - 0.2;
        glBegin(GL_QUADS);
			glTexCoord3f(0.0f, 0.0f,tz); 
		glVertex3f(-1.0f,-1.0f,vz);
			glTexCoord3f(1.0f, 0.0f, tz);  
		glVertex3f(1.0f,-1.0f,vz);
			glTexCoord3f(1.0f, 1.0f,tz);  
		glVertex3f(1.0f,1.0f,vz);
			glTexCoord3f(0.0f, 1.0f,tz);  
		glVertex3f(-1.0f,1.0f,vz);
        glEnd();
    }
} /* drawGL3D() */
