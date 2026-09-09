unit Unit4;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

{ Zeigt den ScummVM-Einstellungsdialog. Anders als bei DOSBox braucht
  ScummVM keinen Pfad zu einer Programmdatei, sondern den ORDNER mit den
  Spieldateien - ScummVM erkennt das Spiel darin selbst (--auto-detect). }
function ShowScummVMSettings(var AUseScummVM, AScummVMPath: String): Boolean;

type
  { TScummVMSettingsForm }
  TScummVMSettingsForm = class(TForm)
    chkUse: TCheckBox;
    edtPath: TEdit;
    btnBrowse: TButton;
    procedure btnBrowseClick(Sender: TObject);
  end;

implementation

procedure TScummVMSettingsForm.btnBrowseClick(Sender: TObject);
var
  Dlg: TSelectDirectoryDialog;
begin
  Dlg := TSelectDirectoryDialog.Create(nil);
  try
    Dlg.Title := 'Spiele-Ordner auswählen';
    if edtPath.Text <> '' then
      Dlg.InitialDir := edtPath.Text;
    if Dlg.Execute then
      edtPath.Text := Dlg.FileName; // bei TSelectDirectoryDialog der gewaehlte Ordnerpfad
  finally
    Dlg.Free;
  end;
end;

function ShowScummVMSettings(var AUseScummVM, AScummVMPath: String): Boolean;
var
  F: TScummVMSettingsForm;
  TopY: Integer;
  lblHint: TLabel;
  btnOK, btnCancel: TButton;

  procedure AddLbl(const ACaption: String; AWidth: Integer = 420);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.SetBounds(20, TopY, AWidth, 20);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];
    TopY += 24;
  end;

begin
  Result := False;

  F := TScummVMSettingsForm.CreateNew(Application);
  try
    F.Caption := 'ScummVM-Einstellungen';
    F.Width := 460;
    F.Position := poScreenCenter;
    F.BorderStyle := bsToolWindow;

    TopY := 16;

    F.chkUse := TCheckBox.Create(F);
    F.chkUse.Parent := F;
    F.chkUse.SetBounds(20, TopY, 420, 22);
    F.chkUse.Caption := 'Über ScummVM starten (für LucasArts- & andere Point-and-Click-Adventures)';
    F.chkUse.Checked := SameText(Trim(AUseScummVM), 'Ja');
    TopY += 36;

    AddLbl('Spiele-Ordner (nicht die EXE - ScummVM erkennt das Spiel selbst):');

    F.edtPath := TEdit.Create(F);
    F.edtPath.Parent := F;
    F.edtPath.SetBounds(20, TopY, 300, 25);
    F.edtPath.Text := AScummVMPath;
    F.edtPath.ReadOnly := True;

    F.btnBrowse := TButton.Create(F);
    F.btnBrowse.Parent := F;
    F.btnBrowse.SetBounds(326, TopY - 1, 110, 27);
    F.btnBrowse.Caption := 'Ordner wählen...';
    F.btnBrowse.OnClick := @F.btnBrowseClick;
    TopY += 36;

    lblHint := TLabel.Create(F);
    lblHint.Parent := F;
    lblHint.SetBounds(20, TopY, 420, 34);
    lblHint.Caption := 'Der Ordner, der die Spieldateien direkt enthält (z.B. mit MONKEY.000, ' +
      'TENTACLE.000 o.ä.) - nicht der übergeordnete Sammlungsordner.';
    lblHint.Font.Color := clGray;
    lblHint.Font.Height := -11;
    lblHint.WordWrap := True;
    TopY += 46;

    btnOK := TButton.Create(F);
    btnOK.Parent := F;
    btnOK.SetBounds(180, TopY, 120, 36);
    btnOK.Caption := 'Übernehmen';
    btnOK.ModalResult := mrOK;
    btnOK.Default := True;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(310, TopY, 120, 36);
    btnCancel.Caption := 'Abbrechen';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Cancel := True;

    F.Height := TopY + 90;

    if F.ShowModal = mrOK then
    begin
      if F.chkUse.Checked then
        AUseScummVM := 'Ja'
      else
        AUseScummVM := 'Nein';
      AScummVMPath := F.edtPath.Text;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
