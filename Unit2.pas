unit Unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  base64, RawgApi, IgdbApi, Unit3, Unit4;

function ShowEditGame(var AName, ASprache, AMedium, AZustand, AInhalt,
  AVollstaendig, APublisher, AJahr, AEntwickler, APlattform, ACoverBase64,
  ACoverExt, AWert, AGenre, AExePath, AUseDosBox, ADosBoxConfig, AUseScummVM,
  AScummVMPath: String; const ATitle: String): Boolean;

type
  { TEditGameForm }
  TEditGameForm = class(TForm)
    ScrollBox: TScrollBox;
    imgCover: TImage;
    lblCoverPath: TLabel;
    edtName: TEdit;
    cmbSprache: TComboBox;
    cmbMedium: TComboBox;
    cmbZustand: TComboBox;
    edtInhalt: TEdit;
    rbVollJa: TRadioButton;
    rbVollNein: TRadioButton;
    edtPublisher: TEdit;
    edtJahr: TEdit;
    edtEntwickler: TEdit;
    rbPlatPC: TRadioButton;
    rbPlatAmiga: TRadioButton;
    cmbGenre: TComboBox;
    edtExePath: TEdit;
    btnExeBrowse: TButton;
    btnDosBoxSettings: TButton;
    btnScummVMSettings: TButton;
    btnFetch: TButton;
    edtWert: TEdit;
    btnBild: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnBildClick(Sender: TObject);
    procedure btnExeBrowseClick(Sender: TObject);
    procedure btnDosBoxSettingsClick(Sender: TObject);
    procedure btnScummVMSettingsClick(Sender: TObject);
    procedure btnFetchClick(Sender: TObject);
    procedure edtWertKeyPress(Sender: TObject; var Key: char);
  private
    SelectedCoverBase64: String;
    SelectedCoverExt: String;
    SelectedUseDosBox: String;
    SelectedDosBoxConfig: String;
    SelectedUseScummVM: String;
    SelectedScummVMPath: String;
  end;

implementation

{ Liest eine Datei komplett ein und liefert sie Base64-kodiert zurueck. }
function FileToBase64(const Path: String): String;
var
  FS: TFileStream;
  SS: TStringStream;
begin
  Result := '';
  FS := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(FS, 0);
      Result := EncodeStringBase64(SS.DataString);
    finally
      SS.Free;
    end;
  finally
    FS.Free;
  end;
end;

{ Dekodiert Base64-Bilddaten und laedt sie ins uebergebene TPicture. Braucht
  die urspruengliche Dateiendung, da ohne echte Datei sonst nicht erkennbar
  waere, ob es sich um JPEG/PNG/BMP handelt. }
procedure LoadPictureFromBase64(Pic: TPicture; const B64, Ext: String);
var
  Raw: String;
  MS: TMemoryStream;
  UseExt: String;
begin
  if B64 = '' then
  begin
    Pic.Clear;
    Exit;
  end;
  Raw := DecodeStringBase64(B64);
  MS := TMemoryStream.Create;
  try
    if Length(Raw) > 0 then
      MS.WriteBuffer(Raw[1], Length(Raw));
    MS.Position := 0;
    UseExt := Ext;
    if UseExt = '' then UseExt := '.jpg';
    try
      Pic.LoadFromStreamWithFileExt(MS, UseExt);
    except
      Pic.Clear;
    end;
  finally
    MS.Free;
  end;
end;

procedure TEditGameForm.btnBildClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Cover-Bild wählen';
    Dlg.Filter := 'Bilddateien (*.jpg;*.jpeg;*.png;*.bmp)|*.jpg;*.jpeg;*.png;*.bmp|Alle Dateien (*.*)|*.*';
    if Dlg.Execute then
    begin
      { Bild wird direkt eingelesen und Base64-kodiert im Speicher
        gehalten - keine Kopie mehr auf der Festplatte. Landet beim
        Speichern des Spiels direkt in der CSV-Zeile. }
      try
        SelectedCoverBase64 := FileToBase64(Dlg.FileName);
        SelectedCoverExt := LowerCase(ExtractFileExt(Dlg.FileName));
        if SelectedCoverExt = '' then
          SelectedCoverExt := '.jpg';
        lblCoverPath.Caption := ExtractFileName(Dlg.FileName) + ' (eingebettet)';
        LoadPictureFromBase64(imgCover.Picture, SelectedCoverBase64, SelectedCoverExt);
      except
        on E: Exception do
          ShowMessage('Cover konnte nicht eingelesen werden: ' + E.Message);
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TEditGameForm.btnExeBrowseClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  YearVal: Integer;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'Programmdatei des Spiels auswählen';
    Dlg.Filter := 'Programme (*.exe)|*.exe|Alle Dateien (*.*)|*.*';
    if edtExePath.Text <> '' then
      Dlg.InitialDir := ExtractFilePath(edtExePath.Text);
    if Dlg.Execute then
    begin
      edtExePath.Text := Dlg.FileName;

      { Automatik anhand des Erscheinungsjahres: aeltere Spiele (vor 1998)
        laufen unter Windows 11 (64-Bit) praktisch nie nativ, juengere immer
        oefter schon. Ohne bekanntes Jahr im Zweifel DOSBox aktivieren, da
        die meisten hier verwalteten Titel ohnehin alt sind. Laesst sich
        ueber "DOSBox-Einstellungen..." jederzeit von Hand umschalten. }
      if TryStrToInt(Trim(edtJahr.Text), YearVal) then
      begin
        if YearVal < 1998 then
          SelectedUseDosBox := 'Ja'
        else
          SelectedUseDosBox := 'Nein';
      end
      else
        SelectedUseDosBox := 'Ja';

      if SameText(Trim(SelectedUseDosBox), 'Ja') then
        btnDosBoxSettings.Caption := 'DOSBox-Einstellungen... (aktiv)'
      else
        btnDosBoxSettings.Caption := 'DOSBox-Einstellungen...';
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TEditGameForm.btnDosBoxSettingsClick(Sender: TObject);
begin
  { Der eigentliche Dialog kuemmert sich komplett um Zerlegen/Zusammenbauen
    des dosbox.conf-Textes - hier wird nur mit den aktuell gehaltenen
    Werten hinein- und wieder herausgegangen. }
  if ShowDosBoxSettings(SelectedUseDosBox, SelectedDosBoxConfig) then
  begin
    if SameText(Trim(SelectedUseDosBox), 'Ja') then
      btnDosBoxSettings.Caption := 'DOSBox-Einstellungen... (aktiv)'
    else
      btnDosBoxSettings.Caption := 'DOSBox-Einstellungen...';
  end;
end;

procedure TEditGameForm.btnScummVMSettingsClick(Sender: TObject);
begin
  if ShowScummVMSettings(SelectedUseScummVM, SelectedScummVMPath) then
  begin
    if SameText(Trim(SelectedUseScummVM), 'Ja') then
      btnScummVMSettings.Caption := 'ScummVM-Einstellungen... (aktiv)'
    else
      btnScummVMSettings.Caption := 'ScummVM-Einstellungen...';
  end;
end;

procedure TEditGameForm.btnFetchClick(Sender: TObject);
var
  Jahr, Entwickler, Publisher, RawgCoverURL, IgdbCoverURL, ErrorMsg,
  TempPath: String;
  TextOK, CoverOK: Boolean;
begin
  if Trim(edtName.Text) = '' then
  begin
    ShowMessage('Bitte zuerst einen Namen eingeben.');
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  btnFetch.Enabled := False;
  btnFetch.Caption := 'Lade...';
  Application.ProcessMessages;
  try
    { Jahr/Entwickler/Publisher: RAWG (dessen Cover-Feld ignorieren wir -
      das ist meist ein Screenshot, keine Box-Art). }
    TextOK := RawgFetchGameData(edtName.Text, Jahr, Entwickler, Publisher,
                RawgCoverURL, ErrorMsg);
    if TextOK then
    begin
      if Jahr <> '' then edtJahr.Text := Jahr;
      if Entwickler <> '' then edtEntwickler.Text := Entwickler;
      if Publisher <> '' then edtPublisher.Text := Publisher;
    end
    else
      ShowMessage('RAWG-Abruf (Jahr/Entwickler/Publisher) fehlgeschlagen: ' + ErrorMsg);

    { Cover: IGDB, das "cover" explizit von Screenshots/Artworks trennt.
      Download landet nur kurz in einer Temp-Datei, wird dann Base64-
      kodiert im Speicher gehalten und die Temp-Datei wieder geloescht -
      es bleibt keine dauerhafte Datei auf der Platte zurueck. }
    CoverOK := IgdbFetchCoverURL(edtName.Text, IgdbCoverURL, ErrorMsg);
    if CoverOK then
    begin
      TempPath := GetTempDir + 'spielesammlung_cover_tmp_' +
        FormatDateTime('hhnnsszzz', Now) + '.jpg';

      if RawgDownloadCover(IgdbCoverURL, TempPath, ErrorMsg) then
      begin
        try
          try
            SelectedCoverBase64 := FileToBase64(TempPath);
            SelectedCoverExt := '.jpg';
            lblCoverPath.Caption := 'Cover geladen (eingebettet)';
            LoadPictureFromBase64(imgCover.Picture, SelectedCoverBase64, SelectedCoverExt);
          except
            on E: Exception do
              ShowMessage('Cover konnte nicht eingelesen werden: ' + E.Message);
          end;
        finally
          if FileExists(TempPath) then
            DeleteFile(TempPath);
        end;
      end
      else
        ShowMessage('Cover-Download fehlgeschlagen: ' + ErrorMsg);
    end
    else
      ShowMessage('Cover-Suche (IGDB) fehlgeschlagen: ' + ErrorMsg);
  finally
    btnFetch.Enabled := True;
    btnFetch.Caption := 'Daten & Cover aus dem Netz laden';
    Screen.Cursor := crDefault;
  end;
end;

procedure TEditGameForm.edtWertKeyPress(Sender: TObject; var Key: char);
begin
  if not (Key in ['0'..'9', #8, #3, #22, #24]) then
    Key := #0;
end;

function ShowEditGame(var AName, ASprache, AMedium, AZustand, AInhalt,
  AVollstaendig, APublisher, AJahr, AEntwickler, APlattform, ACoverBase64,
  ACoverExt, AWert, AGenre, AExePath, AUseDosBox, ADosBoxConfig, AUseScummVM,
  AScummVMPath: String; const ATitle: String): Boolean;
var
  F: TEditGameForm;
  TopY: Integer;
  L2: TLabel;

  procedure AddField(const ACaption: String; AText: String; var AEdit: TEdit);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F.ScrollBox;
    L.SetBounds(10, TopY, 105, 20);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];
    AEdit := TEdit.Create(F);
    AEdit.Parent := F.ScrollBox;
    AEdit.SetBounds(120, TopY, 340, 25);
    AEdit.Text := AText;
    TopY += 32;
  end;

  procedure AddCombo(const ACaption: String; AText: String; AItems: array of String; var ACombo: TComboBox);
  var
    L: TLabel;
    i: Integer;
  begin
    L := TLabel.Create(F);
    L.Parent := F.ScrollBox;
    L.SetBounds(10, TopY, 105, 20);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];
    ACombo := TComboBox.Create(F);
    ACombo.Parent := F.ScrollBox;
    ACombo.SetBounds(120, TopY, 340, 25);
    ACombo.Style := csDropDownList;
    for i := 0 to High(AItems) do
      ACombo.Items.Add(AItems[i]);
    ACombo.ItemIndex := ACombo.Items.IndexOf(AText);
    if (ACombo.ItemIndex < 0) and (AText <> '') then
    begin
      ACombo.Items.Insert(0, AText);
      ACombo.ItemIndex := 0;
    end;
    TopY += 32;
  end;

  { Zwei sich gegenseitig ausschliessende Radiobuttons in einer Zeile.
    Braucht ein eigenes Traeger-Panel als Parent, sonst wuerden mehrere
    Radiobutton-Paare auf derselben ScrollBox versehentlich zu EINER
    gemeinsamen Gruppe verschmelzen (nur noch eine Auswahl insgesamt
    moeglich statt pro Feld). }
  procedure AddRadio2(const ACaption, Opt1, Opt2: String; SelectSecond: Boolean;
    var ARB1, ARB2: TRadioButton);
  var
    L: TLabel;
    PnlR: TPanel;
  begin
    L := TLabel.Create(F);
    L.Parent := F.ScrollBox;
    L.SetBounds(10, TopY, 105, 20);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];

    PnlR := TPanel.Create(F);
    PnlR.Parent := F.ScrollBox;
    PnlR.SetBounds(120, TopY, 340, 24);
    PnlR.BevelOuter := bvNone;

    ARB1 := TRadioButton.Create(F);
    ARB1.Parent := PnlR;
    ARB1.SetBounds(0, 2, 160, 20);
    ARB1.Caption := Opt1;
    ARB1.Checked := not SelectSecond;

    ARB2 := TRadioButton.Create(F);
    ARB2.Parent := PnlR;
    ARB2.SetBounds(170, 2, 160, 20);
    ARB2.Caption := Opt2;
    ARB2.Checked := SelectSecond;

    TopY += 32;
  end;

begin
  Result := False;
  F := TEditGameForm.CreateNew(Application);
  try
    F.Caption := ATitle;
    F.Width := 530;
    F.Height := 890; // war 850 - Platz fuer den zusaetzlichen ScummVM-Button
    F.Position := poScreenCenter;
    F.BorderStyle := bsToolWindow; // wie vorher, nur ohne Groessenaenderung
    F.SelectedCoverBase64 := ACoverBase64;
    F.SelectedCoverExt := ACoverExt;
    F.SelectedUseDosBox := AUseDosBox;
    F.SelectedDosBoxConfig := ADosBoxConfig;
    F.SelectedUseScummVM := AUseScummVM;
    F.SelectedScummVMPath := AScummVMPath;

    F.ScrollBox := TScrollBox.Create(F);
    F.ScrollBox.Parent := F;
    F.ScrollBox.Align := alClient;
    F.ScrollBox.BorderStyle := bsNone;
    F.ScrollBox.AutoScroll := True;

    TopY := 10;

    F.imgCover := TImage.Create(F);
    F.imgCover.Parent := F.ScrollBox;
    F.imgCover.SetBounds(120, TopY, 200, 250);
    F.imgCover.Stretch := True;
    F.imgCover.Proportional := True;
    F.imgCover.Center := True;
    LoadPictureFromBase64(F.imgCover.Picture, ACoverBase64, ACoverExt);

    F.btnBild := TButton.Create(F);
    F.btnBild.Parent := F.ScrollBox;
    F.btnBild.SetBounds(330, TopY + 5, 130, 30);
    F.btnBild.Caption := 'Bild wählen...';
    F.btnBild.OnClick := @F.btnBildClick;

    F.lblCoverPath := TLabel.Create(F);
    F.lblCoverPath.Parent := F.ScrollBox;
    F.lblCoverPath.SetBounds(120, TopY + 255, 340, 20);
    if ACoverBase64 <> '' then
      F.lblCoverPath.Caption := 'Cover vorhanden (eingebettet)'
    else
      F.lblCoverPath.Caption := '(Kein Bild)';

    TopY += 285;

    AddField('Name:', AName, F.edtName);
    AddRadio2('Plattform:', 'PC', 'Amiga', SameText(APlattform, 'Amiga'),
      F.rbPlatPC, F.rbPlatAmiga);

    F.btnFetch := TButton.Create(F);
    F.btnFetch.Parent := F.ScrollBox;
    F.btnFetch.SetBounds(120, TopY, 340, 30);
    F.btnFetch.Caption := 'Daten & Cover aus dem Netz laden';
    F.btnFetch.OnClick := @F.btnFetchClick;
    TopY += 40;

    AddCombo('Sprache:', ASprache, ['Deutsch', 'Englisch', 'DE + EN', 'Andere'], F.cmbSprache);
    AddCombo('Medium:', AMedium, ['5,25 Disk', '3,5 Disk', '5,25+3,5 Disk', 'CD-ROM', 'DVD-ROM'], F.cmbMedium);
    AddCombo('Zustand:', AZustand, ['Neu (eingeschweißt)', 'Neu', 'Neuwertig', 'Sehr Gut', 'Gut', 'Akzeptabel'], F.cmbZustand);
    AddField('Inhalt:', AInhalt, F.edtInhalt);
    AddRadio2('Vollständig:', 'Ja', 'Nein', SameText(AVollstaendig, 'Nein'),
      F.rbVollJa, F.rbVollNein);
    AddField('Publisher:', APublisher, F.edtPublisher);
    AddField('Jahr:', AJahr, F.edtJahr);
    F.edtJahr.MaxLength := 4;
    AddField('Entwickler:', AEntwickler, F.edtEntwickler);
    AddCombo('Genre:', AGenre, ['Action', 'Abenteuer', 'Rollenspiel', 'Strategie',
      'Simulation', 'Sport', 'Rennspiel', 'Shooter', 'Puzzle', 'Jump''n''Run',
      'Sonstige'], F.cmbGenre);
    AddField('Wert (€):', AWert, F.edtWert);
    F.edtWert.MaxLength := 10;
    F.edtWert.OnKeyPress := @F.edtWertKeyPress;

    { Programmpfad zum Starten des Spiels (fuer den "Spiel starten"-Button
      im Hauptfenster). Freitextfeld ist absichtlich schreibgeschuetzt -
      der Pfad soll ausschliesslich ueber den Dialog gewaehlt werden, damit
      er garantiert gueltig ist. }
    begin
      L2 := TLabel.Create(F);
      L2.Parent := F.ScrollBox;
      L2.SetBounds(10, TopY, 105, 20);
      L2.Caption := 'Programm (EXE):';
      L2.Font.Style := [fsBold];

      F.edtExePath := TEdit.Create(F);
      F.edtExePath.Parent := F.ScrollBox;
      F.edtExePath.SetBounds(120, TopY, 248, 25);
      F.edtExePath.Text := AExePath;
      F.edtExePath.ReadOnly := True;

      F.btnExeBrowse := TButton.Create(F);
      F.btnExeBrowse.Parent := F.ScrollBox;
      F.btnExeBrowse.SetBounds(373, TopY - 1, 87, 27);
      F.btnExeBrowse.Caption := 'Durchsuchen...';
      F.btnExeBrowse.OnClick := @F.btnExeBrowseClick;

      TopY += 32;

      F.btnDosBoxSettings := TButton.Create(F);
      F.btnDosBoxSettings.Parent := F.ScrollBox;
      F.btnDosBoxSettings.SetBounds(120, TopY, 340, 30);
      if SameText(Trim(AUseDosBox), 'Ja') then
        F.btnDosBoxSettings.Caption := 'DOSBox-Einstellungen... (aktiv)'
      else
        F.btnDosBoxSettings.Caption := 'DOSBox-Einstellungen...';
      F.btnDosBoxSettings.OnClick := @F.btnDosBoxSettingsClick;
      TopY += 40;

      F.btnScummVMSettings := TButton.Create(F);
      F.btnScummVMSettings.Parent := F.ScrollBox;
      F.btnScummVMSettings.SetBounds(120, TopY, 340, 30);
      if SameText(Trim(AUseScummVM), 'Ja') then
        F.btnScummVMSettings.Caption := 'ScummVM-Einstellungen... (aktiv)'
      else
        F.btnScummVMSettings.Caption := 'ScummVM-Einstellungen...';
      F.btnScummVMSettings.OnClick := @F.btnScummVMSettingsClick;
      TopY += 40;
    end;

    TopY += 10;

    F.btnOK := TButton.Create(F);
    F.btnOK.Parent := F.ScrollBox;
    F.btnOK.SetBounds(120, TopY, 130, 36);
    F.btnOK.Caption := 'Speichern';
    F.btnOK.ModalResult := mrOK;
    F.btnOK.Default := True;

    F.btnCancel := TButton.Create(F);
    F.btnCancel.Parent := F.ScrollBox;
    F.btnCancel.SetBounds(260, TopY, 130, 36);
    F.btnCancel.Caption := 'Abbrechen';
    F.btnCancel.ModalResult := mrCancel;
    F.btnCancel.Cancel := True;

    if F.ShowModal = mrOK then
    begin
      AName := F.edtName.Text;
      if F.cmbSprache.ItemIndex >= 0 then
        ASprache := F.cmbSprache.Items[F.cmbSprache.ItemIndex]
      else
        ASprache := '';
      if F.cmbMedium.ItemIndex >= 0 then
        AMedium := F.cmbMedium.Items[F.cmbMedium.ItemIndex]
      else
        AMedium := '';
      if F.cmbZustand.ItemIndex >= 0 then
        AZustand := F.cmbZustand.Items[F.cmbZustand.ItemIndex]
      else
        AZustand := '';
      AInhalt := F.edtInhalt.Text;
      if F.rbVollNein.Checked then
        AVollstaendig := 'Nein'
      else
        AVollstaendig := 'Ja';
      APublisher := F.edtPublisher.Text;
      AJahr := F.edtJahr.Text;
      AEntwickler := F.edtEntwickler.Text;
      if F.rbPlatAmiga.Checked then
        APlattform := 'Amiga'
      else
        APlattform := 'PC';
      ACoverBase64 := F.SelectedCoverBase64;
      ACoverExt := F.SelectedCoverExt;
      AWert := F.edtWert.Text;
      AExePath := F.edtExePath.Text;
      AUseDosBox := F.SelectedUseDosBox;
      ADosBoxConfig := F.SelectedDosBoxConfig;
      AUseScummVM := F.SelectedUseScummVM;
      AScummVMPath := F.SelectedScummVMPath;
      if F.cmbGenre.ItemIndex >= 0 then
        AGenre := F.cmbGenre.Items[F.cmbGenre.ItemIndex]
      else
        AGenre := '';
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
