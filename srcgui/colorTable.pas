unit colorTable;

{$ifdef fpc}{$mode delphi}{$endif}

interface
uses
  dglOpenGL,   Classes, SysUtils;

const  //maximum number of control points for color schemes...
  maxNodes = 6;

type
  TRGBA = packed record //Next: analyze Format Header structure
    R,G,B,A : byte;
  end;
  TScale = array [1..3] of single;
  tVolB = array of byte;
  tVolW = array of word;
  tVolS = array of single;
  tVolRGBA = array of TRGBA;//longword;
  TLUTnodes = record
	//numnodes : integer;
	rgba: array [0..maxNodes] of TRGBA;
        intensity: array [0..maxNodes] of integer;
	end;

Procedure UpdateTransferFunction (var lIndex: integer; LUTCenter,LUTWidth: integer; var TransferTexture : GLuint);//change color table

implementation

procedure setNode (r,g,b,a,i, node: integer; var  lLUTnodes : TLUTnodes);
begin
  lLUTnodes.rgba[node].R := r;
  lLUTnodes.rgba[node].G := g;
  lLUTnodes.rgba[node].B := b;
  lLUTnodes.rgba[node].A := a;
  lLUTnodes.intensity[node] := i;
end;

function makeLUT(var lIndex: integer): TLUTnodes;
begin
  //generate default grayscale color table
  //result.numnodes := 2; //number of nodes implicit: final node has intensity=255
  setNode(0,0,0,0,0, 0, result);
  setNode(255,255,255,255,255, 1, result);
  case lIndex of //generate alternative color table if specified
       1: begin //HotLut
          //result.numnodes:=4;
          setNode(3,0,0,0,0, 0, result);
          setNode(255,0,0,48,95, 1, result);
          setNode(255,255,0,96,191, 2, result);
          setNode(255,255,255,128,255, 3, result);
       end;
       2: begin //bone
          //result.numnodes:=3;
          setNode(0,0,0,0,0, 0, result);
          setNode(103,126,165,76,153, 1, result);
          setNode(255,255,255,128,255, 2, result);
       end;
       3: begin //WinterLut
          //result.numnodes:=3;
          setNode(0,0,255,0,0, 0, result);
          setNode(0,128,196,64,128, 1, result);
          setNode(0,255,128,128,255, 2, result);
       end;
       4: begin //GE-Color
          //result.numnodes:=5;
          setNode(0,0,0,0,0, 0, result);
          setNode(0,128,125,32,63, 1, result);
          setNode(128,0,255,64,128, 2, result);
          setNode(255,128,0,96,192, 3, result);
          setNode(255,255,255,128,255, 4, result);
       end;
       5: begin //ACTC
          //result.numnodes:=5;
          setNode(0,0,0,0,0, 0, result);
          setNode(0,0,136,32,64, 1, result);
          setNode(24,177,0,64,128, 2, result);
          setNode(248,254,0,78,156, 3, result);
          setNode(255,0,0,128,255, 4, result);
       end;
       6: begin //X-rain
          //result.numnodes:=7;
          setNode(0,0,0,0,0, 0, result);
          setNode(64,0,128,8,32, 1, result);
          setNode(0,0,255,16,64, 2, result);
          setNode(0,255,0,24,96, 3, result);
          setNode(255,255,0,32,160, 4, result);
          setNode(255,192,0,52,192, 5, result);
          setNode(255,3,0,80,255, 6, result);
       end;
       else
           lIndex := 0;  //index unknown!!!
  end; //case: alternative LUTs
end; //makeLUT()

function lerpRGBA (p1,p2: TRGBA; frac: single): TRGBA;
//linear interpolation
begin
  result.R := round(p1.R + frac * (p2.R - p1.R));
  result.G := round(p1.G + frac * (p2.G - p1.G));
  result.B := round(p1.B + frac * (p2.B - p1.B));
  result.A := round(p1.A + frac * (p2.A - p1.A));
end;//lerpRGBA()

procedure LoadLUT (var lIndex: integer; LUTCenter,LUTWidth: integer; var lLUT: tVolRGBA);
var
 lLUTnodes :TLUTnodes;
 lInc,lNodeLo: integer;
 frac, f: single;
begin
 lLUTNodes := makeLUT(lIndex);
 lNodeLo := 0;
 if LUTWidth <= 0 then exit;
 lLUT[0] := lerpRGBA(lLUTNodes.rgba[0],lLUTNodes.rgba[0],1);
 for lInc := 1 to 255 do begin
   f := 128 + ((lInc-LUTCenter)*255/LUTWidth);
   if (f < 0) then f := 0;
   if (f > 255) then f := 255;
   //if ((lNodeLo+1) < lLUTNodes.numnodes) and ( f > lLUTNodes.intensity[lNodeLo + 1] ) then
   if ( f > lLUTNodes.intensity[lNodeLo + 1] ) then
      lNodeLo := lNodeLo + 1;
   frac := (f-lLUTNodes.Intensity[lNodeLo])/(lLUTNodes.Intensity[lNodeLo+1]-lLUTNodes.Intensity[lNodeLo]);
   if (frac < 0) then frac := 0;
   if frac > 1 then frac := 1;
   lLUT[lInc] := lerpRGBA(lLUTNodes.rgba[lNodeLo],lLUTNodes.rgba[lNodeLo+1],frac);
 end;
end;//LoadLUT()

Procedure UpdateTransferFunction (var lIndex: integer; LUTCenter,LUTWidth: integer; var TransferTexture : GLuint);
var
 lLUT: tVolRGBA;
begin
 setlength(lLUT,256*4);
 LoadLUT (lIndex, LUTCenter,LUTWidth, lLUT);
 if TransferTexture = 0 then begin
  glGenTextures(1, @TransferTexture);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
 end;
 glBindTexture(GL_TEXTURE_1D, TransferTexture);
 glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP);
 glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexParameterf(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
 glTexImage1D(GL_TEXTURE_1D, 0, GL_RGBA, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, @lLUT[0]);
 lLUT := nil;
end; //UpdateTransferFunction()

end.

