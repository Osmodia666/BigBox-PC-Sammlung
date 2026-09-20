unit Unit3;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

{ Zeigt den DOSBox-Einstellungsdialog. AUseDosBox/ADosBoxConfig sind
  var-Parameter mit demselben Rohformat, das ohnehin schon pro Spiel
  gespeichert wird (ADosBoxConfig = kompletter dosbox.conf-Text). Der
  Dialog zerlegt diesen Text beim Oeffnen in die haeufigsten Einzelfelder
  und baut ihn beim Speichern wieder zusammen - alles, was er nicht
  erkennt, bleibt unangetastet im freien Zusatzfeld erhalten. }
function ShowDosBoxSettings(var AUseDosBox, ADosBoxConfig: String): Boolean;

implementation

{ Zerlegt einen dosbox.conf-Text in die von diesem Dialog verwalteten
  Einzelwerte. Alles, was keiner der bekannten Zeilen/Abschnitts-
  Ueberschriften entspricht, landet gesammelt in AExtra - so gehen von
  Hand eingetragene Zeilen aus frueheren Versionen nicht verloren. }
procedure ParseDosBoxConfig(const Cfg: String; out ACycles, AMemsize: String;
  out AFullscreen: Boolean; out AExtra: String);
var
  SL: TStringList;
  i: Integer;
  Line, LowLine: String;
  Consumed: Boolean;
begin
  ACycles := '';
  AMemsize := '';
  AFullscreen := False;
  AExtra := '';
  SL := TStringList.Create;
  try
    SL.Text := Cfg;
    for i := 0 to SL.Count - 1 do
    begin
      Line := SL[i];
      LowLine := LowerCase(Trim(Line));
      Consumed := False;

      if Pos('cycles=', LowLine) = 1 then
      begin
        ACycles := Trim(Copy(Line, Pos('=', Line) + 1, Length(Line)));
        Consumed := True;
      end
      else if Pos('memsize=', LowLine) = 1 then
      begin
        AMemsize := Trim(Copy(Line, Pos('=', Line) + 1, Length(Line)));
        Consumed := True;
      end
      else if Pos('fullscreen=', LowLine) = 1 then
      begin
        AFullscreen := Pos('true', LowLine) > 0;
        Consumed := True;
      end
      else if (LowLine = '[cpu]') or (LowLine = '[dosbox]') or (LowLine = '[sdl]') then
        Consumed := True; // Abschnitts-Ueberschriften werden beim Speichern neu erzeugt

      if (not Consumed) and (Trim(Line) <> '') then
      begin
        if AExtra <> '' then AExtra := AExtra + LineEnding;
        AExtra := AExtra + Line;
      end;
    end;
  finally
    SL.Free;
  end;
end;

{ Baut aus den Einzelfeldern wieder einen vollstaendigen dosbox.conf-Text
  zusammen, den -conf so an DOSBox uebergeben werden kann. }
function BuildDosBoxConfig(const ACycles, AMemsize: String;
  AFullscreen: Boolean; const AExtra: String): String;
var
  Res: TStringList;
begin
  Res := TStringList.Create;
  try
    if Trim(ACycles) <> '' then
    begin
      Res.Add('[cpu]');
      Res.Add('cycles=' + Trim(ACycles));
    end;
    if Trim(AMemsize) <> '' then
    begin
      Res.Add('[dosbox]');
      Res.Add('memsize=' + Trim(AMemsize));
    end;
    if AFullscreen then
    begin
      Res.Add('[sdl]');
      Res.Add('fullscreen=true');
    end;
    if Trim(AExtra) <> '' then
      Res.Add(Trim(AExtra));
    Result := Res.Text;
  finally
    Res.Free;
  end;
end;

type
  { TDosBoxSettingsForm }
  TDosBoxSettingsForm = class(TForm)
  end;

function ShowDosBoxSettings(var AUseDosBox, ADosBoxConfig: String): Boolean;
var
  F: TDosBoxSettingsForm;
  TopY: Integer;
  chkUse: TCheckBox;
  edtCycles: TEdit;
  cmbMemsize: TComboBox;
  chkFullscreen: TCheckBox;
  memExtra: TMemo;
  btnOK, btnCancel: TButton;
  Cycles, Memsize, Extra: String;
  Fullscreen: Boolean;

  procedure AddLbl(const ACaption: String; AWidth: Integer = 340);
  var
    L: TLabel;
  begin
    L := TLabel.Create(F);
    L.Parent := F;
    L.SetBounds(20, TopY, AWidth, 20);
    L.Caption := ACaption;
    L.Font.Style := [fsBold];
    TopY += 24;
  end;

begin
  Result := False;
  ParseDosBoxConfig(ADosBoxConfig, Cycles, Memsize, Fullscreen, Extra);

  F := TDosBoxSettingsForm.CreateNew(Application);
  try
    F.Caption := 'DOSBox-Einstellungen';
    F.Width := 420;
    F.Height := 470;
    F.Position := poScreenCenter;
    F.BorderStyle := bsToolWindow;

    TopY := 16;

    chkUse := TCheckBox.Create(F);
    chkUse.Parent := F;
    chkUse.SetBounds(20, TopY, 380, 22);
    chkUse.Caption := 'Über DOSBox starten (für alte DOS-Spiele)';
    chkUse.Checked := SameText(Trim(AUseDosBox), 'Ja');
    TopY += 36;

    AddLbl('CPU-Takt (Cycles):');
    edtCycles := TEdit.Create(F);
    edtCycles.Parent := F;
    edtCycles.SetBounds(20, TopY, 200, 25);
    edtCycles.Text := Cycles;
    edtCycles.TextHint := 'leer = DOSBox-Standard, z.B. 10000 oder auto';
    TopY += 36;

    AddLbl('Speichergröße:');
    cmbMemsize := TComboBox.Create(F);
    cmbMemsize.Parent := F;
    cmbMemsize.SetBounds(20, TopY, 150, 25);
    cmbMemsize.Style := csDropDownList;
    cmbMemsize.Items.Add('(DOSBox-Standard)');
    cmbMemsize.Items.Add('4');
    cmbMemsize.Items.Add('8');
    cmbMemsize.Items.Add('16');
    cmbMemsize.Items.Add('32');
    cmbMemsize.Items.Add('63');
    if Trim(Memsize) = '' then
      cmbMemsize.ItemIndex := 0
    else
    begin
      cmbMemsize.ItemIndex := cmbMemsize.Items.IndexOf(Trim(Memsize));
      if cmbMemsize.ItemIndex < 0 then
      begin
        cmbMemsize.Items.Add(Trim(Memsize));
        cmbMemsize.ItemIndex := cmbMemsize.Items.Count - 1;
      end;
    end;
    TopY += 36;

    chkFullscreen := TCheckBox.Create(F);
    chkFullscreen.Parent := F;
    chkFullscreen.SetBounds(20, TopY, 300, 22);
    chkFullscreen.Caption := 'Im Vollbild starten';
    chkFullscreen.Checked := Fullscreen;
    TopY += 36;

    AddLbl('Weitere DOSBox-Zeilen (optional):', 380);
    memExtra := TMemo.Create(F);
    memExtra.Parent := F;
    memExtra.SetBounds(20, TopY, 380, 130);
    memExtra.ScrollBars := ssVertical;
    memExtra.Text := Extra;
    TopY += 142;

    btnOK := TButton.Create(F);
    btnOK.Parent := F;
    btnOK.SetBounds(140, TopY, 120, 36);
    btnOK.Caption := 'Übernehmen';
    btnOK.ModalResult := mrOK;
    btnOK.Default := True;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(270, TopY, 120, 36);
    btnCancel.Caption := 'Abbrechen';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Cancel := True;

    F.Height := TopY + 90;

    if F.ShowModal = mrOK then
    begin
      if chkUse.Checked then
        AUseDosBox := 'Ja'
      else
        AUseDosBox := 'Nein';

      if cmbMemsize.ItemIndex <= 0 then
        Memsize := ''
      else
        Memsize := cmbMemsize.Items[cmbMemsize.ItemIndex];

      ADosBoxConfig := BuildDosBoxConfig(edtCycles.Text, Memsize,
        chkFullscreen.Checked, memExtra.Text);
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
