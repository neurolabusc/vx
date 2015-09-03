object Form1: TForm1
  Left = 266
  Top = 107
  Width = 464
  Height = 529
  Caption = 'GLSL raycasting'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnCreate = FormCreate
  OnMouseWheel = GLboxMouseWheel
  PixelsPerInch = 120
  TextHeight = 16
  object MainMenu1: TMainMenu
    Left = 16
    Top = 40
    object File1: TMenuItem
      Caption = 'File'
      object Open1: TMenuItem
        Caption = 'Open'
        ShortCut = 16463
        OnClick = Open1Click
      end
      object OpenNoGradients1: TMenuItem
        Caption = 'Open without loading gradients'
        ShortCut = 16450
        OnClick = OpenNoGradients1Cick
      end
      object Exit1: TMenuItem
        Caption = 'Exit'
        ShortCut = 16472
        OnClick = Exit1Click
      end
    end
    object Edit1: TMenuItem
      Caption = 'Edit'
      object Copy1: TMenuItem
        Caption = 'Copy'
        OnClick = Copy1Click
      end
    end
    object MenuView: TMenuItem
      Caption = 'View'
      object MenuBackColor: TMenuItem
        Caption = 'Back color'
        OnClick = Backcolor1Click
      end
      object MenuQuality: TMenuItem
        Caption = 'High quality'
        Checked = True
        OnClick = MenuQualityClick
      end
      object MenuSwitchMode: TMenuItem
        Caption = 'Raycast'
        Checked = True
        OnClick = SwitchModeClick
      end
    end
    object MenuRaycast: TMenuItem
      Caption = 'Raycast'
      object Color1: TMenuItem
        Caption = 'Change color table'
        ShortCut = 16468
        OnClick = Color1Click
      end
      object Shade1: TMenuItem
        AutoCheck = True
        Caption = 'Shade toggle'
        ShortCut = 16467
        OnClick = Shade1Click
      end
      object Boundary1: TMenuItem
        AutoCheck = True
        Caption = 'Enhance boundaries'
        ShortCut = 16453
        OnClick = Boundary1Click
      end
      object Gradient1: TMenuItem
        AutoCheck = True
        Caption = 'Show gradient'
        ShortCut = 16455
        OnClick = Gradient1Click
      end
      object Perspective1: TMenuItem
        AutoCheck = True
        Caption = 'Perspective'
        ShortCut = 16464
        OnClick = Perspective1Click
      end
    end
    object Help1: TMenuItem
      Caption = 'Help'
      object About1: TMenuItem
        Caption = 'About'
        OnClick = About1Click
      end
    end
  end
  object OpenDialog1: TOpenDialog
    Filter = 'NIFTI (hdr, nii)|*.nii;*.hdr'
    Left = 16
    Top = 8
  end
  object ColorDialog1: TColorDialog
    Left = 16
    Top = 72
  end
  object ErrorTimer1: TTimer
    Enabled = False
    Interval = 40
    OnTimer = ErrorTimerOnTimer
    Left = 16
    Top = 104
  end
end
