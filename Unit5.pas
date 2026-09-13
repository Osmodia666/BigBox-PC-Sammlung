unit Unit5;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

{ Zeigt den Einstellungsdialog fuer die RAWG-/IGDB-Zugangsdaten (Aufruf
  ueber den "Einstellungen..."-Button im Hauptfenster). Die var-Parameter
  werden nur bei Klick auf "Speichern" veraendert - Abbrechen laesst die
  uebergebenen Werte unangetastet. Das eigentliche Schreiben in die
  settings.ini uebernimmt Unit1 per AppSettings.SaveAppSettings, nachdem
  diese Funktion True geliefert hat. }
function ShowSettings(var ARawgApiKey, AIgdbClientId,
  AIgdbClientSecret: String): Boolean;

implementation

type
  { TSettingsForm }
  TSettingsForm = class(TForm)
  end;

function ShowSettings(var ARawgApiKey, AIgdbClientId,
  AIgdbClientSecret: String): Boolean;
var
  F: TSettingsForm;
  TopY: Integer;
  edtRawg, edtClientId, edtClientSecret: TEdit;
  btnOK, btnCancel: TButton;

  procedure AddLbl(const ACaption: String);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.SetBounds(20, TopY, 400, 18);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];
    TopY += 22;
  end;

  procedure AddHint(const AText: String; AHeight: Integer = 32);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.SetBounds(20, TopY, 400, AHeight);
    L.Caption := AText;
    L.Font.Color := clGray;
    L.WordWrap := True;
    L.AutoSize := False;
    L.Height := AHeight;
    TopY += AHeight + 8;
  end;

begin
  Result := False;
  F := TSettingsForm.CreateNew(Application);
  try
    F.Caption := 'API-Einstellungen';
    F.Width := 460;
    F.Position := poScreenCenter;
    F.BorderStyle := bsToolWindow;

    TopY := 16;

    AddLbl('RAWG-API-Key:');
    edtRawg := TEdit.Create(F);
    edtRawg.Parent := F;
    edtRawg.SetBounds(20, TopY, 400, 25);
    edtRawg.Text := ARawgApiKey;
    TopY += 32;
    AddHint('Kostenlos unter rawg.io/apidocs registrieren, keine Zahlungsdaten noetig.');

    AddLbl('IGDB / Twitch Client-ID:');
    edtClientId := TEdit.Create(F);
    edtClientId.Parent := F;
    edtClientId.SetBounds(20, TopY, 400, 25);
    edtClientId.Text := AIgdbClientId;
    TopY += 32;

    AddLbl('IGDB / Twitch Client-Secret:');
    edtClientSecret := TEdit.Create(F);
    edtClientSecret.Parent := F;
    edtClientSecret.SetBounds(20, TopY, 400, 25);
    edtClientSecret.Text := AIgdbClientSecret;
    edtClientSecret.PasswordChar := '*';
    TopY += 32;
    AddHint('Beide unter dev.twitch.tv/console/apps anlegen (kostenloses Twitch-'
      + 'Konto, "Registrieren"): Name frei waehlbar, OAuth Redirect URL z. B. '
      + 'http://localhost. Client-ID wird direkt angezeigt, "Neues Secret '
      + 'erstellen" fuers Client-Secret.', 60);

    btnOK := TButton.Create(F);
    btnOK.Parent := F;
    btnOK.SetBounds(120, TopY, 130, 36);
    btnOK.Caption := 'Speichern';
    btnOK.ModalResult := mrOK;
    btnOK.Default := True;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(260, TopY, 130, 36);
    btnCancel.Caption := 'Abbrechen';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Cancel := True;

    F.Height := TopY + 90;

    if F.ShowModal = mrOK then
    begin
      ARawgApiKey := Trim(edtRawg.Text);
      AIgdbClientId := Trim(edtClientId.Text);
      AIgdbClientSecret := Trim(edtClientSecret.Text);
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
