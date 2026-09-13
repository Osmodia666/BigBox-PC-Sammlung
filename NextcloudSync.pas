unit NextcloudSync;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, openssl, opensslsockets, base64;

{ Laedt die Datei unter URL per WebDAV-GET nach DestPath herunter (per
  HTTP Basic Auth mit User/Pass, falls User nicht leer ist). Liefert False
  bei Fehler; ErrorMsg enthaelt dann eine fuer den Nutzer verstaendliche
  Meldung. Schreibt NICHT direkt in eine evtl. bereits vorhandene wichtige
  Datei - DestPath sollte deshalb ein Temp-Pfad sein, den der Aufrufer bei
  Erfolg selbst an die eigentliche Zielposition verschiebt. }
function NcDownloadFile(const URL, User, Pass, DestPath: String;
  out ErrorMsg: String): Boolean;

{ Laedt die lokale Datei SrcPath per WebDAV-PUT nach URL hoch. }
function NcUploadFile(const URL, User, Pass, SrcPath: String;
  out ErrorMsg: String): Boolean;

implementation

procedure ApplyAuth(Client: TFPHTTPClient; const User, Pass: String);
begin
  if User <> '' then
    Client.AddHeader('Authorization', 'Basic ' + EncodeStringBase64(User + ':' + Pass));
end;

function NcDownloadFile(const URL, User, Pass, DestPath: String;
  out ErrorMsg: String): Boolean;
var
  Client: TFPHTTPClient;
  FS: TFileStream;
begin
  Result := False;
  ErrorMsg := '';
  if Trim(URL) = '' then
  begin
    ErrorMsg := 'Keine WebDAV-Datei-URL eingetragen (siehe "Einstellungen...").';
    Exit;
  end;

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; SpieleSammlung/1.0)');
    ApplyAuth(Client, User, Pass);
    Client.AllowRedirect := True;
    try
      FS := TFileStream.Create(DestPath, fmCreate);
      try
        Client.Get(URL, FS);
        Result := FS.Size > 0;
        if not Result then
          ErrorMsg := 'Leere Antwort vom Server.';
      finally
        FS.Free;
      end;
    except
      on E: Exception do
        ErrorMsg := E.Message;
    end;
  finally
    Client.Free;
  end;
end;

function NcUploadFile(const URL, User, Pass, SrcPath: String;
  out ErrorMsg: String): Boolean;
var
  Client: TFPHTTPClient;
  FS: TFileStream;
begin
  Result := False;
  ErrorMsg := '';
  if Trim(URL) = '' then
  begin
    ErrorMsg := 'Keine WebDAV-Datei-URL eingetragen (siehe "Einstellungen...").';
    Exit;
  end;
  if not FileExists(SrcPath) then
  begin
    ErrorMsg := 'Lokale Datei nicht gefunden: ' + SrcPath;
    Exit;
  end;

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; SpieleSammlung/1.0)');
    ApplyAuth(Client, User, Pass);
    Client.AllowRedirect := True;
    FS := TFileStream.Create(SrcPath, fmOpenRead or fmShareDenyWrite);
    try
      Client.RequestBody := FS;
      try
        Client.Put(URL);
        Result := True;
      except
        on E: Exception do
          ErrorMsg := E.Message;
      end;
    finally
      Client.RequestBody := nil;
      FS.Free;
    end;
  finally
    Client.Free;
  end;
end;

end.
