unit IgdbApi;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, openssl, opensslsockets, fpjson, jsonparser;

const
  { Kostenloses Twitch-Entwicklerkonto noetig (IGDB gehoert zu Twitch):
    1. https://dev.twitch.tv/console/apps  ->  "Registrieren"
    2. Name frei waehlbar, OAuth Redirect URL z.B. http://localhost,
       Kategorie "Application Integration" oder "Website Integration"
    3. Client-ID wird direkt angezeigt; "Neues Secret erstellen" fuers
       Client-Secret
    Beides unten eintragen. }
  IGDB_CLIENT_ID = 's0r5nobvuvpljlt3kwjh45lxhaa6zy';
  IGDB_CLIENT_SECRET = '96ozallbtkxuczscac7xn5w2odnael';

{ Sucht bei IGDB gezielt nach dem Box-Cover (nicht Screenshot/Artwork) und
  liefert eine fertige Bild-URL in hoher Aufloesung. }
function IgdbFetchCoverURL(const GameName: String; out CoverURL: String;
  out ErrorMsg: String): Boolean;

implementation

function HttpPostText(const URL, Body, AClientId, ABearerToken: String;
  out ResponseText: String; out ErrorMsg: String): Boolean;
var
  Client: TFPHTTPClient;
  ReqStream: TRawByteStringStream;
begin
  Result := False;
  ResponseText := '';
  ErrorMsg := '';
  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; SpieleSammlung/1.0)');
    if AClientId <> '' then
      Client.AddHeader('Client-ID', AClientId);
    if ABearerToken <> '' then
      Client.AddHeader('Authorization', 'Bearer ' + ABearerToken);
    Client.AllowRedirect := True;
    ReqStream := TRawByteStringStream.Create(Body);
    try
      Client.RequestBody := ReqStream;
      try
        ResponseText := Client.Post(URL);
        Result := True;
      except
        on E: Exception do
          ErrorMsg := E.Message;
      end;
    finally
      Client.RequestBody := nil;
      ReqStream.Free;
    end;
  finally
    Client.Free;
  end;
end;

function IgdbGetAppToken(out Token: String; out ErrorMsg: String): Boolean;
var
  URL, ResponseText: String;
  Data: TJSONData;
  Obj: TJSONObject;
  Client: TFPHTTPClient;
begin
  Result := False;
  Token := '';
  ErrorMsg := '';

  if (Trim(IGDB_CLIENT_ID) = '') or (Trim(IGDB_CLIENT_SECRET) = '') then
  begin
    ErrorMsg := 'Keine IGDB Client-ID/Secret eingetragen (siehe IgdbApi.pas).';
    Exit;
  end;

  URL := 'https://id.twitch.tv/oauth2/token?client_id=' + IGDB_CLIENT_ID +
         '&client_secret=' + IGDB_CLIENT_SECRET + '&grant_type=client_credentials';

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; SpieleSammlung/1.0)');
    Client.AllowRedirect := True;
    try
      ResponseText := Client.Post(URL);
    except
      on E: Exception do
      begin
        ErrorMsg := 'Netzwerkfehler beim Twitch-Login: ' + E.Message;
        Exit;
      end;
    end;
  finally
    Client.Free;
  end;

  Data := nil;
  try
    try
      Data := GetJSON(ResponseText);
    except
      on E: Exception do
      begin
        ErrorMsg := 'Twitch-Antwort konnte nicht gelesen werden: ' + E.Message;
        Exit;
      end;
    end;
    if Data.JSONType <> jtObject then
    begin
      ErrorMsg := 'Unerwartetes Antwortformat vom Twitch-Login.';
      Exit;
    end;
    Obj := TJSONObject(Data);
    if Obj.Find('access_token') = nil then
    begin
      ErrorMsg := 'Kein access_token erhalten (Client-ID/Secret in IgdbApi.pas pruefen).';
      Exit;
    end;
    Token := Obj.Get('access_token', '');
    Result := Token <> '';
  finally
    Data.Free;
  end;
end;

function IgdbFetchCoverURL(const GameName: String; out CoverURL: String;
  out ErrorMsg: String): Boolean;
var
  Token, Body, ResponseText, EscapedName, ImageId: String;
  Data: TJSONData;
  Arr: TJSONArray;
  GameObj: TJSONObject;
  CoverField: TJSONData;
  CoverObj: TJSONObject;
  ImageIdField: TJSONData;
  i: Integer;
begin
  Result := False;
  CoverURL := '';
  ErrorMsg := '';

  if not IgdbGetAppToken(Token, ErrorMsg) then
    Exit;

  { Anfuehrungszeichen im Namen fuer die Apicalypse-Abfrage escapen }
  EscapedName := '';
  for i := 1 to Length(GameName) do
  begin
    if GameName[i] = '"' then
      EscapedName := EscapedName + '\"'
    else
      EscapedName := EscapedName + GameName[i];
  end;

  Body := 'search "' + EscapedName + '"; fields name,cover.image_id; limit 1;';

  if not HttpPostText('https://api.igdb.com/v4/games', Body,
       IGDB_CLIENT_ID, Token, ResponseText, ErrorMsg) then
  begin
    ErrorMsg := 'Netzwerkfehler bei der IGDB-Suche: ' + ErrorMsg;
    Exit;
  end;

  Data := nil;
  try
    try
      Data := GetJSON(ResponseText);
    except
      on E: Exception do
      begin
        ErrorMsg := 'IGDB-Antwort konnte nicht gelesen werden: ' + E.Message;
        Exit;
      end;
    end;

    if Data.JSONType <> jtArray then
    begin
      ErrorMsg := 'Unerwartetes Antwortformat von IGDB (Client-ID/Token pruefen).';
      Exit;
    end;
    Arr := TJSONArray(Data);

    if Arr.Count = 0 then
    begin
      ErrorMsg := 'Kein Treffer bei IGDB für "' + GameName + '".';
      Exit;
    end;

    GameObj := TJSONObject(Arr.Items[0]);
    CoverField := GameObj.Find('cover');
    if (CoverField = nil) or (CoverField.JSONType <> jtObject) then
    begin
      ErrorMsg := 'Für diesen Treffer ist bei IGDB kein Cover hinterlegt.';
      Exit;
    end;
    CoverObj := TJSONObject(CoverField);

    ImageIdField := CoverObj.Find('image_id');
    if (ImageIdField = nil) or (ImageIdField.JSONType <> jtString) then
    begin
      ErrorMsg := 'Cover ohne Bild-ID erhalten.';
      Exit;
    end;
    ImageId := ImageIdField.AsString;

    { t_cover_big = ca. 264x374px. Andere Groessen: t_cover_small,
      t_1080p, t_original - siehe https://api-docs.igdb.com/#images }
    CoverURL := 'https://images.igdb.com/igdb/image/upload/t_cover_big/' +
                ImageId + '.jpg';
    Result := True;
  finally
    Data.Free;
  end;
end;

end.
