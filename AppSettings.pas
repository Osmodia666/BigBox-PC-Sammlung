unit AppSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

type
  TFriend = record
    Name: String;
    URL: String; // Link zu seiner tauschliste.json
  end;
  TFriendArray = array of TFriend;

var
  RawgApiKey: String = '';
  IgdbClientId: String = '';
  IgdbClientSecret: String = '';
  NcUrl: String = '';
  NcUser: String = '';
  NcPass: String = '';
  ProfileDisplayName: String = '';
  Friends: TFriendArray;

{ Laedt die API-/Nextcloud-Zugangsdaten sowie Anzeigename/Freundesliste
  fuer die Tauschboerse aus einer INI-Datei (Abschnitte [API], [Nextcloud],
  [Profile], [Friends]). Fehlt die Datei, bleiben die Variablen einfach
  leer - RawgApi/IgdbApi/NextcloudSync zeigen dann ihre eigene "nichts
  eingetragen"-Meldung. }
procedure LoadAppSettings(const APath: String);

{ Speichert die aktuellen Werte der obigen Variablen in die INI-Datei. }
procedure SaveAppSettings(const APath: String);

{ Merkt sich geraeteweit (unabhaengig von einer bestimmten Sammlung), welche
  CSV-Datei zuletzt aktiv war, damit sie beim naechsten Programmstart
  automatisch wieder geoeffnet wird. Liegt bewusst nicht neben der CSV-Datei
  selbst, sondern in einem festen, nutzerspezifischen Konfigurationsordner -
  sonst koennte man die zuletzt genutzte Datei ja gar nicht erst finden. }
function LoadLastCSVPath: String;
procedure SaveLastCSVPath(const APath: String);

implementation

procedure LoadAppSettings(const APath: String);
var
  Ini: TIniFile;
  i, Count: Integer;
begin
  if not FileExists(APath) then Exit;
  Ini := TIniFile.Create(APath);
  try
    RawgApiKey := Ini.ReadString('API', 'RawgApiKey', '');
    IgdbClientId := Ini.ReadString('API', 'IgdbClientId', '');
    IgdbClientSecret := Ini.ReadString('API', 'IgdbClientSecret', '');
    NcUrl := Ini.ReadString('Nextcloud', 'Url', '');
    NcUser := Ini.ReadString('Nextcloud', 'User', '');
    NcPass := Ini.ReadString('Nextcloud', 'Pass', '');
    ProfileDisplayName := Ini.ReadString('Profile', 'DisplayName', '');

    Count := Ini.ReadInteger('Friends', 'Count', 0);
    SetLength(Friends, Count);
    for i := 0 to Count - 1 do
    begin
      Friends[i].Name := Ini.ReadString('Friends', 'Name' + IntToStr(i), '');
      Friends[i].URL := Ini.ReadString('Friends', 'Url' + IntToStr(i), '');
    end;
  finally
    Ini.Free;
  end;
end;

procedure SaveAppSettings(const APath: String);
var
  Ini: TIniFile;
  i: Integer;
begin
  Ini := TIniFile.Create(APath);
  try
    Ini.WriteString('API', 'RawgApiKey', RawgApiKey);
    Ini.WriteString('API', 'IgdbClientId', IgdbClientId);
    Ini.WriteString('API', 'IgdbClientSecret', IgdbClientSecret);
    Ini.WriteString('Nextcloud', 'Url', NcUrl);
    Ini.WriteString('Nextcloud', 'User', NcUser);
    Ini.WriteString('Nextcloud', 'Pass', NcPass);
    Ini.WriteString('Profile', 'DisplayName', ProfileDisplayName);

    { Alte, jetzt ueberzaehlige Friends-Eintraege (nach dem Entfernen eines
      Freundes) aus der Datei entfernen, statt sie als Karteileichen stehen
      zu lassen. }
    Ini.EraseSection('Friends');
    Ini.WriteInteger('Friends', 'Count', Length(Friends));
    for i := 0 to High(Friends) do
    begin
      Ini.WriteString('Friends', 'Name' + IntToStr(i), Friends[i].Name);
      Ini.WriteString('Friends', 'Url' + IntToStr(i), Friends[i].URL);
    end;
  finally
    Ini.Free;
  end;
end;

function PointerConfigFile: String;
var
  Dir: String;
begin
  Dir := GetAppConfigDir(False);
  if Dir = '' then
    Dir := GetUserDir;
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Result := IncludeTrailingPathDelimiter(Dir) + 'lastfile.ini';
end;

function LoadLastCSVPath: String;
var
  Ini: TIniFile;
begin
  Result := '';
  if not FileExists(PointerConfigFile) then Exit;
  Ini := TIniFile.Create(PointerConfigFile);
  try
    Result := Ini.ReadString('General', 'CSVPath', '');
  finally
    Ini.Free;
  end;
end;

procedure SaveLastCSVPath(const APath: String);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(PointerConfigFile);
  try
    Ini.WriteString('General', 'CSVPath', APath);
  finally
    Ini.Free;
  end;
end;

end.
