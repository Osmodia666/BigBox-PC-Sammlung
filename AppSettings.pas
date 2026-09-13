unit AppSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

var
  RawgApiKey: String = '';
  IgdbClientId: String = '';
  IgdbClientSecret: String = '';

{ Laedt die API-Zugangsdaten aus einer INI-Datei (Abschnitt [API]). Fehlt
  die Datei, bleiben die Variablen einfach leer - RawgApi/IgdbApi zeigen
  dann ihre eigene "kein Key eingetragen"-Meldung. }
procedure LoadAppSettings(const APath: String);

{ Speichert die aktuellen Werte der obigen Variablen in die INI-Datei. }
procedure SaveAppSettings(const APath: String);

implementation

procedure LoadAppSettings(const APath: String);
var
  Ini: TIniFile;
begin
  if not FileExists(APath) then Exit;
  Ini := TIniFile.Create(APath);
  try
    RawgApiKey := Ini.ReadString('API', 'RawgApiKey', '');
    IgdbClientId := Ini.ReadString('API', 'IgdbClientId', '');
    IgdbClientSecret := Ini.ReadString('API', 'IgdbClientSecret', '');
  finally
    Ini.Free;
  end;
end;

procedure SaveAppSettings(const APath: String);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(APath);
  try
    Ini.WriteString('API', 'RawgApiKey', RawgApiKey);
    Ini.WriteString('API', 'IgdbClientId', IgdbClientId);
    Ini.WriteString('API', 'IgdbClientSecret', IgdbClientSecret);
  finally
    Ini.Free;
  end;
end;

end.
