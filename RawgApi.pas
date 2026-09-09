unit RawgApi;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, openssl, opensslsockets, httpprotocol,
  fpjson, jsonparser;

const
  { Kostenlosen Key holen unter https://rawg.io/apidocs (kurze Registrierung,
    kein Zahlungsmittel noetig) und hier eintragen. }
  RAWG_API_KEY = 'e2064b227d2b4bfe859e025d1253553b';

{ Sucht das Spiel bei RAWG und liefert Jahr/Entwickler/Publisher/Cover-URL.
  Liefert False bei Fehler oder wenn nichts gefunden wurde; ErrorMsg
  enthaelt dann eine fuer den Nutzer verstaendliche Meldung. }
function RawgFetchGameData(const GameName: String;
  out Jahr, Entwickler, Publisher, CoverURL: String;
  out ErrorMsg: String): Boolean;

{ Laedt das Bild von CoverURL nach DestPath herunter. }
function RawgDownloadCover(const CoverURL, DestPath: String;
  out ErrorMsg: String): Boolean;

implementation

function HttpGetText(const URL: String; out ResponseText: String;
  out ErrorMsg: String): Boolean;
var
  Client: TFPHTTPClient;
begin
  Result := False;
  ResponseText := '';
  ErrorMsg := '';
  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; SpieleSammlung/1.0)');
    Client.AllowRedirect := True;
    try
      ResponseText := Client.Get(URL);
      Result := True;
    except
      on E: Exception do
        ErrorMsg := E.Message;
    end;
  finally
    Client.Free;
  end;
end;

function JSONStr(Obj: TJSONObject; const Key: String): String;
var
  D: TJSONData;
begin
  Result := '';
  D := Obj.Find(Key);
  if (D <> nil) and (D.JSONType = jtString) then
    Result := D.AsString;
end;

function JoinNames(Arr: TJSONArray): String;
var
  i: Integer;
  Obj: TJSONObject;
  NameVal: String;
begin
  Result := '';
  if Arr = nil then Exit;
  for i := 0 to Arr.Count - 1 do
  begin
    if Arr.Items[i].JSONType <> jtObject then Continue;
    Obj := TJSONObject(Arr.Items[i]);
    NameVal := JSONStr(Obj, 'name');
    if NameVal = '' then Continue;
    if Result = '' then
      Result := NameVal
    else
      Result := Result + ' / ' + NameVal;
  end;
end;

function RawgFetchGameData(const GameName: String;
  out Jahr, Entwickler, Publisher, CoverURL: String;
  out ErrorMsg: String): Boolean;
var
  SearchURL, DetailURL, ResponseText, Released: String;
  SearchData, DetailData: TJSONData;
  SearchObj, DetailObj: TJSONObject;
  ResultsField: TJSONData;
  ResultsArr: TJSONArray;
  IdField: TJSONData;
  GameId: Int64;
  DevField, PubField: TJSONData;
begin
  Result := False;
  Jahr := ''; Entwickler := ''; Publisher := ''; CoverURL := ''; ErrorMsg := '';

  if Trim(RAWG_API_KEY) = '' then
  begin
    ErrorMsg := 'Kein RAWG-API-Key eingetragen (siehe RawgApi.pas).';
    Exit;
  end;

  SearchURL := 'https://api.rawg.io/api/games?key=' + RAWG_API_KEY +
               '&search=' + HTTPEncode(GameName) + '&page_size=1';

  if not HttpGetText(SearchURL, ResponseText, ErrorMsg) then
  begin
    ErrorMsg := 'Netzwerkfehler bei der Suche: ' + ErrorMsg;
    Exit;
  end;

  GameId := 0;
  SearchData := nil;
  try
    try
      SearchData := GetJSON(ResponseText);
    except
      on E: Exception do
      begin
        ErrorMsg := 'Antwort konnte nicht gelesen werden: ' + E.Message;
        Exit;
      end;
    end;

    if SearchData.JSONType <> jtObject then
    begin
      ErrorMsg := 'Unerwartetes Antwortformat bei der Suche.';
      Exit;
    end;
    SearchObj := TJSONObject(SearchData);

    ResultsField := SearchObj.Find('results');
    if (ResultsField = nil) or (ResultsField.JSONType <> jtArray) then
    begin
      ErrorMsg := 'Keine Ergebnisliste in der Antwort.';
      Exit;
    end;
    ResultsArr := TJSONArray(ResultsField);

    if ResultsArr.Count = 0 then
    begin
      ErrorMsg := 'Kein Treffer bei RAWG für "' + GameName + '".';
      Exit;
    end;

    IdField := TJSONObject(ResultsArr.Items[0]).Find('id');
    if IdField = nil then
    begin
      ErrorMsg := 'Treffer ohne ID erhalten.';
      Exit;
    end;
    GameId := IdField.AsInt64;
  finally
    SearchData.Free;
  end;

  DetailURL := 'https://api.rawg.io/api/games/' + IntToStr(GameId) +
               '?key=' + RAWG_API_KEY;

  if not HttpGetText(DetailURL, ResponseText, ErrorMsg) then
  begin
    ErrorMsg := 'Netzwerkfehler bei den Details: ' + ErrorMsg;
    Exit;
  end;

  DetailData := nil;
  try
    try
      DetailData := GetJSON(ResponseText);
    except
      on E: Exception do
      begin
        ErrorMsg := 'Detailantwort konnte nicht gelesen werden: ' + E.Message;
        Exit;
      end;
    end;

    if DetailData.JSONType <> jtObject then
    begin
      ErrorMsg := 'Unerwartetes Antwortformat bei den Details.';
      Exit;
    end;
    DetailObj := TJSONObject(DetailData);

    Released := JSONStr(DetailObj, 'released');
    if Length(Released) >= 4 then
      Jahr := Copy(Released, 1, 4);

    DevField := DetailObj.Find('developers');
    if (DevField <> nil) and (DevField.JSONType = jtArray) then
      Entwickler := JoinNames(TJSONArray(DevField));

    PubField := DetailObj.Find('publishers');
    if (PubField <> nil) and (PubField.JSONType = jtArray) then
      Publisher := JoinNames(TJSONArray(PubField));

    CoverURL := JSONStr(DetailObj, 'background_image');

    Result := True;
  finally
    DetailData.Free;
  end;
end;

function RawgDownloadCover(const CoverURL, DestPath: String;
  out ErrorMsg: String): Boolean;
var
  Client: TFPHTTPClient;
  FS: TFileStream;
begin
  Result := False;
  ErrorMsg := '';
  if CoverURL = '' then
  begin
    ErrorMsg := 'Keine Cover-URL vorhanden.';
    Exit;
  end;

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; SpieleSammlung/1.0)');
    Client.AllowRedirect := True;
    try
      FS := TFileStream.Create(DestPath, fmCreate);
      try
        Client.Get(CoverURL, FS);
        Result := FS.Size > 0;
      finally
        FS.Free;
      end;
      if not Result then
        ErrorMsg := 'Download fehlgeschlagen (leere Datei).';
    except
      on E: Exception do
        ErrorMsg := E.Message;
    end;
  finally
    Client.Free;
  end;
end;

initialization
  { FPCs eingebaute Ratensuche fuer OpenSSL-DLL-Namen ist auf alte
    1.1-Versionen ausgelegt und passt nicht zu aktuell erhaeltlichen
    OpenSSL-Installern (die liefern die 3.x-Reihe). Wir legen die
    gesuchten Dateinamen deshalb hier explizit fest, DLLUtilName/
    DLLSSLName sind die zuerst probierten Namen (siehe openssl.pas).
    -> Diese beiden Dateien muessen neben der .exe liegen:
       Windows 64-Bit: libcrypto-3-x64.dll, libssl-3-x64.dll
       Windows 32-Bit: libcrypto-3.dll,     libssl-3.dll }
  {$IFDEF MSWINDOWS}
    {$IFDEF WIN64}
    DLLUtilName := 'libcrypto-4-x64.dll';
    DLLSSLName := 'libssl-4-x64.dll';
    {$ELSE}
    DLLUtilName := 'libcrypto-3.dll';
    DLLSSLName := 'libssl-3.dll';
    {$ENDIF}
  {$ENDIF}

end.
