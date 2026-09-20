program SpieleSammlung;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms, IgdbApi,
  Unit1, Theme3, RawgApi;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='Meine BigBox Spiele';

  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
