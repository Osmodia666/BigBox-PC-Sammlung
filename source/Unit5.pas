unit Unit5;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, LCLIntf;

type
  { Rueckruf fuer die Sync-Aktionen im Einstellungsdialog: bekommt die
    aktuell im Dialog eingetragenen Nextcloud-Zugangsdaten (auch wenn noch
    nicht per "Speichern" bestaetigt) und liefert True bei Erfolg plus eine
    fuer den Nutzer verstaendliche Statusmeldung. Die eigentliche Netzwerk-/
    Dateilogik lebt in Unit1 (TForm1.NcPullAction/NcPushAction) - diese Unit
    bleibt reine Oberflaeche ohne Rueckverweis auf Unit1. }
  TNcSyncFunc = function(const URL, User, Pass: String;
    out StatusMsg: String): Boolean of object;

  { Oeffnet die Tauschboerse (Freundesliste). Bekommt die aktuell im Dialog
    eingetragenen Nextcloud-Zugangsdaten mit, damit "Zu Nextcloud hochladen"
    dort funktioniert, auch wenn der Nutzer sie gerade erst eingetragen und
    noch nicht per "Speichern" bestaetigt hat. Die eigentliche Logik
    (Tauschboerse-Fenster, Zugriff auf die Spieleliste) lebt in Unit1/Unit6 -
    diese Unit bleibt reine Oberflaeche ohne Rueckverweis auf beide. }
  TOpenTauschboerseFunc = procedure(const NcUrl, NcUser, NcPass: String) of object;

  { TSettingsForm }
  TSettingsForm = class(TForm)
    edtRawg: TEdit;
    edtClientId: TEdit;
    edtClientSecret: TEdit;
    btnToggleSecret: TButton;
    lblCSVPath: TLabel;
    btnOpenCSV: TButton;
    btnNewCSV: TButton;
    edtNcUrl: TEdit;
    edtNcUser: TEdit;
    edtNcPass: TEdit;
    btnToggleNcPass: TButton;
    btnPull: TButton;
    btnPush: TButton;
    lblSyncStatus: TLabel;
    btnTauschboerse: TButton;
    lblDonate: TLabel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnToggleSecretClick(Sender: TObject);
    procedure btnToggleNcPassClick(Sender: TObject);
    procedure btnOpenCSVClick(Sender: TObject);
    procedure btnNewCSVClick(Sender: TObject);
    procedure btnPullClick(Sender: TObject);
    procedure btnPushClick(Sender: TObject);
    procedure btnTauschboerseClick(Sender: TObject);
    procedure lblDonateClick(Sender: TObject);
  public
    CurrentCSVPath: String;
    PullFunc: TNcSyncFunc;
    PushFunc: TNcSyncFunc;
    OpenTauschboerseFunc: TOpenTauschboerseFunc;
  end;

{ Zeigt den Einstellungsdialog fuer RAWG-/IGDB-Zugangsdaten, die aktive
  CSV-Datei und den Nextcloud/WebDAV-Sync (Aufruf ueber den
  "Einstellungen..."-Button im Hauptfenster). Die var-Parameter werden nur
  bei Klick auf "Speichern" veraendert - Abbrechen laesst die uebergebenen
  Werte unangetastet. Das eigentliche Schreiben in die settings.ini bzw.
  das Wechseln der Datei uebernimmt Unit1, nachdem diese Funktion True
  geliefert hat. APullFunc/APushFunc werden 1:1 an die "Vom Server
  abrufen"/"Eigenen Stand hochladen"-Buttons durchgereicht. }
function ShowSettings(var ARawgApiKey, AIgdbClientId, AIgdbClientSecret,
  ANcUrl, ANcUser, ANcPass, ACSVPath: String;
  APullFunc, APushFunc: TNcSyncFunc;
  AOpenTauschboerse: TOpenTauschboerseFunc): Boolean;

implementation

procedure TSettingsForm.btnToggleSecretClick(Sender: TObject);
begin
  if edtClientSecret.PasswordChar = #0 then
    edtClientSecret.PasswordChar := '*'
  else
    edtClientSecret.PasswordChar := #0;
end;

procedure TSettingsForm.btnToggleNcPassClick(Sender: TObject);
begin
  if edtNcPass.PasswordChar = #0 then
    edtNcPass.PasswordChar := '*'
  else
    edtNcPass.PasswordChar := #0;
end;

procedure TSettingsForm.btnOpenCSVClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Vorhandene CSV-Datei öffnen';
    Dlg.Filter := 'CSV-Dateien (*.csv)|*.csv|Alle Dateien (*.*)|*.*';
    if (CurrentCSVPath <> '') and DirectoryExists(ExtractFilePath(CurrentCSVPath)) then
      Dlg.InitialDir := ExtractFilePath(CurrentCSVPath);
    if Dlg.Execute then
    begin
      CurrentCSVPath := Dlg.FileName;
      lblCSVPath.Caption := CurrentCSVPath;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TSettingsForm.btnNewCSVClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title := 'Neue CSV-Datei anlegen';
    Dlg.Filter := 'CSV-Dateien (*.csv)|*.csv';
    Dlg.DefaultExt := 'csv';
    Dlg.FileName := 'spiele.csv';
    if (CurrentCSVPath <> '') and DirectoryExists(ExtractFilePath(CurrentCSVPath)) then
      Dlg.InitialDir := ExtractFilePath(CurrentCSVPath);
    if Dlg.Execute then
    begin
      CurrentCSVPath := Dlg.FileName;
      lblCSVPath.Caption := CurrentCSVPath + '  (neu)';
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TSettingsForm.btnPullClick(Sender: TObject);
var
  StatusMsg: String;
begin
  if not Assigned(PullFunc) then Exit;
  PullFunc(edtNcUrl.Text, edtNcUser.Text, edtNcPass.Text, StatusMsg);
  lblSyncStatus.Caption := StatusMsg;
end;

procedure TSettingsForm.btnPushClick(Sender: TObject);
var
  StatusMsg: String;
begin
  if not Assigned(PushFunc) then Exit;
  PushFunc(edtNcUrl.Text, edtNcUser.Text, edtNcPass.Text, StatusMsg);
  lblSyncStatus.Caption := StatusMsg;
end;

procedure TSettingsForm.btnTauschboerseClick(Sender: TObject);
begin
  if Assigned(OpenTauschboerseFunc) then
    OpenTauschboerseFunc(edtNcUrl.Text, edtNcUser.Text, edtNcPass.Text);
end;

procedure TSettingsForm.lblDonateClick(Sender: TObject);
begin
  OpenURL('https://paypal.me/ChristopherStein');
end;

function ShowSettings(var ARawgApiKey, AIgdbClientId, AIgdbClientSecret,
  ANcUrl, ANcUser, ANcPass, ACSVPath: String;
  APullFunc, APushFunc: TNcSyncFunc;
  AOpenTauschboerse: TOpenTauschboerseFunc): Boolean;
var
  F: TSettingsForm;
  TopY: Integer;

  procedure AddLbl(const ACaption: String);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.SetBounds(20, TopY, 420, 18);
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
    L.SetBounds(20, TopY, 420, AHeight);
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
    F.Caption := 'Einstellungen';
    F.Width := 480;
    F.Position := poScreenCenter;
    F.BorderStyle := bsSizeable;
    F.CurrentCSVPath := ACSVPath;
    F.PullFunc := APullFunc;
    F.PushFunc := APushFunc;
    F.OpenTauschboerseFunc := AOpenTauschboerse;

    TopY := 16;

    AddLbl('RAWG-API-Key:');
    F.edtRawg := TEdit.Create(F);
    F.edtRawg.Parent := F;
    F.edtRawg.SetBounds(20, TopY, 440, 25);
    F.edtRawg.Text := ARawgApiKey;
    TopY += 32;
    AddHint('Kostenlos unter rawg.io/apidocs registrieren, keine Zahlungsdaten noetig.');

    AddLbl('IGDB / Twitch Client-ID:');
    F.edtClientId := TEdit.Create(F);
    F.edtClientId.Parent := F;
    F.edtClientId.SetBounds(20, TopY, 440, 25);
    F.edtClientId.Text := AIgdbClientId;
    TopY += 32;

    AddLbl('IGDB / Twitch Client-Secret:');
    F.edtClientSecret := TEdit.Create(F);
    F.edtClientSecret.Parent := F;
    F.edtClientSecret.SetBounds(20, TopY, 394, 25);
    F.edtClientSecret.Text := AIgdbClientSecret;
    F.edtClientSecret.PasswordChar := '*';
    F.btnToggleSecret := TButton.Create(F);
    F.btnToggleSecret.Parent := F;
    F.btnToggleSecret.SetBounds(424, TopY, 36, 25);
    F.btnToggleSecret.Caption := '👁';
    F.btnToggleSecret.OnClick := @F.btnToggleSecretClick;
    TopY += 32;
    AddHint('Beide unter dev.twitch.tv/console/apps anlegen (kostenloses Twitch-'
      + 'Konto, "Registrieren"): Name frei waehlbar, OAuth Redirect URL z. B. '
      + 'http://localhost. Client-ID wird direkt angezeigt, "Neues Secret '
      + 'erstellen" fuers Client-Secret.', 60);

    AddLbl('CSV-Datei dieser Sammlung:');
    F.lblCSVPath := TLabel.Create(F);
    F.lblCSVPath.Parent := F;
    F.lblCSVPath.SetBounds(20, TopY, 440, 32);
    F.lblCSVPath.Caption := ACSVPath;
    F.lblCSVPath.WordWrap := True;
    F.lblCSVPath.AutoSize := False;
    F.lblCSVPath.Height := 32;
    F.lblCSVPath.Font.Color := clNavy;
    TopY += 38;
    F.btnOpenCSV := TButton.Create(F);
    F.btnOpenCSV.Parent := F;
    F.btnOpenCSV.SetBounds(20, TopY, 210, 28);
    F.btnOpenCSV.Caption := 'Vorhandene öffnen...';
    F.btnOpenCSV.OnClick := @F.btnOpenCSVClick;
    F.btnNewCSV := TButton.Create(F);
    F.btnNewCSV.Parent := F;
    F.btnNewCSV.SetBounds(240, TopY, 210, 28);
    F.btnNewCSV.Caption := 'Neue anlegen...';
    F.btnNewCSV.OnClick := @F.btnNewCSVClick;
    TopY += 36;
    AddHint('Zum Wechseln zwischen mehreren Sammlungen, oder um eine lokal '
      + 'synchronisierte Datei zu verwenden (z. B. Nextcloud-Desktop-Client, '
      + 'OneDrive, Dropbox). Wird beim naechsten Start automatisch wieder '
      + 'geoeffnet.', 46);

    AddLbl('Nextcloud / WebDAV-Sync:');
    F.edtNcUrl := TEdit.Create(F);
    F.edtNcUrl.Parent := F;
    F.edtNcUrl.SetBounds(20, TopY, 440, 25);
    F.edtNcUrl.Text := ANcUrl;
    F.edtNcUrl.TextHint := 'https://cloud.example.com/remote.php/dav/files/DEINUSER/Sammlung/spiele.csv';
    TopY += 32;
    F.edtNcUser := TEdit.Create(F);
    F.edtNcUser.Parent := F;
    F.edtNcUser.SetBounds(20, TopY, 210, 25);
    F.edtNcUser.Text := ANcUser;
    F.edtNcUser.TextHint := 'Benutzername';
    F.edtNcPass := TEdit.Create(F);
    F.edtNcPass.Parent := F;
    F.edtNcPass.SetBounds(240, TopY, 160, 25);
    F.edtNcPass.Text := ANcPass;
    F.edtNcPass.PasswordChar := '*';
    F.edtNcPass.TextHint := 'App-Passwort';
    F.btnToggleNcPass := TButton.Create(F);
    F.btnToggleNcPass.Parent := F;
    F.btnToggleNcPass.SetBounds(410, TopY, 50, 25);
    F.btnToggleNcPass.Caption := '👁';
    F.btnToggleNcPass.OnClick := @F.btnToggleNcPassClick;
    TopY += 32;
    AddHint('Funktioniert mit jedem WebDAV-faehigen Speicher - neben Nextcloud '
      + 'z. B. auch ownCloud, Seafile, pCloud, Koofr, Yandex.Disk oder Box. '
      + 'Dieselbe Datei kann parallel von der Handy-Web-App unter "Mehr -> '
      + 'Sync" genutzt werden. Zugangsdaten bleiben nur lokal in der '
      + 'settings.ini neben der CSV-Datei.', 60);
    F.btnPull := TButton.Create(F);
    F.btnPull.Parent := F;
    F.btnPull.SetBounds(20, TopY, 210, 30);
    F.btnPull.Caption := 'Vom Server abrufen';
    F.btnPull.OnClick := @F.btnPullClick;
    F.btnPush := TButton.Create(F);
    F.btnPush.Parent := F;
    F.btnPush.SetBounds(240, TopY, 210, 30);
    F.btnPush.Caption := 'Eigenen Stand hochladen';
    F.btnPush.OnClick := @F.btnPushClick;
    TopY += 38;
    F.lblSyncStatus := TLabel.Create(F);
    F.lblSyncStatus.Parent := F;
    F.lblSyncStatus.SetBounds(20, TopY, 440, 34);
    F.lblSyncStatus.Caption := '';
    F.lblSyncStatus.WordWrap := True;
    F.lblSyncStatus.AutoSize := False;
    F.lblSyncStatus.Height := 34;
    F.lblSyncStatus.Font.Color := clNavy;
    TopY += 40;

    F.btnTauschboerse := TButton.Create(F);
    F.btnTauschboerse.Parent := F;
    F.btnTauschboerse.SetBounds(20, TopY, 440, 30);
    F.btnTauschboerse.Caption := 'Tauschbörse öffnen (Freunde & tauschbare Spiele)...';
    F.btnTauschboerse.OnClick := @F.btnTauschboerseClick;
    TopY += 38;
    AddHint('Zeigt deine als "Tauschbar" markierten Spiele, veröffentlicht sie '
      + 'als Datei/auf Nextcloud, und verwaltet Freunde, deren Tauschlisten du '
      + 'abonnierst.', 32);

    F.lblDonate := TLabel.Create(F);
    F.lblDonate.Parent := F;
    F.lblDonate.SetBounds(20, TopY, 440, 20);
    F.lblDonate.Caption := '💛 Gefällt dir die App? Spende via PayPal (paypal.me/ChristopherStein)';
    F.lblDonate.Font.Color := clBlue;
    F.lblDonate.Font.Style := [fsUnderline];
    F.lblDonate.Cursor := crHandPoint;
    F.lblDonate.OnClick := @F.lblDonateClick;
    TopY += 32;

    F.btnOK := TButton.Create(F);
    F.btnOK.Parent := F;
    F.btnOK.SetBounds(150, TopY, 130, 36);
    F.btnOK.Caption := 'Speichern';
    F.btnOK.ModalResult := mrOK;
    F.btnOK.Default := True;

    F.btnCancel := TButton.Create(F);
    F.btnCancel.Parent := F;
    F.btnCancel.SetBounds(290, TopY, 130, 36);
    F.btnCancel.Caption := 'Abbrechen';
    F.btnCancel.ModalResult := mrCancel;
    F.btnCancel.Cancel := True;

    F.Height := TopY + 90;

    if F.ShowModal = mrOK then
    begin
      ARawgApiKey := Trim(F.edtRawg.Text);
      AIgdbClientId := Trim(F.edtClientId.Text);
      AIgdbClientSecret := Trim(F.edtClientSecret.Text);
      ANcUrl := Trim(F.edtNcUrl.Text);
      ANcUser := Trim(F.edtNcUser.Text);
      ANcPass := F.edtNcPass.Text;
      ACSVPath := F.CurrentCSVPath;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
