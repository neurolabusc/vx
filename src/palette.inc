/*color palette lookup table (LUT) functions */

uint32_t lerprgb (uint32_t lo, uint32_t hi, int loindex, int hiindex, int tarindex) {//linearly interpolate to blend RGBA colors
	int i;
	uint32_t ret;
	unsigned char* plo, *phi, *pret;
	float frac;
	frac = (float)(tarindex-loindex)/(hiindex-loindex);
	plo = (unsigned char*)&lo;
	phi = (unsigned char*)&hi;
	pret = (unsigned char*)&ret;
	for (i = 0; i < 4; i++) 
		pret[i] = (plo[i]+ frac*(phi[i]- plo[i]) ); 
	return ret;
}

struct RGBAnode {
    uint32_t rgba;
    int   intensity;
};

double round_c99(double x) { /* round is not part of classic C used by MPISpro */
    return (x >= 0.0) ? floor(x + 0.5) : ceil(x - 0.5);
}

struct RGBAnode makeRGBAnode (unsigned char r, unsigned char g, unsigned char b, float a, int inten) {
    struct RGBAnode ret;
    float ax = a;
    if (ax < 0) ax = 0;
    if (ax > 255) ax = 255;  
 #ifdef __sgi /* swapped endian */
    ret.rgba =  (r << 24)+ (g << 16) + (b << 8) + ((unsigned char)round_c99(ax) << 0); 
 #else
    ret.rgba =  (r << 0)+ (g << 8) + (b << 16) + ((unsigned char)round_c99(ax) << 24);
 #endif
    ret.intensity = inten;
    return ret;
}

void filllut(struct RGBAnode loNode, struct RGBAnode hiNode, uint32_t* lut) {
    int i, mn, mx;
    mn = (loNode.intensity >= 0) ? loNode.intensity : 0;
    mx = (hiNode.intensity <= 256) ? hiNode.intensity : 256;
    for (i = mn; i < mx; i++)
        lut[i] = lerprgb(loNode.rgba, hiNode.rgba, loNode.intensity, hiNode.intensity,i);
}

void createlutX(int colorscheme, uint32_t* lut) {
	float oc;
	int i;    
	int numNodes = 2; //default color scheme has two nodes: [0]black, [1]white
    struct RGBAnode nodes[8];
    if (gQuality == 1) 
    	oc = 0.75; /* thin slices are relatively translucent */
    else
    	oc = 1.5; /* thicker slices are more opaque */
    nodes[0] = makeRGBAnode(0,0,0,0,0); //assume minimum intensity is black
    nodes[1] = makeRGBAnode(255,255,255,128*oc,256); //assume maximum intensity is white

    switch (colorscheme) {
        case 1: //1=hot
            numNodes = 4;
            nodes[0] = makeRGBAnode(3,0,0,0,0);
            nodes[1] = makeRGBAnode(255,0,0,48*oc,96);
            nodes[2] = makeRGBAnode(255,255,0,96*oc,192);
            nodes[3] = makeRGBAnode(255,255,255,128*oc,256);
            break;
        case 2: //2=winter
            numNodes = 3;
            nodes[0] = makeRGBAnode(0,0,255,0*oc,0);
            nodes[1] = makeRGBAnode(0,128,96,64*oc,128);
            nodes[2] = makeRGBAnode(0,255,128,128*oc,256);
            break;
        case 3: //3=warm
            numNodes = 3;
            nodes[0] = makeRGBAnode(255,127,0,0,0);
            nodes[1] = makeRGBAnode(255,196,0,64*oc,128);
            nodes[2] = makeRGBAnode(255,254,0,128*oc,256);
            break;
        case 4: //4=cool
            numNodes = 3;
            nodes[0] = makeRGBAnode(0,127,255,0,0);
            nodes[1] = makeRGBAnode(0,196,255,64*oc,128);
            nodes[2] = makeRGBAnode(0,254,255,128*oc,256);
            break;
        case 5: //5=red/yellow
            numNodes = 3;
            nodes[0] = makeRGBAnode(192,1,0,0,0);
            nodes[1] = makeRGBAnode(224,128,0,64*oc,128);
            nodes[2] = makeRGBAnode(255,255,0,128*oc,256);
            break;
        case 6: //6=blue/green
            numNodes = 3;
            nodes[0] = makeRGBAnode(0,1,222,0,0);
            nodes[1] = makeRGBAnode(0,128,127,64*oc,128);
            nodes[2] = makeRGBAnode(0,255,32,128*oc,256);
            break;
        case 7: //7=actc
            numNodes = 5;
            nodes[1] = makeRGBAnode(0,0,136,32*oc,64);
            nodes[2] = makeRGBAnode(24,177,0,64*oc,128);
            nodes[3] = makeRGBAnode(248,254,0,78*oc,156);
            nodes[4] = makeRGBAnode(255,0,0,128*oc,256);
            break;
        case 8: //8=bone
            numNodes = 3;
            nodes[1] = makeRGBAnode(103,126,165,76*oc,153);
            nodes[2] = makeRGBAnode(255,255,255,128*oc,256);
            break;
        case 9: //9=gold
            numNodes = 4;
            nodes[1] = makeRGBAnode(142,85,14,42*oc,85);
            nodes[2] = makeRGBAnode(227,170,76,84*oc,170);
            nodes[3] = makeRGBAnode(255,255,255,128*oc,256);
            break;
        case 10: //10=hotiron
            numNodes = 4;
            nodes[1] = makeRGBAnode(255,0,0,64*oc,128);
            nodes[2] = makeRGBAnode(255,126,0,96*oc,191);
            nodes[3] = makeRGBAnode(255,255,255,128*oc,256);
            break;
        case 11: //11=surface
            numNodes = 3;
            nodes[1] = makeRGBAnode(208,128,128,76*oc,153);
            nodes[2] = makeRGBAnode(255,255,255,128*oc,256);
            break;
        case 12: //12=red
            nodes[1] = makeRGBAnode(255,0,0,128*oc,256);
            break;
        case 13: //13=green
            nodes[1] = makeRGBAnode(0,255,0,128*oc,256);
            break;
        case 14: //14=blue
            nodes[1] = makeRGBAnode(0,0,255,128*oc,256);
            break;
    }

    for (i = 1; i < numNodes; i++)
        filllut(nodes[i-1], nodes[i], lut);
    return;
}

void changeLUT(int brightness, int contrast, int table, int isInit) {
 tRGBAlut luto; //our original color table, without our brightness/contrast selection
int i, idx;
float slopef, cenf;
 gWindowCenter += brightness;
 if (gWindowCenter < 0) gWindowCenter = 0;  
 if (gWindowCenter > 255) gWindowCenter = 255; 
 gWindowWidth += contrast; 
 if (gWindowWidth < 4) gWindowWidth = 4;  
 if (gWindowWidth > 256) gWindowWidth = 256;
 gColorTable += table;       
 if (gColorTable < 0) gColorTable = maxgColorTable;  
 if (gColorTable > maxgColorTable) gColorTable = 0;       
 slopef = 255.0f/ (float)gWindowWidth;
 cenf = 1.0f * (float)gWindowCenter;
 createlutX(gColorTable, luto);
 gRGBAlut[0] = luto[0]; /* for segmented images, air always clear */
 for (i = 1; i < 256; i++) { /* from 1 instead of 0: air always transparent */
 	idx = trunc(128.0f + ((i - cenf) * slopef));
  	if (idx < 0) idx = 0;
 	if (idx > 255) idx = 255;
 	gRGBAlut[i] = luto[idx];
 }
 if (!isInit)
 	printf("palette %d with brightness (center) %d and contrast (width) %d \n", gColorTable, gWindowCenter, gWindowWidth); 
 /* IN THEORY for SGI we only need to update the color palette, we do not need to modify the textures */
 /*
 #ifdef __sgi 
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glColorTableSGI( GL_TEXTURE_COLOR_TABLE_SGI, GL_RGBA8_EXT, 256, GL_RGBA, GL_UNSIGNED_BYTE, gRGBAlut);
    glEnable(GL_TEXTURE_COLOR_TABLE_SGI); 
	 if (isInit) {
		loadTex(vptr, isInit);
		free(vptr);
	 } 
 #else */
 	loadTex(vptr, isInit);
 /*#endif*/
}
