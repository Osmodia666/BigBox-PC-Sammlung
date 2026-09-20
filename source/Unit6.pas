unit Unit6;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  fpjson, jsonparser, AppSettings, NextcloudSync;

type
  { Leichtgewichtiges Spiel-Abbild fuer die Tauschboerse - absichtlich ein
    eigener Record statt Unit1.TGame, damit diese Unit nicht auf Unit1
    zurueckverweisen muss (gleiche Trennung wie bei Unit2/Unit3/Unit5). }
  TTradeGame = record
    Name, Jahr, Publisher, Entwickler, Medium, Zustand, Genre, Wert,
    CoverBase64, CoverExt: String;
  end;
  TTradeGameArray = array of TTradeGame;

  TFriendCacheEntry = record
    Loaded: Boolean;
    OK: Boolean;
    OwnerName: String;
    Games: TTradeGameArray;
    ErrorMsg: String;
  end;

{ Baut das JSON-Dokument, das per "Als Datei exportieren" bzw. "Zu
  Nextcloud hochladen" veroeffentlicht wird - exakt dasselbe Format wie
  buildTauschliste() in der Web-App (docs/index.html), damit Freunde
  unabhaengig davon, welche der beiden Apps du benutzt, deine Liste lesen
  koennen. }
function BuildTauschlisteJSON(const OwnerName: String;
  const Games: array of TTradeGame): String;

{ Liest ein solches JSON-Dokument (von einem Freund) wieder ein. }
function ParseTauschlisteJSON(const JSONText: String; out OwnerName: String;
  out Games: TTradeGameArray; out ErrorMsg: String): Boolean;

{ Zeigt den Tauschboerse-Dialog: eigene tauschbare Spiele, Veroeffentlichen
  (Datei-Export bzw. Nextcloud-Upload) und Freundesverwaltung (Hinzufuegen/
  Entfernen/Abrufen). AppSettings.Friends/ProfileDisplayName werden direkt
  waehrend der Bedienung veraendert (kein Abbrechen-Zustand noetig) - der
  Aufrufer sollte danach AppSettings.SaveAppSettings aufrufen, um das
  dauerhaft zu machen. MyTradeGames sind die aktuell als "Tauschbar"
  markierten Spiele der eigenen Sammlung. }
procedure ShowTauschboerse(const MyTradeGames: array of TTradeGame;
  const ANcUrl, ANcUser, ANcPass: String);

implementation

function BuildTauschlisteJSON(const OwnerName: String;
  const Games: array of TTradeGame): String;
var
  Root, GameObj: TJSONObject;
  Arr: TJSONArray;
  i: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('owner', OwnerName);
    Root.Add('updatedAt', Int64(DateTimeToUnix(Now)) * 1000);
    Arr := TJSONArray.Create;
    for i := 0 to High(Games) do
    begin
      GameObj := TJSONObject.Create;
      GameObj.Add('name', Games[i].Name);
      GameObj.Add('jahr', Games[i].Jahr);
      GameObj.Add('publisher', Games[i].Publisher);
      GameObj.Add('entwickler', Games[i].Entwickler);
      GameObj.Add('medium', Games[i].Medium);
      GameObj.Add('zustand', Games[i].Zustand);
      GameObj.Add('genre', Games[i].Genre);
      GameObj.Add('wert', Games[i].Wert);
      GameObj.Add('coverBase64', Games[i].CoverBase64);
      GameObj.Add('coverExt', Games[i].CoverExt);
      Arr.Add(GameObj);
    end;
    Root.Add('games', Arr);
    Result := Root.FormatJSON;
  finally
    Root.Free;
  end;
end;

function JSONStrField(O: TJSONObject; const Key: String): String;
var
  D: TJSONData;
begin
  Result := '';
  D := O.Find(Key);
  if (D <> nil) and (D.JSONType in [jtString, jtNumber]) then
    Result := D.AsString;
end;

function ParseTauschlisteJSON(const JSONText: String; out OwnerName: String;
  out Games: TTradeGameArray; out ErrorMsg: String): Boolean;
var
  Data: TJSONData;
  Obj, GObj: TJSONObject;
  GamesField: TJSONData;
  Arr: TJSONArray;
  i: Integer;
begin
  Result := False;
  OwnerName := '';
  SetLength(Games, 0);
  ErrorMsg := '';
  Data := nil;
  try
    try
      Data := GetJSON(JSONText);
    except
      on E: Exception do
      begin
        ErrorMsg := 'Ungültiges JSON: ' + E.Message;
        Exit;
      end;
    end;
    if Data.JSONType <> jtObject then
    begin
      ErrorMsg := 'Unerwartetes Format.';
      Exit;
    end;
    Obj := TJSONObject(Data);
    OwnerName := JSONStrField(Obj, 'owner');
    GamesField := Obj.Find('games');
    if (GamesField = nil) or (GamesField.JSONType <> jtArray) then
    begin
      ErrorMsg := 'Keine Spieleliste gefunden.';
      Exit;
    end;
    Arr := TJSONArray(GamesField);
    SetLength(Games, Arr.Count);
    for i := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[i].JSONType <> jtObject then Continue;
      GObj := TJSONObject(Arr.Items[i]);
      Games[i].Name := JSONStrField(GObj, 'name');
      Games[i].Jahr := JSONStrField(GObj, 'jahr');
      Games[i].Publisher := JSONStrField(GObj, 'publisher');
      Games[i].Entwickler := JSONStrField(GObj, 'entwickler');
      Games[i].Medium := JSONStrField(GObj, 'medium');
      Games[i].Zustand := JSONStrField(GObj, 'zustand');
      Games[i].Genre := JSONStrField(GObj, 'genre');
      Games[i].Wert := JSONStrField(GObj, 'wert');
      Games[i].CoverBase64 := JSONStrField(GObj, 'coverBase64');
      Games[i].CoverExt := JSONStrField(GObj, 'coverExt');
    end;
    Result := True;
  finally
    Data.Free;
  end;
end;

{ Laedt eine (oeffentliche, unauthentifizierte) tauschliste.json per HTTP
  GET herunter und parst sie direkt. Nutzt NcDownloadFile mit leeren
  Zugangsdaten - Freunde-Links sind normale oeffentliche Freigabelinks,
  keine per Passwort geschuetzten WebDAV-Adressen. }
function FetchFriendTauschliste(const URL: String; out OwnerName: String;
  out Games: TTradeGameArray; out ErrorMsg: String): Boolean;
var
  TmpPath: String;
  SL: TStringList;
begin
  Result := False;
  TmpPath := GetTempDir(False) + 'bigbox_friend_' + IntToStr(Random(999999)) + '.json';
  if not NextcloudSync.NcDownloadFile(URL, '', '', TmpPath, ErrorMsg) then
    Exit;
  try
    SL := TStringList.Create;
    try
      SL.LoadFromFile(TmpPath);
      Result := ParseTauschlisteJSON(SL.Text, OwnerName, Games, ErrorMsg);
    finally
      SL.Free;
    end;
  finally
    if FileExists(TmpPath) then
      DeleteFile(TmpPath);
  end;
end;

type
  { TTauschboerseForm }
  TTauschboerseForm = class(TForm)
    lbMyGames: TListBox;
    edtDisplayName: TEdit;
    btnExport: TButton;
    btnPushNC: TButton;
    lblPublishStatus: TLabel;
    edtFriendName: TEdit;
    edtFriendUrl: TEdit;
    btnAddFriend: TButton;
    lbFriends: TListBox;
    btnRefreshFriend: TButton;
    btnRemoveFriend: TButton;
    memFriendGames: TMemo;
    btnClose: TButton;
    procedure btnExportClick(Sender: TObject);
    procedure btnPushNCClick(Sender: TObject);
    procedure btnAddFriendClick(Sender: TObject);
    procedure btnRefreshFriendClick(Sender: TObject);
    procedure btnRemoveFriendClick(Sender: TObject);
    procedure lbFriendsClick(Sender: TObject);
  public
    MyGames: TTradeGameArray;
    NcUrl, NcUser, NcPass: String;
    FriendCache: array of TFriendCacheEntry;
    procedure RebuildFriendsListbox;
    procedure RefreshFriendAt(Idx: Integer);
    procedure ShowFriendGamesInMemo(Idx: Integer);
  end;

procedure TTauschboerseForm.RebuildFriendsListbox;
var
  i: Integer;
  Line: String;
begin
  lbFriends.Items.BeginUpdate;
  try
    lbFriends.Items.Clear;
    for i := 0 to High(AppSettings.Friends) do
    begin
      if (i <= High(FriendCache)) and FriendCache[i].Loaded then
      begin
        if FriendCache[i].OK then
          Line := AppSettings.Friends[i].Name + '  —  ' + IntToStr(Length(FriendCache[i].Games)) + ' tauschbare Spiele'
        else
          Line := AppSettings.Friends[i].Name + '  —  Fehler';
      end
      else
        Line := AppSettings.Friends[i].Name + '  —  (noch nicht geladen)';
      lbFriends.Items.Add(Line);
    end;
  finally
    lbFriends.Items.EndUpdate;
  end;
end;

procedure TTauschboerseForm.RefreshFriendAt(Idx: Integer);
var
  OwnerName, ErrorMsg: String;
  Games: TTradeGameArray;
  OK: Boolean;
begin
  if (Idx < 0) or (Idx > High(AppSettings.Friends)) then Exit;
  if Idx > High(FriendCache) then
    SetLength(FriendCache, Idx + 1);

  Screen.Cursor := crHourglass;
  try
    OK := FetchFriendTauschliste(AppSettings.Friends[Idx].URL, OwnerName, Games, ErrorMsg);
  finally
    Screen.Cursor := crDefault;
  end;

  FriendCache[Idx].Loaded := True;
  FriendCache[Idx].OK := OK;
  FriendCache[Idx].OwnerName := OwnerName;
  FriendCache[Idx].Games := Games;
  FriendCache[Idx].ErrorMsg := ErrorMsg;
  RebuildFriendsListbox;
end;

procedure TTauschboerseForm.ShowFriendGamesInMemo(Idx: Integer);
var
  i: Integer;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    if (Idx < 0) or (Idx > High(FriendCache)) or not FriendCache[Idx].Loaded then
      Lines.Add('Noch nicht geladen - "Ausgewählten aktualisieren" klicken.')
    else if not FriendCache[Idx].OK then
      Lines.Add('Fehler: ' + FriendCache[Idx].ErrorMsg)
    else if Length(FriendCache[Idx].Games) = 0 then
      Lines.Add('Aktuell keine tauschbaren Spiele veröffentlicht.')
    else
      for i := 0 to High(FriendCache[Idx].Games) do
        Lines.Add('• ' + FriendCache[Idx].Games[i].Name + ' (' + FriendCache[Idx].Games[i].Jahr +
          ')  —  ' + FriendCache[Idx].Games[i].Zustand + '  —  ' + FriendCache[Idx].Games[i].Publisher);
    memFriendGames.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TTauschboerseForm.btnExportClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  SL: TStringList;
begin
  AppSettings.ProfileDisplayName := Trim(edtDisplayName.Text);
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Title := 'Tauschliste exportieren';
    Dlg.Filter := 'JSON-Dateien (*.json)|*.json';
    Dlg.DefaultExt := 'json';
    Dlg.FileName := 'tauschliste.json';
    if Dlg.Execute then
    begin
      SL := TStringList.Create;
      try
        SL.Text := BuildTauschlisteJSON(AppSettings.ProfileDisplayName, MyGames);
        SL.SaveToFile(Dlg.FileName);
        lblPublishStatus.Caption := 'Exportiert: ' + Dlg.FileName;
      finally
        SL.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TTauschboerseForm.btnPushNCClick(Sender: TObject);
var
  JSONText, TargetURL, TmpPath, ErrorMsg: String;
  SL: TStringList;
  OK: Boolean;
begin
  AppSettings.ProfileDisplayName := Trim(edtDisplayName.Text);

  if Trim(NcUrl) = '' then
  begin
    lblPublishStatus.Caption := 'Keine Nextcloud-Verbindung eingerichtet (siehe Einstellungen).';
    Exit;
  end;

  JSONText := BuildTauschlisteJSON(AppSettings.ProfileDisplayName, MyGames);
  TargetURL := NextcloudSync.ReplaceLastURLSegment(NcUrl, 'tauschliste.json');
  TmpPath := GetTempDir(False) + 'bigbox_tauschliste_' + IntToStr(Random(999999)) + '.json';
  SL := TStringList.Create;
  try
    SL.Text := JSONText;
    SL.SaveToFile(TmpPath);
  finally
    SL.Free;
  end;

  Screen.Cursor := crHourglass;
  try
    OK := NextcloudSync.NcUploadFile(TargetURL, NcUser, NcPass, TmpPath, ErrorMsg);
  finally
    Screen.Cursor := crDefault;
    if FileExists(TmpPath) then
      DeleteFile(TmpPath);
  end;

  if OK then
    lblPublishStatus.Caption := 'Veröffentlicht (' + FormatDateTime('dd.mm.yyyy hh:nn', Now) +
      '). Denk daran, dafür einmalig einen öffentlichen Freigabelink auf Nextcloud einzurichten.'
  else
    lblPublishStatus.Caption := 'Fehler: ' + ErrorMsg;
end;

procedure TTauschboerseForm.btnAddFriendClick(Sender: TObject);
var
  n: Integer;
begin
  if (Trim(edtFriendName.Text) = '') or (Trim(edtFriendUrl.Text) = '') then
  begin
    ShowMessage('Bitte Name und Link eintragen.');
    Exit;
  end;
  n := Length(AppSettings.Friends);
  SetLength(AppSettings.Friends, n + 1);
  AppSettings.Friends[n].Name := Trim(edtFriendName.Text);
  AppSettings.Friends[n].URL := Trim(edtFriendUrl.Text);
  edtFriendName.Text := '';
  edtFriendUrl.Text := '';
  RebuildFriendsListbox;
  RefreshFriendAt(n);
end;

procedure TTauschboerseForm.btnRemoveFriendClick(Sender: TObject);
var
  Idx, i: Integer;
begin
  Idx := lbFriends.ItemIndex;
  if (Idx < 0) or (Idx > High(AppSettings.Friends)) then
  begin
    ShowMessage('Bitte zuerst einen Freund in der Liste auswählen.');
    Exit;
  end;
  for i := Idx to High(AppSettings.Friends) - 1 do
    AppSettings.Friends[i] := AppSettings.Friends[i + 1];
  SetLength(AppSettings.Friends, Length(AppSettings.Friends) - 1);

  for i := Idx to High(FriendCache) - 1 do
    FriendCache[i] := FriendCache[i + 1];
  if Length(FriendCache) > 0 then
    SetLength(FriendCache, Length(FriendCache) - 1);

  RebuildFriendsListbox;
  memFriendGames.Lines.Clear;
end;

procedure TTauschboerseForm.btnRefreshFriendClick(Sender: TObject);
begin
  if lbFriends.ItemIndex < 0 then
  begin
    ShowMessage('Bitte zuerst einen Freund in der Liste auswählen.');
    Exit;
  end;
  RefreshFriendAt(lbFriends.ItemIndex);
  ShowFriendGamesInMemo(lbFriends.ItemIndex);
end;

procedure TTauschboerseForm.lbFriendsClick(Sender: TObject);
begin
  ShowFriendGamesInMemo(lbFriends.ItemIndex);
end;

procedure ShowTauschboerse(const MyTradeGames: array of TTradeGame;
  const ANcUrl, ANcUser, ANcPass: String);
var
  F: TTauschboerseForm;
  TopY: Integer;
  i: Integer;

  procedure AddLbl(const ACaption: String);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.SetBounds(20, TopY, 460, 18);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];
    TopY += 22;
  end;

begin
  F := TTauschboerseForm.CreateNew(Application);
  try
    F.Caption := 'Tauschbörse';
    F.Width := 520;
    F.Position := poScreenCenter;
    F.BorderStyle := bsSizeable;

    SetLength(F.MyGames, Length(MyTradeGames));
    for i := 0 to High(MyTradeGames) do
      F.MyGames[i] := MyTradeGames[i];
    F.NcUrl := ANcUrl;
    F.NcUser := ANcUser;
    F.NcPass := ANcPass;

    TopY := 16;

    AddLbl('Meine tauschbaren Spiele:');
    F.lbMyGames := TListBox.Create(F);
    F.lbMyGames.Parent := F;
    F.lbMyGames.SetBounds(20, TopY, 460, 100);
    for i := 0 to High(F.MyGames) do
      F.lbMyGames.Items.Add(F.MyGames[i].Name + ' (' + F.MyGames[i].Jahr + ')');
    if Length(F.MyGames) = 0 then
      F.lbMyGames.Items.Add('(keine - im Bearbeiten-Dialog "Tauschbar" ankreuzen)');
    TopY += 110;

    AddLbl('Veröffentlichen:');
    F.edtDisplayName := TEdit.Create(F);
    F.edtDisplayName.Parent := F;
    F.edtDisplayName.SetBounds(20, TopY, 460, 25);
    F.edtDisplayName.Text := AppSettings.ProfileDisplayName;
    F.edtDisplayName.TextHint := 'Dein Anzeigename für Freunde';
    TopY += 32;
    F.btnExport := TButton.Create(F);
    F.btnExport.Parent := F;
    F.btnExport.SetBounds(20, TopY, 220, 28);
    F.btnExport.Caption := 'Als Datei exportieren';
    F.btnExport.OnClick := @F.btnExportClick;
    F.btnPushNC := TButton.Create(F);
    F.btnPushNC.Parent := F;
    F.btnPushNC.SetBounds(250, TopY, 230, 28);
    F.btnPushNC.Caption := 'Zu Nextcloud hochladen';
    F.btnPushNC.Enabled := Trim(ANcUrl) <> '';
    F.btnPushNC.OnClick := @F.btnPushNCClick;
    TopY += 36;
    F.lblPublishStatus := TLabel.Create(F);
    F.lblPublishStatus.Parent := F;
    F.lblPublishStatus.SetBounds(20, TopY, 460, 34);
    F.lblPublishStatus.WordWrap := True;
    F.lblPublishStatus.AutoSize := False;
    F.lblPublishStatus.Height := 34;
    F.lblPublishStatus.Font.Color := clNavy;
    TopY += 42;

    AddLbl('Freund hinzufügen (Name + Link zu seiner tauschliste.json):');
    F.edtFriendName := TEdit.Create(F);
    F.edtFriendName.Parent := F;
    F.edtFriendName.SetBounds(20, TopY, 150, 25);
    F.edtFriendName.TextHint := 'Name';
    F.edtFriendUrl := TEdit.Create(F);
    F.edtFriendUrl.Parent := F;
    F.edtFriendUrl.SetBounds(180, TopY, 220, 25);
    F.edtFriendUrl.TextHint := 'https://…/tauschliste.json';
    F.btnAddFriend := TButton.Create(F);
    F.btnAddFriend.Parent := F;
    F.btnAddFriend.SetBounds(410, TopY, 70, 25);
    F.btnAddFriend.Caption := '+';
    F.btnAddFriend.OnClick := @F.btnAddFriendClick;
    TopY += 34;

    AddLbl('Meine Freunde:');
    F.lbFriends := TListBox.Create(F);
    F.lbFriends.Parent := F;
    F.lbFriends.SetBounds(20, TopY, 460, 100);
    F.lbFriends.OnClick := @F.lbFriendsClick;
    TopY += 108;
    F.btnRefreshFriend := TButton.Create(F);
    F.btnRefreshFriend.Parent := F;
    F.btnRefreshFriend.SetBounds(20, TopY, 220, 28);
    F.btnRefreshFriend.Caption := 'Ausgewählten aktualisieren';
    F.btnRefreshFriend.OnClick := @F.btnRefreshFriendClick;
    F.btnRemoveFriend := TButton.Create(F);
    F.btnRemoveFriend.Parent := F;
    F.btnRemoveFriend.SetBounds(250, TopY, 230, 28);
    F.btnRemoveFriend.Caption := 'Entfernen';
    F.btnRemoveFriend.OnClick := @F.btnRemoveFriendClick;
    TopY += 36;

    AddLbl('Tauschbare Spiele des ausgewählten Freundes:');
    F.memFriendGames := TMemo.Create(F);
    F.memFriendGames.Parent := F;
    F.memFriendGames.SetBounds(20, TopY, 460, 140);
    F.memFriendGames.ReadOnly := True;
    F.memFriendGames.ScrollBars := ssVertical;
    TopY += 150;

    F.btnClose := TButton.Create(F);
    F.btnClose.Parent := F;
    F.btnClose.SetBounds(200, TopY, 120, 36);
    F.btnClose.Caption := 'Schließen';
    F.btnClose.ModalResult := mrOK;
    F.btnClose.Default := True;
    TopY += 46;

    F.Height := TopY + 90;

    F.RebuildFriendsListbox;
    for i := 0 to High(AppSettings.Friends) do
      F.RefreshFriendAt(i);

    F.ShowModal;
  finally
    F.Free;
  end;
end;

initialization
  Randomize;

end.
