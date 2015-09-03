unit glpanel;

interface
uses
  dglopengl,Classes,Controls,ExtCtrls, Windows;//, Messages  ,Windows
type
  TGLPanel= class(TPanel)
  private
      DC: HDC;
      RC: HGLRC;
      FOnPaint: TNotifyEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SwapBuffers; virtual;
    property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;
    //procedure MakeCurrent;
    //procedure ReleaseContext;
  published

  end;
procedure Register;

implementation

(*procedure TGLPanel.MakeCurrent;
begin
  wglMakeCurrent(self.DC, self.RC);
end;

procedure  TGLPanel.ReleaseContext;
begin
  wglMakeCurrent(0,0);
end;*)


procedure TGLPanel.SwapBuffers;
begin
    Windows.SwapBuffers(Self.DC);
end;

procedure Register;
begin
  RegisterComponents('GLPanel', [TGLPanel]);
end;

procedure TGLPanel.Paint;
begin
    If Assigned(OnPaint) then OnPaint(self);
end;

constructor TGLPanel.Create(AOwner: TComponent);
var
//http://stackoverflow.com/questions/3444217/opengl-how-to-limit-to-an-image-component
  PixelFormat: integer;

const
  PFD: TPixelFormatDescriptor = (
         nSize: sizeOf(TPixelFormatDescriptor);
         nVersion: 1;
         dwFlags: PFD_SUPPORT_OPENGL or PFD_DRAW_TO_WINDOW or PFD_DOUBLEBUFFER;
         iPixelType: PFD_TYPE_RGBA;
         cColorBits: 24;
         cRedBits: 0;
         cRedShift: 0;
         cGreenBits: 0;
         cGreenShift: 0;
         cBlueBits: 0;
         cBlueShift: 0;
         cAlphaBits: 24;
         cAlphaShift: 0;
         cAccumBits: 0;
         cAccumRedBits: 0;
         cAccumGreenBits: 0;
         cAccumBlueBits: 0;
         cAccumAlphaBits: 0;
         cDepthBits: 16;
         cStencilBits: 0;
         cAuxBuffers: 0;
         iLayerType: PFD_MAIN_PLANE;
         bReserved: 0;
         dwLayerMask: 0;
         dwVisibleMask: 0;
         dwDamageMask: 0);
begin
    inherited Create(AOwner);
    parent := TWinControl(AOwner);
  Self.DC := GetDC(Self.Handle);
  PixelFormat := ChoosePixelFormat(Self.DC, @PFD);
  SetPixelFormat(Self.DC, PixelFormat, @PFD);
  Self.RC := wglCreateContext(Self.DC);
  wglMakeCurrent(Self.DC, RC);
end;


end.
  
