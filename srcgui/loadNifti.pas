unit loadNifti;
{$IFDEF FPC}{$mode objfpc}{$H+}{$ENDIF}
interface
{$IFDEF FPC}
 {$DEFINE GZIP}
{$ENDIF}
uses
   colorTable, dglOpenGL,
  {$IFDEF GZIP}{$IFDEF FPC}zstream, {$ELSE} zlib,{$ENDIF}{$ENDIF} //Freepascal includes the handy zstream function for decompressing GZip files
  forms,dialogs,sysutils,Classes;

function Load3DTextures (FileName : AnsiString; var  gradientVolume,intensityVolume  : GLuint; var isRGBA: integer; var ScaleDim: TScale; loadGradients: boolean): boolean;// Load 3D image                                                                 }
procedure ShowDebug (lS: AnsiString);

implementation

uses main; //for error reporting

//Written by Chris Rorden, released under BSD license
//This is the header NIfTI format http://nifti.nimh.nih.gov/nifti-1/
//NIfTI is popular in neuroimaging - should be compatible for Analyze format
//   http://eeg.sourceforge.net/ANALYZE75.pdf
//NIfTI format images have two components:
// 1.) Header data provides image dimensions and details
// 2.) Image data
//These two components can be separate files: MRI.hdr, MRI.img
//  or a single file with the header at the start MRI.nii
//Note raw image daya begins vox_offset bytes into the image data file
//  For example, in a typical NII file, the header is the first 348 bytes,
//  but the image data begins at byte 352 (as this is evenly divisible by 8)
Type
  TNIFTIhdr = packed record //NIfTI header structure
   HdrSz : longint; //MUST BE 348
   Data_Type: array [1..10] of ansichar; //unused
   db_name: array [1..18] of ansichar; //unused
   extents: longint; //unused
   session_error: smallint; //unused                  `
   regular: ansichar; ////unused: in Analyze 7.5 this must be 114
   dim_info: byte; //MRI slice order
   dim: array[0..7] of smallint; //Data array dimensions
   intent_p1, intent_p2, intent_p3: single;
   intent_code: smallint;
   datatype: smallint;
   bitpix: smallint;
   slice_start: smallint;
   pixdim: array[0..7]of single;
   vox_offset: single;
   scl_slope: single;//scaling slope
   scl_inter: single;//scaling intercept
   slice_end: smallint;
   slice_code: byte; //e.g. ascending
   xyzt_units: byte; //e.g. mm and sec
   cal_max,cal_min: single; //unused
   slice_duration: single; //time for one slice
   toffset: single; //time axis to shift
   glmax, glmin: longint; //UNUSED
   descrip: array[1..80] of ansichar;
   aux_file: array[1..24] of ansichar;
   qform_code, sform_code: smallint;
   quatern_b,quatern_c,quatern_d,
   qoffset_x,qoffset_y,qoffset_z: single;
   srow_x: array[0..3]of single;
   srow_y: array[0..3]of single;
   srow_z: array[0..3]of single;
   intent_name: array[1..16] of ansichar;
   magic: longint;
 end; //TNIFTIhdr Header Structure

const
      kRGBAclear : TRGBA = (r: 0; g: 0; b: 0; a:0);

procedure ShowDebug (lS: AnsiString);
begin
Form1.Hint := lS;;
Form1.ErrorTimer1.enabled := true;
end;


Function XYZI (X1,X2,Y1,Y2,Z1,Z2: single; Center: byte): TRGBA;
//gradients in range -1..1
//input voxel intensity to the left,right,anterior,posterior,inferior,superior and center
// Output RGBA image where values correspond to X,Y,Z gradients and ImageIntensity
//AlphaT will make a voxel invisible if center intensity is less than specified value
// Voxels where there is no gradient (no edge boundary) are made transparent
var
  X,Y,Z,Dx: single;
begin
  Result := kRGBAclear;
  if Center < 1 then
    exit; //intensity less than threshold: make invisible
  X := X1-X2;
  Y := Y1-Y2;
  Z := Z1-Z2;
  Dx := sqrt(X*X+Y*Y+Z*Z);
  if Dx = 0 then
    exit;  //no gradient - set intensity to zero.
  result.r :=round((X/(Dx*2)+0.5)*255); //X
  result.g :=round((Y/(Dx*2)+0.5)*255); //Y
  result.b := round((Z/(Dx*2)+0.5)*255); //Z
  result.a := Center;
end;

function Sobel (rawData: tVolB; Xsz,Ysz, I : integer; var GradMag: single): TRGBA;
//this computes intensity gradients using 3D Sobel filter.
//Much slower than central difference but more accurate
//http://www.aravind.ca/cs788h_Final_Project/gradient_estimators.htm
var
  Y,Z,J: integer;
  Xp,Xm,Yp,Ym,Zp,Zm: single;
begin
  GradMag := 0;//gradient magnitude
  Result := kRGBAclear;
  if rawData[i] < 1 then
    exit; //intensity less than threshold: make invisible
  Y := XSz; //each row is X voxels
  Z := YSz*XSz; //each plane is X*Y voxels
  //X:: cols: +Z +0 -Z, rows -Y +0 +Y
  J := I+1;
  Xp := rawData[J-Y+Z]+3*rawData[J-Y]+rawData[J-Y-Z]
        +3*rawData[J+Z]+6*rawData[J]+3*rawData[J-Z]
        +rawData[J+Y+Z]+3*rawData[J+Y]+rawData[J+Y-Z];
  J := I-1;
  Xm := rawData[J-Y+Z]+3*rawData[J-Y]+rawData[J-Y-Z]
        +3*rawData[J+Z]+6*rawData[J]+3*rawData[J-Z]
        +rawData[J+Y+Z]+3*rawData[J+Y]+rawData[J+Y-Z];
  //Y:: cols: +Z +0 -Z, rows -X +0 +X
  J := I+Y;
  Yp := rawData[J-1+Z]+3*rawData[J-1]+rawData[J-1-Z]
        +3*rawData[J+Z]+6*rawData[J]+3*rawData[J-Z]
        +rawData[J+1+Z]+3*rawData[J+1]+rawData[J+1-Z];
  J := I-Y;
  Ym := rawData[J-1+Z]+3*rawData[J-1]+rawData[J-1-Z]
        +3*rawData[J+Z]+6*rawData[J]+3*rawData[J-Z]
        +rawData[J+1+Z]+3*rawData[J+1]+rawData[J+1-Z];
  //Z:: cols: +Z +0 -Z, rows -X +0 +X
  J := I+Z;
  Zp := rawData[J-Y+1]+3*rawData[J-Y]+rawData[J-Y-1]
        +3*rawData[J+1]+6*rawData[J]+3*rawData[J-1]
        +rawData[J+Y+1]+3*rawData[J+Y]+rawData[J+Y-1];
  J := I-Z;
  Zm := rawData[J-Y+1]+3*rawData[J-Y]+rawData[J-Y-1]
        +3*rawData[J+1]+6*rawData[J]+3*rawData[J-1]
        +rawData[J+Y+1]+3*rawData[J+Y]+rawData[J+Y-1];
  result := XYZI (Xm,Xp,Ym,Yp,Zm,Zp,rawData[I]);
  GradMag :=  sqrt( sqr(Xm-Xp)+sqr(Ym-Yp)+sqr(Zm-Zp));//gradient magnitude
end;

procedure NormVol (var Vol: tVolS);
var
  n,i: integer;
  mx,mn: single;
begin
  n := length(Vol);
  if n < 1 then
    exit;
  mx := Vol[0];
  mn := Vol[0];
  for i := 0 to (n-1) do begin
    if Vol[i] > mx then
      mx := Vol[i];
    if Vol[i] < mn then
      mn := Vol[i];
  end;
  if mx = mn then
    exit;
  mx := mx-mn;//range
  for i := 0 to (n-1) do
    Vol[i] := (Vol[i]-mn)/mx;
end;

function SmoothVol (var rawData: tVolB; lXdim,lYdim,lZdim: integer): integer;
//simple 3D smoothing for noisy data - makes images blurry
//this is useful prior to generating gradients, as it reduces stepping
const
  kCen : single = 2/3; //center of kernel is 2/3
  kEdge : single = 1/6; //voxel on each edge is 1/6
var
   lSmoothImg,lSmoothImg2: tVolS;
   lSliceSz,lZPos,lYPos,lX,lY,lZ,lnVox,lVox: integer;
begin
   result := -1;
   lSliceSz := lXdim*lYdim;
   lnVox := lSliceSz*lZDim;
    if (lnVox < 0) or (lXDim < 3) or (lYDim < 3) or (lZDim < 3) then begin
	    showDebug('Smooth3DNII error: Image dimensions are not large enough to filter.');
	    exit;
   end;
  setlength(lSmoothImg,lnVox);
  setlength(lSmoothImg2,lnVox);
  for lX := 0 to (lnVox-1) do
    lSmoothImg[lX] := rawData[lX];
  for lX := 0 to (lnVox-1) do
    lSmoothImg2[lX] := rawData[lX];
  //X-direction - copy from SmoothImg -> SmoothImg2
  for lZ := 2 to lZdim-1 do begin
    lZPos := (lZ-1)*lSliceSz;
    for lY := 2 to lYdim-1 do begin
      lYPos := (lY-1)*lXdim;
      for lX := 2 to lXdim-1 do begin
            lVox := lZPos+lYPos+lX-1;//-1 as indexed from 0
            lSmoothImg2[lVox] := (lSmoothImg[lVox-1]*kEdge)+(lSmoothImg[lVox]*kCen)+(lSmoothImg[lVox+1]*kEdge);
      end; {lX}
    end; {lY}
  end; {lZ loop for X-plane}
  //Y-direction - copy from SmoothImg2 -> SmoothImg
  for lZ := 2 to lZdim-1 do begin
    lZPos := (lZ-1)*lSliceSz;
    for lY := 2 to lYdim-1 do begin
      lYPos := (lY-1)*lXdim;
      for lX := 2 to lXdim-1 do begin
            lVox := lZPos+lYPos+lX-1;//-1 as indexed from 0
            lSmoothImg[lVox] := (lSmoothImg2[lVox-lXdim]*kEdge)+(lSmoothImg2[lVox]*kCen)+(lSmoothImg2[lVox+lXdim]*kEdge);
      end; {lX}
    end; {lY}
  end; {lZ loop for Y-plane}
  //Z-direction - copy from SmoothImg -> SmoothImg2
  for lZ := 2 to lZdim-1 do begin
    lZPos := (lZ-1)*lSliceSz;
    for lY := 2 to lYdim-1 do begin
      lYPos := (lY-1)*lXdim;
      for lX := 2 to lXdim-1 do begin
            lVox := lZPos+lYPos+lX-1;//-1 as indexed from 0
            lSmoothImg2[lVox] := (lSmoothImg[lVox-lSliceSz]*kEdge)+(lSmoothImg[lVox]*kCen)+(lSmoothImg[lVox+lSliceSz]*kEdge);
      end; {lX}
    end; {lY}
  end; {lZ loop for X-plane}
   //next make this in the range 0..255
  for lX := 0 to (lnVox-1) do
    rawData[lX] := round(lSmoothImg2[lX]);
  lSmoothImg2 := nil;
  lSmoothImg := nil;
end;

procedure CreateGradientVolume (rData: tVolB; Xsz,Ysz,Zsz, isRGBA: integer; var gradientVolume : GLuint);
//compute gradients for each voxel... Output texture in form RGBA
//  RGB will represent as normalized X,Y,Z gradient vector:  Alpha will store gradient magnitude
const
  kEdgeSharpness = 255;//value 1..255: 1=all edges transparent, 255=edges very opaque
var
  X, Y,Z,Index,XYsz : Integer;
  VolData: tVolB;
  tRGBA,VolRGBA: tVolRGBA;
  GradMagS: tVolS;
Begin
  tRGBA := nil;
  if (XSz < 1) or (YSz < 1) or (ZSz < 1) then
    exit;
  XYsz :=  Xsz*Ysz;
  Setlength (VolData,XYsz*Zsz);
  if isRGBA = 1 then begin
     tRGBA := tVolRGBA(rData );
     for Index := 0 to ((XYsz*Zsz)-1) do
      VolData[Index] := tRGBA[Index].a;
  end else
    for Index := 0 to ((XYsz*Zsz)-1) do
      VolData[Index] := rData[Index];
  //next line: blur the data
  SmoothVol (VolData, Xsz,Ysz,Zsz);
  SetLength (VolRGBA, XYsz*Zsz);
  SetLength (GradMagS,XYsz*Zsz);
  for Index := 0 to ((XYsz*Zsz)-1) do //we can not compute gradients for image edges, so initialize volume so all voxels are transparent
    VolRGBA[Index] := kRGBAclear;
  for Z := 1 To Zsz - 2 do  //for X,Y,Z dimensions indexed from zero, so := 1 gives 1 voxel border
    for Y := 1 To Ysz - 2 do
      for X := 1 To Xsz - 2 do begin
        Index := (Z * XYsz) + (Y * Xsz) + X;
        //Next line computes gradients using Sobel filter
        VolRGBA[Index] := Sobel (VolData, Xsz,Ysz, Index,GradMagS[Index]);
        //Next line computes gradients using Central Difference
        //VolRGBA[Index] := XYZI (rawData[Index-1],rawData[Index+1],rawData[Index-Xsz],rawData[Index+Xsz],rawData[Index-XYsz],rawData[Index+XYsz],rawData[Index],AlphaT);
      end;//X
  VolData := nil;
  //next: generate normalized gradient magnitude values
  NormVol (GradMagS);
  for Index := 0 to ((XYsz*Zsz)-1) do
    VolRGBA[Index].A := round(GradMagS[Index]*kEdgeSharpness);
  GradMagS := nil;
  glPixelStorei(GL_UNPACK_ALIGNMENT,1);
  glGenTextures(1, @gradientVolume);
  glBindTexture(GL_TEXTURE_3D, gradientVolume);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);
  glTexImage3D(GL_TEXTURE_3D, 0,GL_RGBA, Xsz, Ysz,Zsz,0, GL_RGBA, GL_UNSIGNED_BYTE,@VolRGBA[0]);
  VolRGBA := nil;
end;

procedure LoadBorg(Dim: integer; var  rawData: tVolB; var Xo,Yo,Zo, isRGBA: integer; var ScaleDim: TScale);
const
 Border = 4;//margin so we can calculate gradients at edge
var
 F: array of single;
 mn, mx, scale: single;
 I, X, Y, Z: integer;
begin
 IsRGBA := 0;
 ScaleDim[1] := 1;
 ScaleDim[2] := 1;
 ScaleDim[3] := 1;
 Xo := Dim;
 Yo := Dim;
 Zo := Dim;
 SetLength(F, Dim*Dim*Dim);
 Scale := 0.005;
 I := 0;
 for X := 0 to Dim-1 do
  for Y := 0 to Dim-1 do
   for Z := 0 to Dim-1 do
   begin
    if (X < Border) or (Y < Border) or (Z < Border) or ((Dim-X) < Border) or ((Dim-Y) < Border) or ((Dim-Z) < Border) then
     F[I] := 0
    else
     F[I] := sin(scale *x *y) + sin(scale *y * z) + sin(scale *z * x);
    Inc(I);
   end;
 //next find range...
 mn := F[0];
 for I := 0 to Dim*Dim*Dim-1 do
  if F[I] < mn then
   mn := F[I];
 mx := F[0];
 for I := 0 to Dim*Dim*Dim-1 do
  if F[I] > mx then
   mx := F[I];
 scale := 255/(mx-mn);
 SetLength(RawData, Dim*Dim*Dim);
 for I := 0 to Dim*Dim*Dim-1 do begin
  if F[I] <= 0 then
   RawData[I] := 0
  else
   RawData[I] := Round((F[I]-mn)*scale);
 end;
 F := nil;
end;

function FloatMaxVal (lA,lB,lC: single): single;
//returns largest of three values
begin
 if (lA > lB) and (lA > lC) then
  result := lA
 else if lB > lC then
  result := lB
 else
  result := lC;
end; //func FloatMaxVal

{$IFDEF GZIP}
{$IFNDEF FPC}
NOTE THE FOLLOWING DELPHI CODE READS .Z FILES, BUT .GZ FILES HAVE A FEW BYTES WRAPPER...
 EASY TO FIX SOMEDAY
 function GzHdrBytes (Fname: string): integer;
// GzHdrBytes('/Users/rorden/Documents/osx/chris_t1.nii.gz');
//http://www.onicos.com/staff/iz/formats/gzip.html
label
 666;
var
  FS1: TFileStream;
  B1, B2, B3, Flags: byte;
  i: integer;
  isPart, isExtra, isFname, isComment, isEncrypt : boolean;
begin
   result := 0;
   if not FileExists(Fname) then exit;
   FS1:= TFileStream.Create(Fname, fmOpenRead);
   FS1.Seek(0, soBeginning);
   FS1.Read(B1, SizeOf(B1)); //0: magic 1
   FS1.Read(B2, SizeOf(B2)); //1: magic 2
   FS1.Read(B3, SizeOf(B3)); //2: compression method
   FS1.Read(Flags, SizeOf(Flags)); //2: compression method
   isPart := (Flags and 2) <> 0;
   isExtra := (Flags and 4) <> 0;
   isFname := (Flags and 8) <> 0;
   isComment := (Flags and 16) <> 0;
   isEncrypt := (Flags and 32) <> 0;
   if (isEncrypt) or (isPart) or (isExtra) or (B1 <> 31) or (B2 <> 139) or (B3 <> 08) then goto 666; //magic is not 0x1F8B or compress not deflate
   for i := 1 to 6 do
     FS1.Read(B1, SizeOf(B1)); //Read 6 bytes: 4xTime,Extra, OSType
   result := 10;
   //2 bytes if isPart, only get here if not isPart
   //2+ bytes if isExtra, only get here if not isExtra
   if isFname then begin //if isFname read null terminated string
    B1 := 1;
    while B1 <> 0 do begin
      FS1.Read(B1, SizeOf(B1));
      inc(result);
    end;
   end; //if isFname
   if isComment then begin //if isComment read null terminated string
    B1 := 1;
    while B1 <> 0 do begin
      FS1.Read(B1, SizeOf(B1));
      inc(result);
    end;
   end; //if isComment
   //12 bytes if isEncrypt - only get here if not isEncrypt
 666:
   FS1.Free;
end;
{$ELSE}
function LoadGZ(FileName : AnsiString; var  rawData: tVolB; var lHdr: TNIFTIHdr): boolean;// Load 3D data                                 }
//FSL compressed nii.gz file
var
  Stream: TGZFileStream;
begin
 result := false;
 Stream := TGZFileStream.Create (FileName, gzopenread);
 Try
  Stream.ReadBuffer (lHdr, SizeOf (TNIFTIHdr));
  if lHdr.HdrSz <> SizeOf (TNIFTIHdr) then begin
   Showdebug('Unable to read image '+Filename+' - this software can only read uncompressed NIfTI files with the same endianess as the host CPU.');
   exit;
  end;
  if (lHdr.bitpix <> 8) and (lHdr.bitpix <> 16) and (lHdr.bitpix <> 24) and (lHdr.bitpix <> 32) then begin
   Showdebug('Unable to load '+Filename+' - this software can only read 8,16,24,32-bit NIfTI files.');
   exit;
  end;
  //read the image data
  Stream.Seek(round(lHdr.vox_offset),soFromBeginning);
  SetLength (rawData, lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3] * (lHdr.bitpix div 8));
  Stream.ReadBuffer (rawData[0], lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3]* (lHdr.bitpix div 8));
 Finally
  Stream.Free;
 End; { Try }
 result := true;
end;
{$ENDIF}
{$ENDIF}

function LoadRaw(FileName : AnsiString; var  rawData: tVolB; var lHdr: TNIFTIHdr): boolean;// Load 3D data                                 }
//Uncompressed .nii or .hdr/.img pair
var
 Stream : TFileStream;
begin
 result := false;
 Stream := TFileStream.Create (FileName, fmOpenRead or fmShareDenyWrite);
 Try
  Stream.ReadBuffer (lHdr, SizeOf (TNIFTIHdr));
  if lHdr.HdrSz <> SizeOf (TNIFTIHdr) then begin
   Showdebug('Unable to read image '+Filename+' - this software can only read uncompressed NIfTI files with the same endianess as the host CPU.');
   exit;
  end;
  if (lHdr.bitpix <> 8) and (lHdr.bitpix <> 16) and (lHdr.bitpix <> 24) and (lHdr.bitpix <> 32) then begin
   Showdebug('Unable to load '+Filename+' - this software can only read 8,16,24,32-bit NIfTI files.');
   exit;
  end;
  //read the image data
  if extractfileext(Filename) = '.hdr' then begin
   Stream.Free;
   Stream := TFileStream.Create (changefileext(FileName,'.img'), fmOpenRead or fmShareDenyWrite);
  end;
  Stream.Seek(round(lHdr.vox_offset),soFromBeginning);
  SetLength (rawData, lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3]* (lHdr.bitpix div 8));
  Stream.ReadBuffer (rawData[0], lHdr.Dim[1]*lHdr.Dim[2]*lHdr.Dim[3]* (lHdr.bitpix div 8));
 Finally
  Stream.Free;
 End;
 result := true;
end;

procedure Word2Byte(var  rawData: tVolB; var lHdr: TNIFTIHdr);// Load 3D data
//convert 16-bit data to 8-bit
var
 i,vx: integer;
 scale: single;
 mn,mx: integer;
 Src,Temp: tVolW;
begin
  Temp := nil;
  vx := (lHdr.dim[1]*lHdr.dim[2]*lHdr.dim[3]);
  if (lHdr.bitpix <> 16) or (vx < 1) then
   exit;
  setlength(Src,vx);
  Temp := tVolW(rawData);
  for i := 0 to (vx-1) do
    Src[i] := Temp[i];
  setlength(rawData,vx);
  mn := Src[0];
  mx := mn;
  for i := 0 to (vx-1) do begin
    if Src[i] > mx then mx := Src[i];
    if Src[i] < mn then mn := Src[i];
  end;
  if mn>=mx then //avoid divide by zero
   scale := 1
  else
   scale := 255/(mx-mn);
  for i := 0 to (vx-1) do
   rawdata[i] := round((Src[i]-mn)*Scale);
  Src := nil;//free memory
end;

FUNCTION specialsingle (var s:single): boolean;
//returns true if s is Infinity, NAN or Indeterminate
CONST kSpecialExponent = 255 shl 23;
VAR Overlay: LongInt ABSOLUTE s;
BEGIN
 IF ((Overlay AND kSpecialExponent) = kSpecialExponent) THEN
   RESULT := true
 ELSE
   RESULT := false;
END; //specialsingle()

procedure Single2Byte(var  rawData: tVolB; var lHdr: TNIFTIHdr);// Load 3D data
//convert 32-bit float data to 8-bit
var
 i,vx: integer;
 scale,mn,mx: single;
 Src,Temp: tVolS;
begin
  Temp := nil;
  vx := (lHdr.dim[1]*lHdr.dim[2]*lHdr.dim[3]);
  if (lHdr.bitpix <> 32) or (vx < 1) then exit;
  setlength(Src,vx);
  Temp := tVolS(rawData );
  for i := 0 to (vx-1) do
    Src[i] := Temp[i];
  setlength(rawData,vx);
  if specialSingle(Src[0]) then Src[0] := 0;
  mn := Src[0];
  mx := mn;
  for i := 0 to (vx-1) do begin
    if specialSingle(Src[i]) then Src[i] := 0; //zero not-a-number and infinity values
    if Src[i] > mx then mx := Src[i];
    if Src[i] < mn then mn := Src[i];
  end;
  if mn>=mx then //avoid divide by zero
   scale := 1
  else
   scale := 255/(mx-mn);
  for i := 0 to (vx-1) do
   rawdata[i] := round((Src[i]-mn)*Scale);
  Src := nil;//free memory
end;

procedure RGB2RGBA(var  rawData: tVolB; var lHdr: TNIFTIHdr);// Load 3D data
//function RGB2RGBA(var  rawData: tVolB; var lHdr: TNIFTIHdr): boolean;// Load 3D data                                 }
//convert 24-bit RGB data to 8-bit
// warning: Analyze is planar RRRR GGGG BBBB RRRR .... NIfTI is packed RGBRGBRGB
// whereas we need to make quads RGBA RGBA RGBA
var
 //alpha,i,rplane,gplane,bplane,z,xy,xysz,
 i,z,vx: integer;
 SrcPlanar: tVolB;
 OutRGBA: tVolRGBA;
begin
  OutRGBA := nil;
  vx := (lHdr.dim[1]*lHdr.dim[2]*lHdr.dim[3]);
  if (lHdr.bitpix <> 24) or (vx < 1) then
   exit;
  setlength(SrcPlanar,vx*3);
  for i := 0 to ((vx*3)-1) do
    SrcPlanar[i] := rawData[i];
  setlength(rawData,vx*4);
  OutRGBA := tVolRGBA(rawData );
  z := 0;
  for i := 0 to (vx-1) do begin
      OutRGBA[i].r := SrcPlanar[z]; z := z + 1;
      OutRGBA[i].g := SrcPlanar[z]; z := z + 1;
      OutRGBA[i].b := SrcPlanar[z]; z := z + 1;
      OutRGBA[i].a := ((OutRGBA[i].r+OutRGBA[i].g+OutRGBA[i].b) div 3);
  end;
  (*xysz := lHdr.dim[1]*lHdr.dim[2];
  i := 0;
  for z := 0 to (lHdr.dim[3]-1) do begin
   rplane := z * 3 * xysz;
   gplane := rplane+ xysz;
   bplane := gplane+ xysz;
   for xy := 0 to (xysz-1) do begin
    Alpha := (SrcPlanar[rplane+xy]+SrcPlanar[gplane+xy]+SrcPlanar[bplane+xy]) div 3;
    OutRGBA[i].r := SrcPlanar[rplane+xy];
    OutRGBA[i].g := SrcPlanar[gplane+xy];
    OutRGBA[i].b := SrcPlanar[bplane+xy];
    OutRGBA[i].a := Alpha;
    inc(i);
   end;//for each xy
  end;//for each Z *)
  SrcPlanar := nil;//free memory
end;

function Load3DNIfTI(FileName : AnsiString; var  rawData: tVolB; var X,Y,Z, isRGBA: integer; var ScaleDim: TScale): boolean;// Load 3D data                                 }
Var
 lHdr: TNIFTIHdr;
 Scale: single;
 Mx,Mn,I: integer;
 F_Filename: AnsiString;
begin
 result := false;
 if Filename = '' then
  exit;
 if uppercase(extractfileext(Filename)) = '.IMG' then begin
   //NIfTI images can be a single .NII file [contains both header and image]
   //or a pair of files named .HDR and .IMG. If the latter, we want to read the header first
   F_Filename := changefileext(FileName,'.hdr');
   {$IFDEF LINUX} //LINUX is case sensitive, OSX is not
   Showdebug('Unable to find header (case sensitive!) '+F_Filename);
   {$ELSE}
   Showdebug('Unable to find header '+F_Filename);
   {$ENDIF}
 end else
   F_Filename := Filename;
 if not Fileexists(F_FileName) then begin
  Showdebug('Unable to find '+F_Filename);
  exit;
 end;
 if uppercase(extractfileext(F_Filename)) = '.GZ' then begin
   {$IFDEF GZIP}
   if not LoadGZ(F_FileName,rawData,lHdr) then
      exit;
   {$ELSE}
   Showdebug('Please manually decompress images '+F_Filename);
   exit;
   {$ENDIF}
 end else begin
   if not LoadRaw(F_FileName,rawData,lHdr) then
    exit;
 end;
 if (lHdr.bitpix = 16) then
  Word2Byte(rawData, lHdr);
 if (lHdr.bitpix = 32) and (lHdr.datatype = 16) then
  Single2Byte(rawData, lHdr)
 else if (lHdr.bitpix = 32) then begin
    Showdebug('Unsupported 32-bit data type');
    exit;
 end;
 if (lHdr.bitpix = 24) then begin
  RGB2RGBA(rawData, lHdr);
  IsRGBA := 1;
 end else
  IsRGBA := 0;
 //Set output values
 X := lHdr.Dim[1];
 Y := lHdr.Dim[2];
 Z := lHdr.Dim[3];
 //normalize size so there is a proportional bounding box with largest side having length of 1
 Scale := FloatMaxVal(abs(lHdr.Dim[1]*lHdr.PixDim[1]),abs(lHdr.Dim[2]*lHdr.pixDim[2]),abs(lHdr.Dim[3]*lHdr.pixDim[3]));
 if (Scale <> 0) then begin
   ScaleDim[1] := abs((lHdr.Dim[1]*lHdr.PixDim[1]) / Scale);
   ScaleDim[2] := abs((lHdr.Dim[2]*lHdr.PixDim[2]) / Scale);
   ScaleDim[3] := abs((lHdr.Dim[3]*lHdr.PixDim[3]) / Scale);
 end;
 //normalize intensity 0..255
 mx := rawData[0];
 mn := mx;
 for I := 0 to ((X*Y*Z)-1) do begin
   if rawData[I] > mx then
    mx := rawData[I];
   if rawData[I] < mn then
    mn := rawData[I];
 end;
 if (mx > mn) and ((mx-mn) < 255) then begin
  Scale := 255/(mx-mn);
  for I := 0 to ((X*Y*Z)-1) do
   rawData[I] := round(Scale*(rawData[I]-Mn));
 end;
 result := true;
end;

function Load3DTextures(FileName : AnsiString; var gradientVolume, intensityVolume : GLuint; var isRGBA: integer; var ScaleDim: TScale; loadGradients: boolean): boolean;// Load 3D data                                 }
var
 X,Y,Z: integer;
 i: GLint;
 rawData: tVolB;
begin
 result := true;
 //Load the image from disk, or generate the borg image
 if Filename = '' then
  LoadBorg(64,rawdata, X,Y,Z, isRGBA, ScaleDim)
 else begin
  if not Load3DNIfTI(FileName, rawData, X,Y,Z, isRGBA, ScaleDim) then begin
         LoadBorg(64,rawdata, X,Y,Z, isRGBA, ScaleDim);
         result := false;
     end;
 end;
 if (intensityVolume <> 0) then glDeleteTextures(1,@intensityVolume);
 //next: see if our video card can show this texture
 if isRGBA = 1 then
  glTexImage3D(GL_PROXY_TEXTURE_3D, 0, GL_RGBA, X, Y, Z, 0, GL_RGBA, GL_UNSIGNED_BYTE, NIL)
 else
     glTexImage3D(GL_PROXY_TEXTURE_3D, 0, GL_ALPHA8, X, Y, Z, 0, GL_ALPHA, GL_UNSIGNED_BYTE, NIL);
  //   glTexImage3D(GL_PROXY_TEXTURE_3D, 0, GL_INTENSITY, X, Y, Z, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NIL);
  glGetTexLevelParameteriv(GL_PROXY_TEXTURE_3D, 0, GL_TEXTURE_WIDTH, @i);
 if i = 0 then begin //video card can not support this texture - report an error but not in OpenGL context
    LoadBorg(64,rawdata, X,Y,Z, isRGBA, ScaleDim);
    result := false; //we failed to load the requested image
 end;
 //next copy the image to the GPU
 glPixelStorei(GL_UNPACK_ALIGNMENT,1);
 glGenTextures(1, @intensityVolume);
 glBindTexture(GL_TEXTURE_3D, intensityVolume);
 //glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
 //glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
 glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
 glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
 glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);//?
 glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);//?
 glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);//?
 if isRGBA = 1 then
  glTexImage3D(GL_TEXTURE_3D, 0,GL_RGBA, X, Y,Z,0, GL_RGBA, GL_UNSIGNED_BYTE,@rawData[0])
 else
   glTexImage3D(GL_TEXTURE_3D, 0, GL_INTENSITY,X, Y,Z,0, GL_LUMINANCE, GL_UNSIGNED_BYTE, @rawData[0]);
  //next: generate a RGBA volume where components are normalized X,Y,Z gradient direction and magnitude
 if (gradientVolume <> 0) then glDeleteTextures(1,@gradientVolume);
 if loadGradients then
  CreateGradientVolume (rawData, X,Y,Z, isRGBA, gradientVolume)
 else
  gradientVolume := 0;//critical value 1... not sure how to adjust threshold
 rawData :=nil;
end;

end.
