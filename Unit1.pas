unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Grids, LCLIntf, lazjpg, lazpng, Theme3, Math,
  BGRABitmap, BGRABitmapTypes, base64, Process, Buttons;

const
  { Geometrie der Regal-Ansicht. Bei Bedarf einfach diese Werte anpassen. }
  ShelfBoxW = 90;
  ShelfBoxH = 128;
  ShelfGapX = 18;
  ShelfRowH = 170;
  ShelfPadTop = 26;
  ShelfPadLeft = 24;
  { Regal wird in dieser Aufloesung gezeichnet und dann sauber
    heruntergerechnet (Supersampling) - das ergibt weiche statt
    treppig-harte Kanten an den schraeg gestellten Boxen. 2 = doppelte
    Aufloesung, guter Kompromiss zwischen Optik und Tempo. }
  ShelfSuperSample = 2;

type
  TGame = record
    Name: String;
    Sprache: String;
    Medium: String;
    Zustand: String;
    Inhalt: String;
    Vollstaendig: String;
    Publisher: String;
    Jahr: String;
    Entwickler: String;
    Plattform: String;
    Genre: String;
    ExePath: String; // Pfad zur Programmdatei, um das Spiel direkt zu starten
    UseDosBox: String; // 'Ja'/'Nein' - ueber DOSBox statt direkt starten
    DosBoxConfig: String; // Freitext mit DOSBox-Konfigurationszeilen fuer dieses Spiel (Klartext im Speicher)
    UseScummVM: String; // 'Ja'/'Nein' - ueber ScummVM statt direkt/DOSBox starten
    ScummVMPath: String; // Ordner mit den Spieldateien (kein Dateiname - ScummVM erkennt das Spiel selbst)
    CoverBase64: String; // Bilddaten Base64-kodiert (statt Dateipfad)
    CoverExt: String;    // z.B. '.jpg' - noetig, um die Daten beim Anzeigen richtig zu interpretieren
    Wert: String;
  end;

  { TForm1 }
  TForm1 = class(TForm)
    btnStartGame: TBitBtn;
    pnlToolbar: TPanel;
    btnNeu: TBitBtn;
    btnBearbeiten: TBitBtn;
    btnLoeschen: TBitBtn;
    btnRegal: TButton;
    lblGesamtwert: TLabel;
    lblSpieleAnzahl: TLabel;
    StringGrid1: TStringGrid;
    pnlGridContainer: TPanel;
    pbShelf: TPaintBox;
    cmbShelfSort: TComboBox;
    PanelRechts: TPanel;
    ImageCover: TImage;
    lblWikipedia: TLabel;
    lblMobyGames: TLabel;
    lblName: TLabel;
    lblInfo: TLabel;
    lblPlat: TLabel;
    lblMedium: TLabel;
    pnlBadgeMedium: TPanel;
    lblBadgeMedium: TLabel;
    pnlBadgeZustand: TPanel;
    lblBadgeZustand: TLabel;
    pnlWertBox: TPanel;
    lblWertCaption: TLabel;
    lblWertNum: TLabel;
    pnlSearchbar: TPanel;
    edtSuche: TEdit;
    btnSuche: TButton;
    sbGrid: TScrollBar;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure RepositionToolbarControls;
    procedure StringGrid1SelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure StringGrid1DblClick(Sender: TObject);
    procedure StringGrid1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure StringGrid1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure StringGrid1MouseLeave(Sender: TObject);
    procedure MarqueeTimerTimer(Sender: TObject);
    function CellTextOverflows(ACol, ARow: Integer; out Overflow: Integer): Boolean;
    procedure btnRegalClick(Sender: TObject);
    procedure btnStartGameClick(Sender: TObject);
    procedure ApplyShelfMode;
    procedure pbShelfPaint(Sender: TObject);
    procedure pbShelfMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbShelfMouseLeave(Sender: TObject);
    procedure pbShelfMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbShelfDblClick(Sender: TObject);
    procedure pbShelfMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function ShelfIndexAtPoint(X, Y: Integer): Integer;
    procedure DrawShelfBox(Bmp: TBGRABitmap; BX, BY: Integer;
      const G: TGame; TiltPx: Integer; Hover: Boolean; Scale: Integer);
    procedure DrawShelfBoxOnLayer(Layer: TBGRABitmap; BX, BY: Integer;
      const G: TGame; TiltPx: Integer);
    procedure RebuildShelfFullLayer;
    procedure RebuildShelfSortedRows;
    function CompareForShelfSort(A, B: Integer): Integer;
    procedure cmbShelfSortChange(Sender: TObject);
    procedure StringGrid1MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure sbGridChange(Sender: TObject);
    procedure btnSucheClick(Sender: TObject);
    procedure edtSucheChange(Sender: TObject);
    procedure btnNeuClick(Sender: TObject);
    procedure btnBearbeitenClick(Sender: TObject);
    procedure btnLoeschenClick(Sender: TObject);
    procedure lblWikipediaClick(Sender: TObject);
    procedure lblMobyGamesClick(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: Integer;
      aRect: TRect; aState: TGridDrawState);
  private
    Games: array of TGame;
    FilteredRows: array of Integer;
    CSVPath: String;
    CurrentGameIndex: Integer;
    HoverRow, HoverCol: Integer;
    MarqueeOffset: Integer;
    MarqueeTick: Integer;
    MarqueeTimer: TTimer;
    ShelfMode: Boolean;
    HoverShelfIndex: Integer;
    ShelfCoverCache: TStringList; // Name=Cache-Schluessel, Objects[i]=TBGRABitmap
    ShelfFullLayer: TBGRABitmap;  // KOMPLETTES Regal (alle Zeilen), fertig geglaettet
    ShelfBaseDirty: Boolean;      // True = muss vor dem naechsten Zeichnen neu gebaut werden
    ShelfSortMode: Integer;       // Index in cmbShelfSort
    ShelfSortedRows: array of Integer; // FilteredRows in der gewaehlten Regal-Sortierung
    procedure LoadCSV(const Filename: String);
    procedure SaveCSV;
    procedure ApplyFilter(const SearchText: String);
    procedure ShowGame(Index: Integer);
    procedure RefreshGrid;
    procedure AutoSizeGrid;
    procedure SaveColumnWidths;
    function LoadColumnWidths: Boolean;
    procedure UpdateGesamtwert;
    function FindGameByRow(ARow: Integer): Integer;
    function GameToSearchURL(const BaseURL: String): String;
    procedure GetMediumColors(const Medium: String; out BG, Txt: TColor);
    procedure GetZustandColors(const Zustand: String; out BG, Txt: TColor);
    function BuildGameHint(const G: TGame): String;
    procedure UpdateScrollBar;
    procedure RefreshShelfScrollBarBounds;
    procedure SortGamesByName;
    function FindGridRowForGame(const AName: String): Integer;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses Unit2;

{ TForm1 }

{ Einfache 16x16-Symbole per Code gezeichnet (keine Icon-Dateien
  eingebettet). clFuchsia dient als Maskenfarbe fuer Transparenz - kommt
  in den Symbolen selbst nicht vor, wird also komplett durchsichtig. }

function CreatePlayGlyph: TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(16, 16);
  Result.Canvas.Brush.Color := clFuchsia;
  Result.Canvas.FillRect(0, 0, 16, 16);
  Result.Canvas.Brush.Color := clBlack;
  Result.Canvas.Pen.Color := clBlack;
  Result.Canvas.Polygon([Point(4, 3), Point(4, 13), Point(13, 8)]);
  Result.TransparentColor := clFuchsia;
  Result.Transparent := True;
end;

function CreatePlusGlyph: TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(16, 16);
  Result.Canvas.Brush.Color := clFuchsia;
  Result.Canvas.FillRect(0, 0, 16, 16);
  Result.Canvas.Pen.Color := clBlack;
  Result.Canvas.Pen.Width := 2;
  Result.Canvas.MoveTo(8, 3); Result.Canvas.LineTo(8, 13);
  Result.Canvas.MoveTo(3, 8); Result.Canvas.LineTo(13, 8);
  Result.TransparentColor := clFuchsia;
  Result.Transparent := True;
end;

function CreateEditGlyph: TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(16, 16);
  Result.Canvas.Brush.Color := clFuchsia;
  Result.Canvas.FillRect(0, 0, 16, 16);
  { Stift-Schaft }
  Result.Canvas.Pen.Color := clBlack;
  Result.Canvas.Pen.Width := 2;
  Result.Canvas.MoveTo(2, 14);
  Result.Canvas.LineTo(10, 6);
  { Stift-Spitze/Kopf }
  Result.Canvas.Brush.Color := clBlack;
  Result.Canvas.Pen.Width := 1;
  Result.Canvas.Polygon([Point(9, 5), Point(13, 2), Point(13, 6)]);
  Result.TransparentColor := clFuchsia;
  Result.Transparent := True;
end;

function CreateDeleteGlyph: TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(16, 16);
  Result.Canvas.Brush.Color := clFuchsia;
  Result.Canvas.FillRect(0, 0, 16, 16);
  Result.Canvas.Pen.Color := clBlack;
  Result.Canvas.Brush.Style := bsClear;
  Result.Canvas.Pen.Width := 2;
  { Muelleimer-Koerper }
  Result.Canvas.Rectangle(4, 6, 12, 14);
  { Deckel }
  Result.Canvas.MoveTo(2, 6); Result.Canvas.LineTo(14, 6);
  { Griff }
  Result.Canvas.MoveTo(6, 6); Result.Canvas.LineTo(6, 4);
  Result.Canvas.LineTo(10, 4); Result.Canvas.LineTo(10, 6);
  Result.Canvas.Brush.Style := bsSolid;
  Result.TransparentColor := clFuchsia;
  Result.Transparent := True;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  TempGlyph: TBitmap;
begin
  CurrentGameIndex := -1;

  CSVPath := ExtractFilePath(Application.ExeName) + 'spiele.csv';
  if not FileExists(CSVPath) then
    CSVPath := 'C:\Users\chris\Documents\Default Project\spiele.csv';

  LoadCSV(CSVPath);

  StringGrid1.DefaultDrawing := False;
  StringGrid1.GridLineWidth := 0;
  StringGrid1.RowHeights[0] := 34;
  StringGrid1.DefaultRowHeight := 30;
  StringGrid1.Color := clWhite;
  StringGrid1.FixedColor := clWhite;
  StringGrid1.FixedRows := 1;
  StringGrid1.ColCount := 8;
  StringGrid1.Options := StringGrid1.Options + [goRowSelect, goThumbTracking, goColSizing];

  StringGrid1.Cells[0, 0] := 'Nr.';
  StringGrid1.Cells[1, 0] := 'Name';
  StringGrid1.Cells[2, 0] := 'Jahr';
  StringGrid1.Cells[3, 0] := 'Publisher / Entwickler';
  StringGrid1.Cells[4, 0] := 'Inhalt';
  StringGrid1.Cells[5, 0] := 'Zustand';
  StringGrid1.Cells[6, 0] := 'Medium';
  StringGrid1.Cells[7, 0] := 'Wert';

  ApplyFilter('');
  if not LoadColumnWidths then
    AutoSizeGrid;
  UpdateGesamtwert;

  edtSuche.TextHint := 'Suche nach Name, Publisher, Jahr...';
  edtSuche.Height := 26;
  OnResize := @FormResize;

  { Theme setup }
  Self.Color := clAppBg;
  Self.Font.Name := FontBody;
  Self.Font.Size := 9;

  pnlToolbar.Color := clSidebar;
  pnlToolbar.Font.Color := clWhite;
  pnlToolbar.Font.Name := FontBody;
  pnlToolbar.Font.Size := 9;
  btnNeu.Font.Color := clWhite;
  btnNeu.Font.Name := FontBody;
  btnNeu.Font.Size := 9;
  btnBearbeiten.Font.Color := clWhite;
  btnBearbeiten.Font.Name := FontBody;
  btnBearbeiten.Font.Size := 9;
  btnLoeschen.Font.Color := clWhite;
  btnLoeschen.Font.Name := FontBody;
  btnLoeschen.Font.Size := 9;
  lblGesamtwert.Font.Color := clAccent;
  lblGesamtwert.Font.Name := FontDisplay;
  lblGesamtwert.Font.Size := 10;
  lblGesamtwert.Font.Style := [fsBold];

  lblSpieleAnzahl.Font.Color := clWhite;
  lblSpieleAnzahl.Font.Name := FontBody;
  lblSpieleAnzahl.Font.Size := 10;

  PanelRechts.Color := clDetailBg;
  PanelRechts.Font.Name := FontBody;

  lblName.Font.Name := FontDisplay;
  lblName.Font.Size := 12;
  lblName.Font.Style := [fsBold];
  lblName.Font.Color := clBlack;
  lblInfo.Font.Name := FontBody;
  lblInfo.Font.Size := 9;
  lblInfo.Font.Color := clTextMuted;
  lblPlat.Font.Name := FontBody;
  lblPlat.Font.Size := 8;
  lblPlat.Font.Color := clTextMuted;
  lblMedium.Font.Name := FontBody;
  lblMedium.Font.Size := 8;
  lblMedium.Font.Color := clTextMuted;
  lblWikipedia.Font.Color := clAccent;
  lblWikipedia.Font.Name := FontBody;
  lblWikipedia.Font.Size := 8;
  lblWikipedia.Font.Style := [fsUnderline];
  lblMobyGames.Font.Color := clAccent;
  lblMobyGames.Font.Name := FontBody;
  lblMobyGames.Font.Size := 8;
  lblMobyGames.Font.Style := [fsUnderline];

  StringGrid1.Font.Name := FontBody;
  StringGrid1.Font.Size := 9;
  StringGrid1.Font.Color := clBlack;
  StringGrid1.OnDrawCell := @StringGrid1DrawCell;

  { Lauftext-Effekt fuer zu lange Zellinhalte beim Hovern }
  HoverRow := -1;
  HoverCol := -1;
  MarqueeOffset := 0;
  MarqueeTick := 0;

  MarqueeTimer := TTimer.Create(Self);
  MarqueeTimer.Interval := 40;
  MarqueeTimer.Enabled := False;
  MarqueeTimer.OnTimer := @MarqueeTimerTimer;

  StringGrid1.OnMouseMove := @StringGrid1MouseMove;
  StringGrid1.OnMouseLeave := @StringGrid1MouseLeave;

  ShelfMode := True; // Regal-Ansicht ist jetzt der Standard beim Programmstart
  ShelfSortMode := 0;

  cmbShelfSort.Items.Add('Name A-Z');
  cmbShelfSort.Items.Add('Publisher');
  cmbShelfSort.Items.Add('Entwickler');
  cmbShelfSort.Items.Add('Genre');
  cmbShelfSort.Items.Add('Wert (niedrig -> hoch)');
  cmbShelfSort.Items.Add('Wert (hoch -> niedrig)');
  cmbShelfSort.Items.Add('Jahr');
  cmbShelfSort.ItemIndex := 0;
  cmbShelfSort.Font.Name := FontBody;
  cmbShelfSort.Font.Size := 9;
  HoverShelfIndex := -1;
  ShelfFullLayer := nil;
  ShelfBaseDirty := True;
  ShelfCoverCache := TStringList.Create;
  ShelfCoverCache.Sorted := True;
  ShelfCoverCache.Duplicates := dupIgnore;

  { Bitmap-Symbole fuer die vier Buttons - Create...Glyph erzeugt jeweils
    eine neue Bitmap, .Glyph.Assign() kopiert die Pixel hinein, danach
    wird die temporaere Bitmap wieder freigegeben. NumGlyphs wird explizit
    auf 1 gesetzt - TBitBtn interpretiert eine Glyph-Bitmap sonst
    standardmaessig als mehrere nebeneinanderliegende Zustands-Bilder
    (Normal/Disabled/...) und wuerde unser einzelnes Icon in Scheiben
    zerschneiden, was zu verzerrter Darstellung fuehrt. }
  TempGlyph := CreatePlusGlyph;
  try
    btnNeu.Glyph.Assign(TempGlyph);
    btnNeu.NumGlyphs := 1;
    btnNeu.Kind := bkCustom;
  finally
    TempGlyph.Free;
  end;

  TempGlyph := CreateEditGlyph;
  try
    btnBearbeiten.Glyph.Assign(TempGlyph);
    btnBearbeiten.NumGlyphs := 1;
    btnBearbeiten.Kind := bkCustom;
  finally
    TempGlyph.Free;
  end;

  TempGlyph := CreateDeleteGlyph;
  try
    btnLoeschen.Glyph.Assign(TempGlyph);
    btnLoeschen.NumGlyphs := 1;
    btnLoeschen.Kind := bkCustom;
  finally
    TempGlyph.Free;
  end;

  TempGlyph := CreatePlayGlyph;
  try
    btnStartGame.Glyph.Assign(TempGlyph);
    btnStartGame.NumGlyphs := 1;
    btnStartGame.Kind := bkCustom;
  finally
    TempGlyph.Free;
  end;

  { Wichtig: pnlToolbar hat Font.Color := clWhite (fuer die weissen Labels
    dort), das TBitBtn (anders als das vorherige TButton) offenbar per
    ParentFont uebernimmt - weisser Text auf hellem Button-Hintergrund
    waere praktisch unsichtbar/nur als Kanten-Artefakte sichtbar. Deshalb
    hier explizit von der geerbten Panel-Schrift lösen. }
  btnNeu.ParentFont := False;
  btnNeu.Font.Color := clBlack;
  btnBearbeiten.ParentFont := False;
  btnBearbeiten.Font.Color := clBlack;
  btnLoeschen.ParentFont := False;
  btnLoeschen.Font.Color := clBlack;
  btnRegal.ParentFont := False;
  btnRegal.Font.Color := clBlack;

  { Suchleiste }
  pnlSearchbar.Color := clWhite;
  edtSuche.Font.Name := FontBody;
  edtSuche.Font.Size := 9;
  btnSuche.Font.Name := FontBody;
  btnSuche.Font.Size := 9;

  { Badges (Medium / Zustand) — Farben werden pro Spiel in ShowGame gesetzt }
  lblBadgeMedium.Font.Name := FontBody;
  lblBadgeMedium.Font.Size := 8;
  lblBadgeMedium.Font.Style := [fsBold];

  lblBadgeZustand.Font.Name := FontBody;
  lblBadgeZustand.Font.Size := 8;
  lblBadgeZustand.Font.Style := [fsBold];

  { Wertebox }
  pnlWertBox.Color := clSidebarBtn;
  lblWertCaption.Font.Name := FontBody;
  lblWertCaption.Font.Size := 9;
  lblWertCaption.Font.Color := clWhite;
  lblWertNum.Font.Name := FontDisplay;
  lblWertNum.Font.Color := clAccent;

  { Manueller Scrollbalken ersetzt die native Grid-Scrollbar (siehe
    UpdateScrollBar) - Feinabstimmung Farbe/Sichtbarkeit passiert dort. }
  StringGrid1.Invalidate;

  if Length(FilteredRows) > 0 then
    ShowGame(FilteredRows[0]);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  RepositionToolbarControls;

  { VisibleRowCount ist erst zuverlaessig, wenn das Fenster seine
    tatsaechliche Bildschirmgroesse hat - FormCreate laeuft davor.
    ApplyShelfMode kuemmert sich sowohl um UpdateScrollBar als auch (bei
    Regal-Standard) um den einmaligen Vollaufbau des Regals. }
  ApplyShelfMode;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  SaveColumnWidths;
  SetLength(Games, 0);
  SetLength(FilteredRows, 0);

  if ShelfCoverCache <> nil then
  begin
    for i := 0 to ShelfCoverCache.Count - 1 do
      ShelfCoverCache.Objects[i].Free;
    ShelfCoverCache.Free;
  end;

  if ShelfFullLayer <> nil then
    ShelfFullLayer.Free;
end;

{ Liest eine Datei komplett ein und liefert sie Base64-kodiert zurueck.
  Genutzt fuer die einmalige Migration alter, dateipfad-basierter
  Cover-Eintraege beim ersten Laden nach der Umstellung. }
function EncodeFileToBase64(const Path: String): String;
var
  FS: TFileStream;
  SS: TStringStream;
begin
  Result := '';
  try
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
  except
    Result := ''; // Datei nicht lesbar - Migration dieser einen Zeile ueberspringen
  end;
end;

{ Dekodiert Base64-Bilddaten in einen neuen MemoryStream - der Aufrufer ist
  fuers Freigeben verantwortlich. Bei leerem B64 ein leerer (nicht nil-)
  Stream, damit Aufrufer nicht extra auf nil pruefen muessen. }
function DecodeBase64ToStream(const B64: String): TMemoryStream;
var
  Raw: String;
begin
  Result := TMemoryStream.Create;
  if B64 = '' then Exit;
  Raw := DecodeStringBase64(B64);
  if Length(Raw) > 0 then
    Result.WriteBuffer(Raw[1], Length(Raw));
  Result.Position := 0;
end;

procedure TForm1.LoadCSV(const Filename: String);
var
  SL: TStringList;
  i: Integer;
  Parts: TStringArray;
  Count: Integer;
  RawCover: String;
  NeedsMigration: Boolean;
begin
  NeedsMigration := False;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Filename);
    Count := SL.Count - 1;
    if Count < 0 then Exit;
    SetLength(Games, Count);
    for i := 1 to SL.Count - 1 do
    begin
      Parts := SL[i].Split(['|']);
      if Length(Parts) >= 11 then
      begin
        Games[i-1].Name := Parts[0];
        Games[i-1].Sprache := Parts[1];
        Games[i-1].Medium := Parts[2];
        Games[i-1].Zustand := Parts[3];
        Games[i-1].Inhalt := Parts[4];
        Games[i-1].Vollstaendig := Parts[5];
        Games[i-1].Publisher := Parts[6];
        Games[i-1].Jahr := Parts[7];
        Games[i-1].Entwickler := Parts[8];
        Games[i-1].Plattform := Parts[9];

        RawCover := Parts[10];

        if Length(Parts) >= 13 then
        begin
          { Aktuelles Format: CoverBase64 + CoverExt als eigene Spalten. }
          Games[i-1].CoverBase64 := RawCover;
          Games[i-1].CoverExt := Parts[11];
          Games[i-1].Wert := Parts[12];
        end
        else
        begin
          { Altes Format (vor der Base64-Umstellung): Spalte 10 war ein
            Dateipfad, Spalte 11 (falls vorhanden) war der Wert. Automatisch
            einmalig migrieren - die Bilddatei einlesen und einbetten,
            danach am Ende der Funktion neu speichern. }
          if Length(Parts) >= 12 then
            Games[i-1].Wert := Parts[11]
          else
            Games[i-1].Wert := '';

          if (RawCover <> '') and FileExists(RawCover) then
          begin
            Games[i-1].CoverBase64 := EncodeFileToBase64(RawCover);
            Games[i-1].CoverExt := LowerCase(ExtractFileExt(RawCover));
            NeedsMigration := True;
          end
          else
          begin
            Games[i-1].CoverBase64 := '';
            Games[i-1].CoverExt := '';
          end;
        end;

        { Genre wurde nachtraeglich angehaengt (Spalte 14) - bei aelteren
          Zeilen (egal ob altes oder neues Cover-Format) einfach leer. }
        if Length(Parts) >= 14 then
          Games[i-1].Genre := Parts[13]
        else
          Games[i-1].Genre := '';

        { ExePath (Spalte 15) - noch neuer als Genre, ebenfalls optional. }
        if Length(Parts) >= 15 then
          Games[i-1].ExePath := Parts[14]
        else
          Games[i-1].ExePath := '';

        { UseDosBox (Spalte 16) - noch neuer als ExePath, ebenfalls optional. }
        if Length(Parts) >= 16 then
          Games[i-1].UseDosBox := Parts[15]
        else
          Games[i-1].UseDosBox := '';

        { DosBoxConfig (Spalte 17) - Base64-kodiert gespeichert, weil das
          Feld echte Zeilenumbrueche enthalten kann/soll (mehrzeiliger
          Konfigurationstext) - unser zeilenbasiertes CSV-Format wuerde
          bei rohen Zeilenumbruechen sonst kaputtgehen. }
        if Length(Parts) >= 17 then
          Games[i-1].DosBoxConfig := DecodeStringBase64(Parts[16])
        else
          Games[i-1].DosBoxConfig := '';

        { UseScummVM/ScummVMPath (Spalten 18/19) - noch neuer, ebenfalls
          optional. ScummVMPath ist ein Ordnerpfad, der theoretisch ein
          '|' enthalten koennte, was das Format sprengen wuerde - dafuer
          waere aber ein Pipe-Zeichen im Verzeichnisnamen noetig, was unter
          Windows ohnehin ungueltig ist, daher unproblematisch. }
        if Length(Parts) >= 18 then
          Games[i-1].UseScummVM := Parts[17]
        else
          Games[i-1].UseScummVM := '';

        if Length(Parts) >= 19 then
          Games[i-1].ScummVMPath := Parts[18]
        else
          Games[i-1].ScummVMPath := '';
      end;
    end;
  finally
    SL.Free;
  end;
  SetLength(FilteredRows, Length(Games));
  for i := 0 to Length(Games) - 1 do
    FilteredRows[i] := i;

  if NeedsMigration then
    SaveCSV; // Migration dauerhaft machen, damit sie nur einmal laeuft
end;

procedure TForm1.SaveCSV;
var
  SL: TStringList;
  i: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Add('Name|Sprache|Medium|Zustand|Inhalt|Vollständig|Publisher|Jahr|Entwickler|Plattform|CoverBase64|CoverExt|Wert|Genre|ExePath|UseDosBox|DosBoxConfig|UseScummVM|ScummVMPath');
    for i := 0 to Length(Games) - 1 do
    begin
      SL.Add(Games[i].Name + '|' +
             Games[i].Sprache + '|' +
             Games[i].Medium + '|' +
             Games[i].Zustand + '|' +
             Games[i].Inhalt + '|' +
             Games[i].Vollstaendig + '|' +
             Games[i].Publisher + '|' +
             Games[i].Jahr + '|' +
             Games[i].Entwickler + '|' +
             Games[i].Plattform + '|' +
             Games[i].CoverBase64 + '|' +
             Games[i].CoverExt + '|' +
             Games[i].Wert + '|' +
             Games[i].Genre + '|' +
             Games[i].ExePath + '|' +
             Games[i].UseDosBox + '|' +
             EncodeStringBase64(Games[i].DosBoxConfig) + '|' +
             Games[i].UseScummVM + '|' +
             Games[i].ScummVMPath);
    end;
    SL.SaveToFile(CSVPath);
  finally
    SL.Free;
  end;
end;

procedure TForm1.RefreshGrid;
begin
  ApplyFilter(edtSuche.Text);
  UpdateGesamtwert;
end;

procedure TForm1.UpdateGesamtwert;
var
  i: Integer;
  Summe: Double;
  Val: Double;
begin
  Summe := 0;
  for i := 0 to Length(Games) - 1 do
  begin
    if TryStrToFloat(StringReplace(Games[i].Wert, ',', '.', [rfReplaceAll]), Val) then
      Summe := Summe + Val;
  end;
  lblGesamtwert.Caption := 'Gesamtwert: ' + FormatFloat('0.00', Summe) + ' €';
  lblSpieleAnzahl.Caption := IntToStr(Length(Games)) + ' Spiele';
end;

procedure TForm1.AutoSizeGrid;
var
  W, Avail: Integer;
begin
  Avail := StringGrid1.Width - 2;
  if Avail < 100 then Exit;

  StringGrid1.ColWidths[0] := 50;
  StringGrid1.ColWidths[2] := 50;
  StringGrid1.ColWidths[6] := 70;
  StringGrid1.ColWidths[7] := 80;
  Avail := Avail - 50 - 50 - 70 - 80;
  StringGrid1.ColWidths[1] := Round(Avail * 0.35);
  StringGrid1.ColWidths[3] := Round(Avail * 0.25);
  StringGrid1.ColWidths[4] := Round(Avail * 0.20);
  W := Avail - StringGrid1.ColWidths[1] - StringGrid1.ColWidths[3] - StringGrid1.ColWidths[4];
  StringGrid1.ColWidths[5] := W;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  RepositionToolbarControls;

  { Loest bei Fenstergroessenaenderung (z.B. Maximieren) ein Neuzeichnen
    aus. pbShelfPaint erkennt dabei selbststaendig, dass sich die Breite
    geaendert hat, baut das Regal neu auf und synchronisiert dabei ueber
    RefreshShelfScrollBarBounds auch gleich den Scrollbalken - vorher
    passierte bei reiner Groessenaenderung gar nichts, wodurch der
    Scrollbalken auf einem veralteten Stand haengen blieb. }
  if ShelfMode then
    pbShelf.Invalidate;
end;

procedure TForm1.RepositionToolbarControls;
begin
  { Diese vier Elemente von Hand statt per Align positionieren - Align hat
    sich hier bei mehreren Versuchen unerwartet/inkonsistent verhalten
    (Reihenfolge vertauscht, falsche Randabstaende). Direkte Pixel-
    Berechnung ist zwar weniger elegant, dafuer aber garantiert
    vorhersehbar. 20px rechter Rand passend zum Cover-Bild in
    PanelRechts (das ist dort 20px vom rechten Rand entfernt platziert). }
  btnRegal.Left := pnlToolbar.ClientWidth - btnRegal.Width - 20;

  cmbShelfSort.Left := pnlSearchbar.ClientWidth - cmbShelfSort.Width - 20;
  btnSuche.Left := cmbShelfSort.Left - btnSuche.Width - 14;
  edtSuche.Width := btnSuche.Left - edtSuche.Left - 8;
end;



procedure TForm1.SaveColumnWidths;
var
  SL: TStringList;
  i: Integer;
  CfgPath: String;
begin
  CfgPath := ExtractFilePath(CSVPath) + 'column_widths.cfg';
  SL := TStringList.Create;
  try
    for i := 0 to StringGrid1.ColCount - 1 do
      SL.Add(IntToStr(StringGrid1.ColWidths[i]));
    SL.SaveToFile(CfgPath);
  finally
    SL.Free;
  end;
end;

function TForm1.LoadColumnWidths: Boolean;
var
  SL: TStringList;
  i: Integer;
  CfgPath: String;
begin
  Result := False;
  CfgPath := ExtractFilePath(CSVPath) + 'column_widths.cfg';
  if not FileExists(CfgPath) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(CfgPath);
    if SL.Count >= StringGrid1.ColCount then
    begin
      for i := 0 to StringGrid1.ColCount - 1 do
        StringGrid1.ColWidths[i] := StrToIntDef(SL[i], StringGrid1.ColWidths[i]);
      Result := True;
    end;
  finally
    SL.Free;
  end;
end;

procedure TForm1.ApplyFilter(const SearchText: String);
var
  i, Row, Count: Integer;
  Search: String;
begin
  Search := LowerCase(Trim(SearchText));
  Count := 0;
  SetLength(FilteredRows, Length(Games));

  for i := 0 to Length(Games) - 1 do
  begin
    if (Search = '') or
       (Pos(Search, LowerCase(Games[i].Name)) > 0) or
       (Pos(Search, LowerCase(Games[i].Publisher)) > 0) or
       (Pos(Search, LowerCase(Games[i].Jahr)) > 0) or
       (Pos(Search, LowerCase(Games[i].Plattform)) > 0) or
       (Pos(Search, LowerCase(Games[i].Entwickler)) > 0) or
       (Pos(Search, LowerCase(Games[i].Medium)) > 0) then
    begin
      FilteredRows[Count] := i;
      Inc(Count);
    end;
  end;

  SetLength(FilteredRows, Count);
  StringGrid1.RowCount := Count + 1;

  for Row := 0 to Count - 1 do
  begin
    i := FilteredRows[Row];
    StringGrid1.Cells[0, Row + 1] := IntToStr(Row + 1);
    StringGrid1.Cells[1, Row + 1] := Games[i].Name;
    StringGrid1.Cells[2, Row + 1] := Games[i].Jahr;
    StringGrid1.Cells[3, Row + 1] := Games[i].Publisher;
    if Games[i].Entwickler <> '' then
    begin
      if Games[i].Publisher <> '' then
        StringGrid1.Cells[3, Row + 1] := StringGrid1.Cells[3, Row + 1] + ' / ';
      StringGrid1.Cells[3, Row + 1] := StringGrid1.Cells[3, Row + 1] + Games[i].Entwickler;
    end;
    StringGrid1.Cells[4, Row + 1] := Games[i].Inhalt;
    StringGrid1.Cells[5, Row + 1] := Games[i].Zustand;
    StringGrid1.Cells[6, Row + 1] := Games[i].Medium;
    if Games[i].Wert <> '' then
      StringGrid1.Cells[7, Row + 1] := Games[i].Wert + ' €'
    else
      StringGrid1.Cells[7, Row + 1] := '';
  end;

  StringGrid1.Col := 0;
  if Count > 0 then
    StringGrid1.Row := 1;

  UpdateScrollBar;
end;

procedure TForm1.RefreshShelfScrollBarBounds;
var
  ItemsPerRow, ShelfTotalRows, ShelfVisibleRows: Integer;
begin
  { Berechnet NUR sbGrid.Min/Max/PageSize/Visible neu, OHNE (anders als
    UpdateScrollBar) ShelfBaseDirty zu setzen oder einen Neuaufbau
    auszuloesen. Wird direkt am Ende von RebuildShelfFullLayer aufgerufen -
    dadurch ist garantiert, dass sich der Scrollbalken exakt auf dieselbe
    Breite bezieht, die gerade tatsaechlich zum Zeichnen benutzt wurde.
    Vorher wurde sbGrid nur bei Suche/Hinzufuegen/Bearbeiten/Umschalten
    aktualisiert, aber NIE bei reiner Fenstergroessenaenderung - der
    Balken blieb dadurch nach einem Maximieren/Verkleinern auf einem
    veralteten Stand haengen, obwohl das Regal selbst (dank eigener
    Breiten-Pruefung in pbShelfPaint) weiterhin korrekt aussah. }
  ItemsPerRow := Max(1, (pbShelf.Width - ShelfPadLeft) div (ShelfBoxW + ShelfGapX));
  ShelfTotalRows := (Length(FilteredRows) + ItemsPerRow - 1) div ItemsPerRow;
  ShelfVisibleRows := Max(1, (pbShelf.Height - ShelfPadTop) div ShelfRowH);

  sbGrid.Min := 0;
  sbGrid.Max := Max(0, ShelfTotalRows - ShelfVisibleRows);
  sbGrid.PageSize := ShelfVisibleRows;
  sbGrid.Visible := ShelfTotalRows > ShelfVisibleRows;
  if sbGrid.Position > sbGrid.Max then
    sbGrid.Position := sbGrid.Max;
end;

procedure TForm1.UpdateScrollBar;
var
  VisibleRows, ItemsPerRow, ShelfTotalRows, ShelfVisibleRows: Integer;
begin
  if ShelfMode then
  begin
    { Regal-Modus: sbGrid steuert hier "Regalzeilen" statt Grid-Zeilen. }
    ItemsPerRow := Max(1, (pbShelf.Width - ShelfPadLeft) div (ShelfBoxW + ShelfGapX));
    ShelfTotalRows := (Length(FilteredRows) + ItemsPerRow - 1) div ItemsPerRow;
    ShelfVisibleRows := Max(1, (pbShelf.Height - ShelfPadTop) div ShelfRowH);

    sbGrid.Min := 0;
    { Max so begrenzt, dass an der tiefsten Position noch eine volle
      Bildschirmseite mit Inhalt gefuellt ist - vorher war Max einfach
      "letzte Zeile", wodurch man mit dem Mausrad ueber die vorgerechnete
      Regal-Ebene hinausscrollen konnte (das weisse Leere darunter). }
    sbGrid.Max := Max(0, ShelfTotalRows - ShelfVisibleRows);
    sbGrid.PageSize := ShelfVisibleRows;
    sbGrid.Visible := ShelfTotalRows > ShelfVisibleRows;
    if sbGrid.Position > sbGrid.Max then
      sbGrid.Position := sbGrid.Max;
    ShelfBaseDirty := True;
    pbShelf.Invalidate;
    Exit;
  end;

  { Haelt den manuellen sbGrid-Scrollbalken im Einklang mit dem Grid-Inhalt.
    Wird nach jeder Aenderung der Zeilenanzahl (Suche/Filter, Laden, etc.)
    aufgerufen. }
  VisibleRows := StringGrid1.VisibleRowCount;
  if VisibleRows < 1 then VisibleRows := 1;

  sbGrid.Min := StringGrid1.FixedRows;
  if StringGrid1.RowCount - 1 >= sbGrid.Min then
    sbGrid.Max := StringGrid1.RowCount - 1
  else
    sbGrid.Max := sbGrid.Min;
  sbGrid.PageSize := VisibleRows;

  { Scrollbar nur einblenden, wenn tatsaechlich mehr Zeilen da sind als
    sichtbar passen - sonst wirkt ein permanent sichtbarer, aber toter
    Balken irritierend. }
  sbGrid.Visible := (StringGrid1.RowCount - StringGrid1.FixedRows) > VisibleRows;

  if sbGrid.Position <> StringGrid1.TopRow then
    sbGrid.Position := StringGrid1.TopRow;
end;

procedure TForm1.SortGamesByName;
var
  i, j: Integer;
  Temp: TGame;
begin
  { Einfache Insertion-Sort - bei ~200-300 Spielen voellig ausreichend
    schnell, und stabil (gleiche Namen behalten ihre relative Reihenfolge).
    AnsiCompareText nutzt die System-Locale fuer sinnvolle
    Gross-/Kleinschreibung und Umlaut-Einordnung. }
  for i := 1 to Length(Games) - 1 do
  begin
    Temp := Games[i];
    j := i - 1;
    while (j >= 0) and (AnsiCompareText(Games[j].Name, Temp.Name) > 0) do
    begin
      Games[j + 1] := Games[j];
      Dec(j);
    end;
    Games[j + 1] := Temp;
  end;
end;

function TForm1.FindGridRowForGame(const AName: String): Integer;
var
  i, GameIdx: Integer;
begin
  Result := -1;
  GameIdx := -1;
  for i := 0 to Length(Games) - 1 do
    if Games[i].Name = AName then
    begin
      GameIdx := i;
      Break;
    end;
  if GameIdx = -1 then Exit;

  for i := 0 to Length(FilteredRows) - 1 do
    if FilteredRows[i] = GameIdx then
    begin
      Result := i + 1; // Grid-Zeilen sind 1-basiert (Zeile 0 = Kopfzeile)
      Exit;
    end;
end;

function TForm1.FindGameByRow(ARow: Integer): Integer;
begin
  Result := -1;
  if (ARow < 1) or (ARow > Length(FilteredRows)) then
    Exit;
  Result := FilteredRows[ARow - 1];
end;

procedure TForm1.GetMediumColors(const Medium: String; out BG, Txt: TColor);
var
  M: String;
begin
  M := LowerCase(Medium);
  if (Pos('5,25', M) > 0) or (Pos('3,5', M) > 0) or (Pos('disk', M) > 0) then
  begin
    BG := clMediumDisketteBg;
    Txt := clMediumDisketteText;
  end
  else if Pos('dvd', M) > 0 then
  begin
    BG := clMediumDvdBg;
    Txt := clMediumDvdText;
  end
  else if Pos('cd', M) > 0 then
  begin
    BG := clRowSelBg;   // vorhandenes Amber-Theme wiederverwendet
    Txt := clAccent;
  end
  else
  begin
    BG := clRowEven;
    Txt := clTextMuted;
  end;
end;

procedure TForm1.GetZustandColors(const Zustand: String; out BG, Txt: TColor);
var
  Z: String;
begin
  Z := Trim(Zustand);
  if (Z = 'Neu (eingeschweißt)') or (Z = 'Neu') then
  begin
    BG := clZustandNeuBg;
    Txt := clZustandNeuText;
  end
  else if Z = 'Neuwertig' then
  begin
    BG := clZustandNeuwertigBg;
    Txt := clZustandNeuwertigText;
  end
  else if Z = 'Sehr Gut' then
  begin
    BG := clZustandSehrGutBg;
    Txt := clZustandSehrGutText;
  end
  else if Z = 'Gut' then
  begin
    BG := clZustandGutBg;
    Txt := clZustandGutText;
  end
  else if Z = 'Akzeptabel' then
  begin
    BG := clZustandAkzBg;
    Txt := clZustandAkzText;
  end
  else
  begin
    BG := clRowEven;
    Txt := clTextMuted;
  end;
end;

procedure TForm1.ShowGame(Index: Integer);
var
  CoverStream: TMemoryStream;
  CoverExt: String;
  BgC, TxtC: TColor;
begin
  if (Index < 0) or (Index >= Length(Games)) then Exit;
  CurrentGameIndex := Index;

  lblName.Caption := Games[Index].Name;
  lblInfo.Caption := 'Von ' + Games[Index].Entwickler +
                     ' | ' + Games[Index].Jahr +
                     ' | ' + Games[Index].Publisher;
  lblPlat.Caption := 'Plattform: ' + Games[Index].Plattform;

  btnStartGame.Enabled := (Trim(Games[Index].ExePath) <> '') and
    FileExists(Games[Index].ExePath);

  { Medium/Zustand als farblich unterschiedene Badges }
  if Games[Index].Medium <> '' then
  begin
    lblBadgeMedium.Caption := Games[Index].Medium;
    GetMediumColors(Games[Index].Medium, BgC, TxtC);
    pnlBadgeMedium.Color := BgC;
    lblBadgeMedium.Font.Color := TxtC;
    pnlBadgeMedium.Width := lblBadgeMedium.Canvas.TextWidth(lblBadgeMedium.Caption) + 24;
    lblBadgeMedium.Width := pnlBadgeMedium.Width - 16;
    pnlBadgeMedium.Visible := True;
  end
  else
    pnlBadgeMedium.Visible := False;

  if Games[Index].Zustand <> '' then
  begin
    lblBadgeZustand.Caption := Games[Index].Zustand;
    GetZustandColors(Games[Index].Zustand, BgC, TxtC);
    pnlBadgeZustand.Color := BgC;
    lblBadgeZustand.Font.Color := TxtC;
    pnlBadgeZustand.Width := lblBadgeZustand.Canvas.TextWidth(lblBadgeZustand.Caption) + 24;
    lblBadgeZustand.Width := pnlBadgeZustand.Width - 16;
    pnlBadgeZustand.Left := (ImageCover.Left + ImageCover.Width) - pnlBadgeZustand.Width;
    pnlBadgeZustand.Visible := True;
  end
  else
    pnlBadgeZustand.Visible := False;

  { Wertebox }
  if Games[Index].Wert <> '' then
  begin
    lblWertNum.Caption := Games[Index].Wert + ' €';
    pnlWertBox.Visible := True;
  end
  else
    pnlWertBox.Visible := False;

  if Games[Index].Name <> '' then
  begin
    lblWikipedia.Caption := 'Wikipedia: ' + Games[Index].Name;
    lblMobyGames.Caption := 'MobyGames: ' + Games[Index].Name;
    lblWikipedia.Visible := True;
    lblMobyGames.Visible := True;
  end
  else
  begin
    lblWikipedia.Visible := False;
    lblMobyGames.Visible := False;
  end;

  ImageCover.Picture.Clear;
  ImageCover.Width := 220;
  ImageCover.Height := 280;
  ImageCover.Left := 20;

  if Games[Index].CoverBase64 <> '' then
  begin
    CoverStream := DecodeBase64ToStream(Games[Index].CoverBase64);
    try
      CoverExt := Games[Index].CoverExt;
      if CoverExt = '' then CoverExt := '.jpg';
      try
        ImageCover.Picture.LoadFromStreamWithFileExt(CoverStream, CoverExt);
      except
        on E: Exception do
          lblName.Caption := lblName.Caption + ' [Bildfehler!]';
      end;
    finally
      CoverStream.Free;
    end;
  end;
end;

function TForm1.GameToSearchURL(const BaseURL: String): String;
var
  GameName: String;
begin
  if CurrentGameIndex < 0 then
  begin
    Result := '';
    Exit;
  end;
  GameName := Games[CurrentGameIndex].Name;
  GameName := StringReplace(GameName, ' ', '+', [rfReplaceAll]);
  GameName := StringReplace(GameName, '&', '%26', [rfReplaceAll]);
  Result := BaseURL + GameName;
end;

procedure TForm1.StringGrid1SelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
var
  GameIdx: Integer;
begin
  GameIdx := FindGameByRow(ARow);
  if GameIdx >= 0 then
    ShowGame(GameIdx);
  if (not ShelfMode) and (sbGrid.Position <> StringGrid1.TopRow) then
    sbGrid.Position := StringGrid1.TopRow;
end;

procedure TForm1.StringGrid1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  { Sichert Spaltenbreiten sofort nach jedem Loslassen der Maus im Grid,
    insbesondere nach dem Ziehen einer Spaltenbreite am Header. Läuft damit
    unabhängig davon, ob das Programm später sauber über OnDestroy beendet
    wird oder abrupt (z.B. IDE-Stop, Absturz) - die Datei ist dann schon
    aktuell. Die günstige Textdatei-Operation stört bei normalen Klicks
    nicht spürbar. }
  SaveColumnWidths;
end;

function TForm1.CellTextOverflows(ACol, ARow: Integer; out Overflow: Integer): Boolean;
var
  TxtWidth, AvailWidth: Integer;
begin
  Result := False;
  Overflow := 0;
  if (ARow < 1) or (ARow >= StringGrid1.RowCount) then Exit;
  if (ACol < 0) or (ACol >= StringGrid1.ColCount) then Exit;

  StringGrid1.Canvas.Font.Name := FontBody;
  StringGrid1.Canvas.Font.Size := 9;
  StringGrid1.Canvas.Font.Style := [];
  TxtWidth := StringGrid1.Canvas.TextWidth(StringGrid1.Cells[ACol, ARow]);
  AvailWidth := StringGrid1.ColWidths[ACol] - 16; // gleiche Innenabstaende wie beim Zeichnen
  Overflow := TxtWidth - AvailWidth;
  Result := Overflow > 0;
end;

procedure TForm1.StringGrid1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  ACol, ARow, Dummy: Integer;
begin
  StringGrid1.MouseToCell(X, Y, ACol, ARow);
  if (ACol = HoverCol) and (ARow = HoverRow) then Exit;

  HoverCol := ACol;
  HoverRow := ARow;
  MarqueeOffset := 0;
  MarqueeTick := 0;
  MarqueeTimer.Enabled := CellTextOverflows(ACol, ARow, Dummy);
  StringGrid1.Invalidate;
end;

procedure TForm1.StringGrid1MouseLeave(Sender: TObject);
begin
  if (HoverRow = -1) and (HoverCol = -1) then Exit;
  HoverRow := -1;
  HoverCol := -1;
  MarqueeOffset := 0;
  MarqueeTick := 0;
  MarqueeTimer.Enabled := False;
  StringGrid1.Invalidate;
end;

procedure TForm1.MarqueeTimerTimer(Sender: TObject);
const
  ScrollStep = 3;
  StartPauseTicks = 8;  // kurze Pause, bevor der Text zu laufen beginnt
  EndPauseTicks = 15;   // Pause, wenn das Textende sichtbar ist
var
  MaxOffset, ScrollTicks, CycleLen: Integer;
begin
  if not CellTextOverflows(HoverCol, HoverRow, MaxOffset) then
  begin
    MarqueeTimer.Enabled := False;
    Exit;
  end;

  ScrollTicks := (MaxOffset + ScrollStep - 1) div ScrollStep;
  CycleLen := StartPauseTicks + ScrollTicks + EndPauseTicks;

  Inc(MarqueeTick);
  if MarqueeTick >= CycleLen then
    MarqueeTick := 0;

  if MarqueeTick < StartPauseTicks then
    MarqueeOffset := 0
  else if MarqueeTick < StartPauseTicks + ScrollTicks then
    MarqueeOffset := Min(MaxOffset, (MarqueeTick - StartPauseTicks) * ScrollStep)
  else
    MarqueeOffset := MaxOffset;

  StringGrid1.Invalidate;
end;

procedure TForm1.StringGrid1MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
const
  LinesPerNotch = 3;
var
  NewTop: Integer;
begin
  { Uebernimmt das Mausrad-Scrollen komplett selbst (statt der LCL-eigenen
    Grid-Verarbeitung zu vertrauen), damit sbGrid garantiert synchron bleibt. }
  if WheelDelta > 0 then
    NewTop := StringGrid1.TopRow - LinesPerNotch
  else
    NewTop := StringGrid1.TopRow + LinesPerNotch;

  if NewTop < StringGrid1.FixedRows then NewTop := StringGrid1.FixedRows;
  if NewTop > sbGrid.Max then NewTop := sbGrid.Max;

  StringGrid1.TopRow := NewTop;
  sbGrid.Position := NewTop;
  Handled := True;
end;

procedure TForm1.sbGridChange(Sender: TObject);
begin
  if ShelfMode then
    pbShelf.Invalidate // reines Verschieben, kein Neuaufbau noetig (siehe pbShelfPaint)
  else
    StringGrid1.TopRow := sbGrid.Position;
end;

procedure TForm1.StringGrid1DblClick(Sender: TObject);
begin
  btnBearbeitenClick(Sender);
end;

procedure TForm1.btnSucheClick(Sender: TObject);
begin
  ApplyFilter(edtSuche.Text);
  if Length(FilteredRows) > 0 then
    ShowGame(FilteredRows[0]);
end;

procedure TForm1.edtSucheChange(Sender: TObject);
begin
  ApplyFilter(edtSuche.Text);
  if Length(FilteredRows) > 0 then
    ShowGame(FilteredRows[0]);
end;

procedure TForm1.btnNeuClick(Sender: TObject);
var
  N, S, M, Z, I, V, P, J, E, Pl, C, CE, W, G, EX, UD, DC, SV, SVP: String;
  Row: Integer;
begin
  N := ''; S := ''; M := ''; Z := ''; I := '';
  V := ''; P := ''; J := ''; E := ''; Pl := ''; C := ''; CE := ''; W := ''; G := ''; EX := ''; UD := ''; DC := ''; SV := ''; SVP := '';

  if ShowEditGame(N, S, M, Z, I, V, P, J, E, Pl, C, CE, W, G, EX, UD, DC, SV, SVP, 'Neues Spiel hinzufügen') then
  begin
    SetLength(Games, Length(Games) + 1);
    Games[Length(Games) - 1].Name := N;
    Games[Length(Games) - 1].Sprache := S;
    Games[Length(Games) - 1].Medium := M;
    Games[Length(Games) - 1].Zustand := Z;
    Games[Length(Games) - 1].Inhalt := I;
    Games[Length(Games) - 1].Vollstaendig := V;
    Games[Length(Games) - 1].Publisher := P;
    Games[Length(Games) - 1].Jahr := J;
    Games[Length(Games) - 1].Entwickler := E;
    Games[Length(Games) - 1].Plattform := Pl;
    Games[Length(Games) - 1].CoverBase64 := C;
    Games[Length(Games) - 1].CoverExt := CE;
    Games[Length(Games) - 1].Wert := W;
    Games[Length(Games) - 1].Genre := G;
    Games[Length(Games) - 1].ExePath := EX;
    Games[Length(Games) - 1].UseDosBox := UD;
    Games[Length(Games) - 1].DosBoxConfig := DC;
    Games[Length(Games) - 1].UseScummVM := SV;
    Games[Length(Games) - 1].ScummVMPath := SVP;
    SortGamesByName;
    SaveCSV;
    RefreshGrid;
    Row := FindGridRowForGame(N);
    if Row > 0 then
      StringGrid1.Row := Row;
  end;
end;

procedure TForm1.btnBearbeitenClick(Sender: TObject);
var
  Idx, Row: Integer;
  N, S, M, Z, I, V, P, J, E, Pl, C, CE, W, G, EX, UD, DC, SV, SVP: String;
begin
  Idx := CurrentGameIndex;
  if (Idx < 0) or (Idx >= Length(Games)) then
  begin
    ShowMessage('Bitte zuerst ein Spiel auswählen.');
    Exit;
  end;

  N := Games[Idx].Name;
  S := Games[Idx].Sprache;
  M := Games[Idx].Medium;
  Z := Games[Idx].Zustand;
  I := Games[Idx].Inhalt;
  V := Games[Idx].Vollstaendig;
  P := Games[Idx].Publisher;
  J := Games[Idx].Jahr;
  E := Games[Idx].Entwickler;
  Pl := Games[Idx].Plattform;
  C := Games[Idx].CoverBase64;
  CE := Games[Idx].CoverExt;
  W := Games[Idx].Wert;
  G := Games[Idx].Genre;
  EX := Games[Idx].ExePath;
  UD := Games[Idx].UseDosBox;
  DC := Games[Idx].DosBoxConfig;
  SV := Games[Idx].UseScummVM;
  SVP := Games[Idx].ScummVMPath;

  if ShowEditGame(N, S, M, Z, I, V, P, J, E, Pl, C, CE, W, G, EX, UD, DC, SV, SVP, 'Spiel bearbeiten: ' + Games[Idx].Name) then
  begin
    Games[Idx].Name := N;
    Games[Idx].Sprache := S;
    Games[Idx].Medium := M;
    Games[Idx].Zustand := Z;
    Games[Idx].Inhalt := I;
    Games[Idx].Vollstaendig := V;
    Games[Idx].Publisher := P;
    Games[Idx].Jahr := J;
    Games[Idx].Entwickler := E;
    Games[Idx].Plattform := Pl;
    Games[Idx].CoverBase64 := C;
    Games[Idx].CoverExt := CE;
    Games[Idx].Wert := W;
    Games[Idx].Genre := G;
    Games[Idx].ExePath := EX;
    Games[Idx].UseDosBox := UD;
    Games[Idx].DosBoxConfig := DC;
    Games[Idx].UseScummVM := SV;
    Games[Idx].ScummVMPath := SVP;
    SortGamesByName;
    SaveCSV;
    RefreshGrid;
    Row := FindGridRowForGame(N);
    if Row > 0 then
      StringGrid1.Row := Row
    else if Length(FilteredRows) > 0 then
      ShowGame(FilteredRows[0]);
  end;
end;

procedure TForm1.btnStartGameClick(Sender: TObject);
var
  Proc: TProcess;
  ExePath, DosBoxPath, ScummVMExePath, ScummVMFolder, ConfPath: String;
  ConfStream: TStringStream;
  UseDosBox, UseScummVM: Boolean;
begin
  if (CurrentGameIndex < 0) or (CurrentGameIndex >= Length(Games)) then
  begin
    ShowMessage('Bitte zuerst ein Spiel auswählen.');
    Exit;
  end;

  UseDosBox := SameText(Trim(Games[CurrentGameIndex].UseDosBox), 'Ja');
  UseScummVM := SameText(Trim(Games[CurrentGameIndex].UseScummVM), 'Ja');

  { Je nach Startmethode wird ein unterschiedlicher Pfad gebraucht - ScummVM
    braucht einen ORDNER (keine EXE), DOSBox und der direkte Start brauchen
    die Programmdatei. Deshalb getrennte Pruefung statt einer gemeinsamen
    Pfad-Kontrolle am Anfang. }
  if UseScummVM then
  begin
    ScummVMFolder := Trim(Games[CurrentGameIndex].ScummVMPath);
    if ScummVMFolder = '' then
    begin
      ShowMessage('Für dieses Spiel ist noch kein Spiele-Ordner für ScummVM hinterlegt.' +
        LineEnding + 'Im Bearbeiten-Dialog unter "ScummVM-Einstellungen..." den Ordner auswählen.');
      Exit;
    end;
    if not DirectoryExists(ScummVMFolder) then
    begin
      ShowMessage('Der hinterlegte ScummVM-Ordner wurde nicht gefunden:' + LineEnding + ScummVMFolder);
      Exit;
    end;
  end
  else
  begin
    ExePath := Trim(Games[CurrentGameIndex].ExePath);
    if ExePath = '' then
    begin
      ShowMessage('Für dieses Spiel ist noch kein Programmpfad hinterlegt.' + LineEnding +
        'Im Bearbeiten-Dialog unter "Programm (EXE)" die Datei auswählen.');
      Exit;
    end;
    if not FileExists(ExePath) then
    begin
      ShowMessage('Die hinterlegte Programmdatei wurde nicht gefunden:' + LineEnding + ExePath);
      Exit;
    end;
  end;

  { Weder DOSBox noch ScummVM werden mitgeliefert (ich kann kein fertiges
    Windows-Programm in den Quelltext einbetten) - beide werden in einem
    eigenen Unterordner neben der EXE erwartet:
      DOSBox:  https://www.dosbox.com/download.php   -> Ordner "DOSBox"
      ScummVM: https://www.scummvm.org/downloads/     -> Ordner "ScummVM"
    Jeweils die portable/ZIP-Version reicht, kein Installer noetig -
    einfach den entpackten Ordner hierher kopieren und entsprechend
    benennen. }
  DosBoxPath := ExtractFilePath(Application.ExeName) + 'DOSBox' + PathDelim + 'DOSBox.exe';
  ScummVMExePath := ExtractFilePath(Application.ExeName) + 'ScummVM' + PathDelim + 'scummvm.exe';

  if UseDosBox and not FileExists(DosBoxPath) then
  begin
    ShowMessage('DOSBox wurde nicht gefunden unter:' + LineEnding + DosBoxPath +
      LineEnding + LineEnding +
      'Bitte DOSBox (portable Version) herunterladen von' + LineEnding +
      'https://www.dosbox.com/download.php' + LineEnding +
      'und den entpackten Ordner nach "DOSBox" neben SpieleSammlung.exe legen.');
    Exit;
  end;

  if UseScummVM and not FileExists(ScummVMExePath) then
  begin
    ShowMessage('ScummVM wurde nicht gefunden unter:' + LineEnding + ScummVMExePath +
      LineEnding + LineEnding +
      'Bitte ScummVM (portable/Zip-Version) herunterladen von' + LineEnding +
      'https://www.scummvm.org/downloads/' + LineEnding +
      'und den entpackten Ordner nach "ScummVM" neben SpieleSammlung.exe legen.');
    Exit;
  end;

  Proc := TProcess.Create(nil);
  try
    if UseScummVM then
    begin
      { -p <Ordner> --auto-detect: ScummVM durchsucht den angegebenen
        Ordner selbst und erkennt Spiel/Engine automatisch - es muss dafuer
        nicht vorher im ScummVM-eigenen Launcher angelegt werden. }
      Proc.Executable := ScummVMExePath;
      Proc.Parameters.Add('-p');
      Proc.Parameters.Add(ScummVMFolder);
      Proc.Parameters.Add('--auto-detect');
      Proc.CurrentDirectory := ExtractFilePath(ScummVMExePath);
    end
    else if UseDosBox then
    begin
      Proc.Executable := DosBoxPath;

      { Individuelle DOSBox-Einstellungen fuer dieses Spiel (falls
        hinterlegt) landen kurz vor dem Start in einer temporaeren .conf-
        Datei und werden ueber -conf mitgegeben - DOSBox uebernimmt die
        dort angegebenen Werte zusaetzlich zu seinen Standardeinstellungen
        (z.B. Cycles, Speicher, Soundkarte, MOUNT-Befehle...). -conf muss
        vor dem eigentlichen Spielpfad stehen, sonst wertet DOSBox es
        nicht als Konfigurationsdatei, sondern als Kommandozeile im
        DOS-Fenster. }
      if Trim(Games[CurrentGameIndex].DosBoxConfig) <> '' then
      begin
        ConfPath := GetTempDir + 'spielesammlung_dosbox_' +
          IntToStr(CurrentGameIndex) + '.conf';
        try
          ConfStream := TStringStream.Create(Games[CurrentGameIndex].DosBoxConfig);
          try
            ConfStream.SaveToFile(ConfPath);
            Proc.Parameters.Add('-conf');
            Proc.Parameters.Add(ConfPath);
          finally
            ConfStream.Free;
          end;
        except
          on E: Exception do
            ShowMessage('DOSBox-Konfiguration konnte nicht geschrieben werden, ' +
              'Spiel wird mit DOSBox-Standardeinstellungen gestartet: ' + E.Message);
        end;
      end;

      { DOSBox mit dem Spielpfad direkt starten und mit -exit automatisch
        schliessen, sobald das Spiel beendet wird, statt am DOS-Prompt
        haengen zu bleiben. Ueber die Parameters-Liste statt eines
        selbst zusammengebauten Strings, damit Leerzeichen im Pfad
        automatisch korrekt behandelt werden. }
      Proc.Parameters.Add(ExePath);
      Proc.Parameters.Add('-exit');
      Proc.CurrentDirectory := ExtractFilePath(DosBoxPath);
    end
    else
    begin
      Proc.Executable := ExePath;
      { Arbeitsverzeichnis auf den Spiele-Ordner setzen - viele (besonders
        aeltere) Spiele suchen ihre Ressourcendateien relativ zu ihrem
        eigenen Ordner und starten sonst nicht richtig. }
      Proc.CurrentDirectory := ExtractFilePath(ExePath);
    end;
    Proc.Options := [poDetached]; // nicht auf das Spiel warten, unser Programm bleibt bedienbar
    try
      Proc.Execute;
    except
      on E: Exception do
      begin
        if (not UseDosBox) and (not UseScummVM) and (Pos('216', E.Message) > 0) then
          ShowMessage('Spiel konnte nicht gestartet werden (Windows-Fehler 216).' +
            LineEnding + LineEnding +
            'Das deutet fast immer darauf hin, dass es sich um eine alte 16-Bit-' +
            'DOS-EXE handelt - die kann Windows 11 (64-Bit) grundsätzlich nicht ' +
            'direkt ausführen, unabhängig davon, wie das Programm eingestellt ist.' +
            LineEnding + LineEnding +
            'Lösung: Im Bearbeiten-Dialog auf "DOSBox-Einstellungen..." klicken, ' +
            'den Haken bei "Über DOSBox starten" setzen und mit "Übernehmen" ' +
            'bestätigen (nicht vergessen, danach auch den Hauptdialog mit ' +
            '"Speichern" zu bestätigen).')
        else
          ShowMessage('Spiel konnte nicht gestartet werden: ' + E.Message);
      end;
    end;
  finally
    Proc.Free;
  end;
end;

procedure TForm1.btnLoeschenClick(Sender: TObject);
var
  Idx, i: Integer;
  NewGames: array of TGame;
begin
  Idx := CurrentGameIndex;
  if (Idx < 0) or (Idx >= Length(Games)) then
  begin
    ShowMessage('Bitte zuerst ein Spiel auswählen.');
    Exit;
  end;

  if MessageDlg('Spiel löschen?',
     'Wirklich "' + Games[Idx].Name + '" löschen?',
     mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;

  SetLength(NewGames, Length(Games) - 1);
  for i := 0 to Length(Games) - 1 do
  begin
    if i < Idx then
      NewGames[i] := Games[i]
    else
      NewGames[i - 1] := Games[i];
  end;
  Games := NewGames;
  CurrentGameIndex := -1;
  SaveCSV;
  RefreshGrid;
  ImageCover.Picture.Clear;
  lblName.Caption := '';
  lblInfo.Caption := '';
  lblPlat.Caption := '';
  lblMedium.Caption := '';
  lblWikipedia.Visible := False;
  lblMobyGames.Visible := False;
  pnlBadgeMedium.Visible := False;
  pnlBadgeZustand.Visible := False;
  pnlWertBox.Visible := False;
end;

procedure TForm1.lblWikipediaClick(Sender: TObject);
var
  URL: String;
begin
  URL := GameToSearchURL('https://de.wikipedia.org/w/index.php?search=');
  if URL <> '' then
    OpenURL(URL);
end;

procedure TForm1.lblMobyGamesClick(Sender: TObject);
var
  URL: String;
begin
  URL := GameToSearchURL('https://www.mobygames.com/search/?q=');
  if URL <> '' then
    OpenURL(URL);
end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: Integer;
  aRect: TRect; aState: TGridDrawState);
var
  g: TStringGrid;
  isSel, isHeader, isEven: Boolean;
  txt: String;
begin
  g := StringGrid1;
  isHeader := aRow = 0;
  isSel := gdSelected in aState;
  isEven := (aRow mod 2 = 0);

  if isHeader then
    g.Canvas.Brush.Color := $00E8E6E0
  else if isSel then
    g.Canvas.Brush.Color := $00C8EEFC
  else if isEven then
    g.Canvas.Brush.Color := $00E6EDF0
  else
    g.Canvas.Brush.Color := clWhite;
  g.Canvas.FillRect(aRect);

  if isSel and (aCol = 0) then
  begin
    g.Canvas.Brush.Color := $003CB1E8;
    g.Canvas.FillRect(Rect(aRect.Left, aRect.Top, aRect.Left + 3, aRect.Bottom));
  end;

  g.Canvas.Pen.Color := $00C4CCCC;
  g.Canvas.Pen.Width := 1;
  g.Canvas.MoveTo(aRect.Left, aRect.Bottom - 1);
  g.Canvas.LineTo(aRect.Right, aRect.Bottom - 1);

  if aCol > 0 then
  begin
    g.Canvas.MoveTo(aRect.Left, aRect.Top);
    g.Canvas.LineTo(aRect.Left, aRect.Bottom - 1);
  end;

  if isHeader then
  begin
    g.Canvas.Font.Name := FontBody;
    g.Canvas.Font.Size := 8;
    g.Canvas.Font.Color := $008A8A77;
    g.Canvas.Font.Style := [];
  end
  else
  begin
    g.Canvas.Font.Name := FontBody;
    g.Canvas.Font.Size := 9;
    g.Canvas.Font.Color := clBlack;
  end;
  g.Canvas.Brush.Style := bsClear;
  txt := g.Cells[aCol, aRow];
  if (not isHeader) and (aCol = HoverCol) and (aRow = HoverRow) then
    g.Canvas.TextRect(aRect, aRect.Left + 8 - MarqueeOffset,
      aRect.Top + (aRect.Height - g.Canvas.TextHeight(txt)) div 2, txt)
  else
    g.Canvas.TextOut(aRect.Left + 8, aRect.Top + (aRect.Height - g.Canvas.TextHeight(txt)) div 2, txt);
  g.Canvas.Brush.Style := bsSolid;
end;

function RGBHex(const Hex: string): TColor; // '#e8b13c' -> TColor
begin
  Result := RGBToColor(
    StrToInt('$'+Copy(Hex,2,2)),
    StrToInt('$'+Copy(Hex,4,2)),
    StrToInt('$'+Copy(Hex,6,2)));
end;

{ ==================== Regal-Ansicht (Pseudo-3D) ====================
  Proof-of-Concept-Umsetzung: Cover werden per BGRABitmap.PutImageAffine
  leicht schraeg ("lehnend") gezeichnet, aehnlich einem Buchruecken im
  Regal. Erfordert das BGRABitmap-Paket (Online Package Manager). }

procedure TForm1.ApplyShelfMode;
begin
  { Wendet den aktuellen ShelfMode-Zustand auf die Oberflaeche an - sowohl
    fuer den Umschalt-Button als auch fuer den Programmstart nutzbar, damit
    beide Wege exakt dasselbe tun. }
  StringGrid1.Visible := not ShelfMode;
  pbShelf.Visible := ShelfMode;
  cmbShelfSort.Visible := ShelfMode;

  if ShelfMode then
    btnRegal.Caption := 'Listen-Ansicht'
  else
    btnRegal.Caption := 'Regal-Ansicht';

  HoverShelfIndex := -1;
  UpdateScrollBar;

  if ShelfMode then
  begin
    { sbGrid wird auch fuers Listen-Grid verwendet und hatte dort Min=1
      (Zeile 0 ist die Kopfzeile). UpdateScrollBar hat Min gerade eben auf
      0 gesetzt (Regal-Modus) - ERST DANACH darf Position auf 0 gesetzt
      werden, sonst wird die Zuweisung intern verworfen/auf das alte Min
      geklemmt, weil 0 < Min zu dem Zeitpunkt noch ungueltig war. Das war
      die Ursache dafuer, dass das Regal immer in Zeile 2 startete. }
    sbGrid.Position := 0;

    { Einmaliger Vollaufbau des kompletten Regals (alle Zeilen, nicht nur
      die sichtbaren) - dafuer muss danach beim Scrollen gar nicht mehr neu
      gezeichnet werden, nur noch der sichtbare Ausschnitt verschoben. }
    RebuildShelfFullLayer;
    pbShelf.Invalidate;
  end
  else
    StringGrid1.Invalidate;
end;

procedure TForm1.btnRegalClick(Sender: TObject);
begin
  ShelfMode := not ShelfMode;
  ApplyShelfMode;
end;

function TForm1.ShelfIndexAtPoint(X, Y: Integer): Integer;
var
  ItemsPerRow, col, row, gi, localY: Integer;
begin
  Result := -1;
  ItemsPerRow := Max(1, (pbShelf.Width - ShelfPadLeft) div (ShelfBoxW + ShelfGapX));
  if (X < ShelfPadLeft) or (Y < ShelfPadTop) then Exit;

  col := (X - ShelfPadLeft) div (ShelfBoxW + ShelfGapX);
  if (col < 0) or (col >= ItemsPerRow) then Exit;

  row := (Y - ShelfPadTop) div ShelfRowH;
  localY := (Y - ShelfPadTop) - row * ShelfRowH;
  if localY > ShelfBoxH then Exit; // Regalbrett-Bereich zwischen den Boxen, kein Treffer

  gi := (sbGrid.Position + row) * ItemsPerRow + col;
  if (gi < 0) or (gi >= Length(ShelfSortedRows)) then Exit;
  Result := gi;
end;

function TForm1.BuildGameHint(const G: TGame): String;
var
  Lines: TStringList;
begin
  { Baut den mehrzeiligen Tooltip-Text zusammen - leere Felder werden
    ausgelassen, damit nicht z.B. "Genre: " als leere Zeile auftaucht. }
  Lines := TStringList.Create;
  try
    if G.Jahr <> '' then
      Lines.Add(G.Name + ' (' + G.Jahr + ')')
    else
      Lines.Add(G.Name);
    if G.Publisher <> '' then Lines.Add('Publisher: ' + G.Publisher);
    if G.Entwickler <> '' then Lines.Add('Entwickler: ' + G.Entwickler);
    if G.Plattform <> '' then Lines.Add('Plattform: ' + G.Plattform);
    if G.Genre <> '' then Lines.Add('Genre: ' + G.Genre);
    if G.Medium <> '' then Lines.Add('Medium: ' + G.Medium);
    if G.Zustand <> '' then Lines.Add('Zustand: ' + G.Zustand);
    if G.Sprache <> '' then Lines.Add('Sprache: ' + G.Sprache);
    if G.Vollstaendig <> '' then Lines.Add('Vollständig: ' + G.Vollstaendig);
    if G.Inhalt <> '' then Lines.Add('Inhalt: ' + G.Inhalt);
    if G.Wert <> '' then Lines.Add('Wert: ' + G.Wert + ' €');
    Result := Lines.Text;
    { TStringList.Text haengt einen abschliessenden Zeilenumbruch an -
      den entfernen, sonst zeigt der Tooltip eine leere letzte Zeile. }
    Result := TrimRight(Result);
  finally
    Lines.Free;
  end;
end;

procedure TForm1.pbShelfMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  Idx := ShelfIndexAtPoint(X, Y);
  if Idx = HoverShelfIndex then Exit;
  HoverShelfIndex := Idx;

  if (Idx >= 0) and (Idx < Length(ShelfSortedRows)) then
    pbShelf.Hint := BuildGameHint(Games[ShelfSortedRows[Idx]])
  else
    pbShelf.Hint := '';
  { Erzwingt, dass Windows den (ggf. geaenderten) Hint sofort neu bewertet -
    ohne das wuerde beim Wechsel von einer Box zur naechsten (beides
    innerhalb desselben physischen Steuerelements pbShelf) der Tooltip
    nicht automatisch aktualisiert, da die Maus ja nie ein "neues"
    Steuerelement betritt. }
  Application.CancelHint;

  pbShelf.Invalidate;
end;

procedure TForm1.pbShelfMouseLeave(Sender: TObject);
begin
  if HoverShelfIndex = -1 then Exit;
  HoverShelfIndex := -1;
  pbShelf.Hint := '';
  pbShelf.Invalidate;
end;

procedure TForm1.pbShelfMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Idx, GameIdx, Row: Integer;
begin
  Idx := ShelfIndexAtPoint(X, Y);
  if Idx < 0 then Exit;

  GameIdx := ShelfSortedRows[Idx];
  ShowGame(GameIdx);

  { Grid-Zeile im Hintergrund mitziehen, damit beim Zurueckschalten auf die
    Liste die Auswahl konsistent bleibt (StringGrid1SelectCell ueberspringt
    im Regal-Modus den sbGrid-Abgleich, siehe dort). Ueber den Namen statt
    Idx+1 gesucht, weil das Regal jetzt eine eigene Sortierung haben kann,
    die von der (immer alphabetischen) Listenreihenfolge abweicht. }
  Row := FindGridRowForGame(Games[GameIdx].Name);
  if (Row >= 1) and (Row < StringGrid1.RowCount) then
    StringGrid1.Row := Row;
end;

procedure TForm1.pbShelfDblClick(Sender: TObject);
begin
  { Der vorangehende Einzelklick (pbShelfMouseUp) hat das Spiel bereits
    ausgewaehlt (CurrentGameIndex gesetzt) - direkt den Bearbeiten-Dialog
    oeffnen, genau wie beim Doppelklick in der Liste. }
  btnBearbeitenClick(Sender);
end;

procedure TForm1.pbShelfMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  NewPos: Integer;
begin
  if WheelDelta > 0 then
    NewPos := sbGrid.Position - 1
  else
    NewPos := sbGrid.Position + 1;
  if NewPos < sbGrid.Min then NewPos := sbGrid.Min;
  if NewPos > sbGrid.Max then NewPos := sbGrid.Max;
  sbGrid.Position := NewPos;
  pbShelf.Invalidate; // reines Verschieben, kein Neuaufbau noetig
  Handled := True;
end;

procedure TForm1.DrawShelfBox(Bmp: TBGRABitmap; BX, BY: Integer;
  const G: TGame; TiltPx: Integer; Hover: Boolean; Scale: Integer);
const
  { Platzhalter-Farbpaare (RGB), falls kein Cover hinterlegt ist }
  PlaceholderRGB: array[0..5, 0..1, 0..2] of Integer = (
    ((58,110,165),(28,58,94)),
    ((179,69,44),(122,44,28)),
    ((126,174,122),(74,115,70)),
    ((232,177,60),(168,120,20)),
    ((122,79,201),(74,44,130)),
    ((31,122,148),(18,70,90))
  );
var
  Cover: TBGRABitmap;
  W, H, ColorIdx, HashVal, i, CacheIdx: Integer;
  Origin, HAxis, VAxis: TPointF;
  Title, CacheKey: String;
  MS: TMemoryStream;
begin
  { Alles ab hier in "Supersample"-Koordinaten (Scale-fach vergroessert) -
    ShelfIndexAtPoint & Co. rechnen weiterhin in normalen Bildschirm-
    Pixeln, davon bleibt das unberuehrt. }
  BX := BX * Scale;
  BY := BY * Scale;
  TiltPx := TiltPx * Scale;
  W := ShelfBoxW * Scale;
  H := ShelfBoxH * Scale;

  if Hover then
  begin
    W := Round(W * 1.1);
    H := Round(H * 1.1);
    BX := BX - (W - ShelfBoxW * Scale) div 2;
    BY := BY - (H - ShelfBoxH * Scale);
  end;

  { Cache-Schluessel: Spielename (bei eingebettetem Cover) bzw. Name allein
    fuer den Platzhalter. So wird jedes Bild nur EINMAL dekodiert, nicht
    bei jedem Neuzeichnen (das war die Ursache des Ruckelns). }
  if G.CoverBase64 <> '' then
    CacheKey := 'COVER:' + G.Name
  else
    CacheKey := 'PLACEHOLDER:' + G.Name;

  CacheIdx := ShelfCoverCache.IndexOf(CacheKey);
  if CacheIdx >= 0 then
    Cover := TBGRABitmap(ShelfCoverCache.Objects[CacheIdx])
  else
  begin
    Cover := nil;
    if G.CoverBase64 <> '' then
    begin
      try
        MS := DecodeBase64ToStream(G.CoverBase64);
        try
          Cover := TBGRABitmap.Create;
          Cover.LoadFromStream(MS);
        finally
          MS.Free;
        end;
      except
        Cover := nil;
      end;
    end;

    if Cover = nil then
    begin
      HashVal := 0;
      for i := 1 to Length(G.Name) do
        HashVal := HashVal + Ord(G.Name[i]);
      ColorIdx := HashVal mod 6;

      Cover := TBGRABitmap.Create(200, 280);
      Cover.GradientFill(0, 0, 200, 280,
        BGRA(PlaceholderRGB[ColorIdx,0,0], PlaceholderRGB[ColorIdx,0,1], PlaceholderRGB[ColorIdx,0,2]),
        BGRA(PlaceholderRGB[ColorIdx,1,0], PlaceholderRGB[ColorIdx,1,1], PlaceholderRGB[ColorIdx,1,2]),
        gtLinear, PointF(0, 0), PointF(200, 280), dmSet);

      Cover.FontHeight := 20;
      Cover.FontStyle := [fsBold];
      Title := G.Name;
      if Length(Title) > 20 then
        Title := Copy(Title, 1, 18) + '…';
      Cover.TextOut(10, 235, Title, BGRAWhite);
    end;

    ShelfCoverCache.AddObject(CacheKey, Cover);
  end;

  { Zielparallelogramm ueber drei absolute Eckpunkte definiert:
    Origin = wohin die Quell-Ecke (0,0) transformiert wird,
    HAxis  = wohin die Quell-Ecke (Breite,0) transformiert wird,
    VAxis  = wohin die Quell-Ecke (0,Hoehe) transformiert wird.
    Das sind KEINE relativen Vektoren ab Origin, sondern absolute
    Zielkoordinaten - mit relativen Vektoren gab es die extreme
    "Speer"-Verzerrung. TiltPx verschiebt die linke Kante horizontal
    fuer die Schraeglage. }
  Origin := PointF(BX, BY);
  HAxis := PointF(BX + W, BY);
  VAxis := PointF(BX + TiltPx, BY + H);

  Bmp.PutImageAffine(Origin, HAxis, VAxis, Cover, 255, True);
end;

procedure TForm1.DrawShelfBoxOnLayer(Layer: TBGRABitmap; BX, BY: Integer;
  const G: TGame; TiltPx: Integer);
var
  S, PatchW, PatchH, PatchX, PatchY: Integer;
  Patch, Final: TBGRABitmap;
begin
  { Zeichnet NUR eine einzelne (gehoverte) Box supersampled in ein kleines
    Extra-Bitmap und setzt es transparent auf die uebergebene Ebene - viel
    billiger, als die ganze sichtbare Flaeche neu aufzubauen, nur weil sich
    der Hover geaendert hat. Rand von 16px rundherum, damit die Hover-
    Vergroesserung (+10%) und die Schraeglage nicht am Bildrand des Patches
    abgeschnitten werden. }
  S := ShelfSuperSample;
  PatchX := BX - 16;
  PatchY := BY - 16;
  PatchW := ShelfBoxW + 32;
  PatchH := ShelfBoxH + 32;

  Patch := TBGRABitmap.Create(PatchW * S, PatchH * S, BGRAPixelTransparent);
  try
    DrawShelfBox(Patch, BX - PatchX, BY - PatchY, G, TiltPx, True, S);
    Final := TBGRABitmap(Patch.Resample(PatchW, PatchH));
    try
      Layer.PutImage(PatchX, PatchY, Final, dmDrawWithTransparency);
    finally
      Final.Free;
    end;
  finally
    Patch.Free;
  end;
end;

function TForm1.CompareForShelfSort(A, B: Integer): Integer;
var
  ValA, ValB: Double;
  YearA, YearB: Integer;
begin
  { A/B sind Indizes in Games. Bei Gleichstand faellt alles auf Name A-Z
    zurueck, damit z.B. gleiches Genre/Publisher intern trotzdem
    alphabetisch gruppiert ist statt in zufaelliger Reihenfolge. }
  case ShelfSortMode of
    1: begin // Publisher
         Result := AnsiCompareText(Games[A].Publisher, Games[B].Publisher);
         if Result = 0 then Result := AnsiCompareText(Games[A].Name, Games[B].Name);
       end;
    2: begin // Entwickler
         Result := AnsiCompareText(Games[A].Entwickler, Games[B].Entwickler);
         if Result = 0 then Result := AnsiCompareText(Games[A].Name, Games[B].Name);
       end;
    3: begin // Genre
         Result := AnsiCompareText(Games[A].Genre, Games[B].Genre);
         if Result = 0 then Result := AnsiCompareText(Games[A].Name, Games[B].Name);
       end;
    4: begin // Wert niedrig -> hoch
         if not TryStrToFloat(StringReplace(Games[A].Wert, ',', '.', [rfReplaceAll]), ValA) then ValA := 0;
         if not TryStrToFloat(StringReplace(Games[B].Wert, ',', '.', [rfReplaceAll]), ValB) then ValB := 0;
         if ValA < ValB then Result := -1
         else if ValA > ValB then Result := 1
         else Result := AnsiCompareText(Games[A].Name, Games[B].Name);
       end;
    5: begin // Wert hoch -> niedrig
         if not TryStrToFloat(StringReplace(Games[A].Wert, ',', '.', [rfReplaceAll]), ValA) then ValA := 0;
         if not TryStrToFloat(StringReplace(Games[B].Wert, ',', '.', [rfReplaceAll]), ValB) then ValB := 0;
         if ValA > ValB then Result := -1
         else if ValA < ValB then Result := 1
         else Result := AnsiCompareText(Games[A].Name, Games[B].Name);
       end;
    6: begin // Jahr
         if not TryStrToInt(Trim(Games[A].Jahr), YearA) then YearA := 0;
         if not TryStrToInt(Trim(Games[B].Jahr), YearB) then YearB := 0;
         if YearA < YearB then Result := -1
         else if YearA > YearB then Result := 1
         else Result := AnsiCompareText(Games[A].Name, Games[B].Name);
       end;
  else
    Result := AnsiCompareText(Games[A].Name, Games[B].Name); // 0 = Name A-Z (und Fallback)
  end;
end;

procedure TForm1.RebuildShelfSortedRows;
var
  i, j, Temp: Integer;
begin
  { Eigene Sortierreihenfolge nur fuers Regal - beeinflusst NICHT die Liste
    (die bleibt ja immer alphabetisch, siehe SortGamesByName). Einfacher
    Insertion-Sort auf einer Kopie von FilteredRows, bei der Kollektionsgroesse
    (ein paar hundert Spiele) voellig ausreichend schnell. }
  SetLength(ShelfSortedRows, Length(FilteredRows));
  for i := 0 to High(FilteredRows) do
    ShelfSortedRows[i] := FilteredRows[i];

  for i := 1 to High(ShelfSortedRows) do
  begin
    Temp := ShelfSortedRows[i];
    j := i - 1;
    while (j >= 0) and (CompareForShelfSort(ShelfSortedRows[j], Temp) > 0) do
    begin
      ShelfSortedRows[j + 1] := ShelfSortedRows[j];
      Dec(j);
    end;
    ShelfSortedRows[j + 1] := Temp;
  end;
end;

procedure TForm1.cmbShelfSortChange(Sender: TObject);
begin
  ShelfSortMode := cmbShelfSort.ItemIndex;
  ShelfBaseDirty := True;
  sbGrid.Position := 0; // nach Umsortieren wieder von oben anfangen
  pbShelf.Invalidate;
end;

procedure TForm1.RebuildShelfFullLayer;
var
  Bmp: TBGRABitmap;
  ItemsPerRow, TotalRows, FullHeight, row, col, bx, by, tiltPx, gi, plankY, S: Integer;
begin
  { Baut das KOMPLETTE Regal auf einmal (alle Zeilen, nicht nur die gerade
    sichtbaren) und cacht das Ergebnis in ShelfFullLayer. Teuer, aber
    passiert nur bei echten Datenaenderungen (Suche, Hinzufuegen/Bearbeiten/
    Loeschen, Fenstergroesse, Umschalten in die Ansicht) - NICHT beim
    Scrollen. Scrollen ist dadurch nur noch ein Verschieben eines bereits
    fertigen Bildausschnitts (siehe pbShelfPaint), daher kein Aufblitzen
    und keine Wartezeit mehr beim Scrollen selbst. }
  S := ShelfSuperSample;
  RebuildShelfSortedRows;
  if ShelfFullLayer <> nil then
    FreeAndNil(ShelfFullLayer);

  ItemsPerRow := Max(1, (pbShelf.Width - ShelfPadLeft) div (ShelfBoxW + ShelfGapX));
  TotalRows := (Length(ShelfSortedRows) + ItemsPerRow - 1) div ItemsPerRow;
  if TotalRows < 1 then TotalRows := 1;
  { Puffer am Ende = eine volle Zeilenhoehe (statt nur 20px) - so ist
    garantiert genug Bild vorhanden, auch wenn die letzte Bildschirmseite
    durch Ganzzahl-Rundung nicht exakt auf eine Zeilengrenze faellt. Zudem
    nach unten mindestens auf pbShelf.Height aufgefuellt, damit auch bei
    wenigen (z.B. gefilterten) Spielen der komplette sichtbare Bereich
    dunklen Hintergrund hat statt am unteren Rand den weissen PaintBox-
    Standardhintergrund durchscheinen zu lassen. }
  FullHeight := Max(pbShelf.Height, ShelfPadTop + TotalRows * ShelfRowH + ShelfRowH);

  Bmp := TBGRABitmap.Create(pbShelf.Width * S, FullHeight * S, BGRA(13, 15, 18));
  try
    for row := 0 to TotalRows - 1 do
    begin
      by := ShelfPadTop + row * ShelfRowH;

      plankY := by + ShelfBoxH + 10;
      Bmp.GradientFill(
        (ShelfPadLeft - 14) * S, plankY * S,
        pbShelf.Width * S - 10 * S, (plankY + 12) * S,
        BGRA(107, 74, 44), BGRA(74, 48, 24), gtLinear,
        PointF(0, plankY * S), PointF(0, (plankY + 12) * S), dmSet);

      for col := 0 to ItemsPerRow - 1 do
      begin
        gi := row * ItemsPerRow + col;
        if gi >= Length(ShelfSortedRows) then Continue;

        bx := ShelfPadLeft + col * (ShelfBoxW + ShelfGapX);
        tiltPx := Round((col - (ItemsPerRow - 1) / 2) * 3);
        DrawShelfBox(Bmp, bx, by, Games[ShelfSortedRows[gi]], tiltPx, False, S);
      end;
    end;

    ShelfFullLayer := TBGRABitmap(Bmp.Resample(pbShelf.Width, FullHeight));
  finally
    Bmp.Free;
  end;
  ShelfBaseDirty := False;
  RefreshShelfScrollBarBounds;
end;

procedure TForm1.pbShelfPaint(Sender: TObject);
var
  Frame: TBGRABitmap;
  SrcY, ItemsPerRow, row, col, bx, by, tiltPx, gi: Integer;
begin
  if (pbShelf.Width <= 0) or (pbShelf.Height <= 0) then Exit;

  if ShelfBaseDirty or (ShelfFullLayer = nil) or
     (ShelfFullLayer.Width <> pbShelf.Width) then
    RebuildShelfFullLayer;

  SrcY := sbGrid.Position * ShelfRowH;

  if HoverShelfIndex < 0 then
  begin
    { Reines Verschieben: die fertige Gesamt-Ebene wird einfach mit
      negativem Y-Versatz gezeichnet, der Rest wird automatisch vom Canvas
      des PaintBox abgeschnitten. Kein Neuzeichnen, daher praktisch
      verzoegerungsfrei. }
    ShelfFullLayer.Draw(pbShelf.Canvas, 0, -SrcY, True);
    Exit;
  end;

  { Hover aktiv: sichtbaren Ausschnitt der Gesamt-Ebene in ein kleines
    Arbeitsbild kopieren (per Draw mit Y-Versatz, wie oben), dann die
    gehoverte Box zusaetzlich supersampled oben drauf zeichnen. }
  Frame := TBGRABitmap.Create(pbShelf.Width, pbShelf.Height, BGRA(13, 15, 18));
  try
    ShelfFullLayer.Draw(Frame.Canvas, 0, -SrcY, True);
    Frame.InvalidateBitmap; // Canvas-Zeichnen -> BGRA-Puffer synchron halten

    gi := HoverShelfIndex;
    if (gi >= 0) and (gi < Length(ShelfSortedRows)) then
    begin
      ItemsPerRow := Max(1, (pbShelf.Width - ShelfPadLeft) div (ShelfBoxW + ShelfGapX));
      row := gi div ItemsPerRow;
      col := gi mod ItemsPerRow;
      by := ShelfPadTop + row * ShelfRowH - SrcY; // relativ zum sichtbaren Ausschnitt
      bx := ShelfPadLeft + col * (ShelfBoxW + ShelfGapX);
      tiltPx := Round((col - (ItemsPerRow - 1) / 2) * 3);
      DrawShelfBoxOnLayer(Frame, bx, by, Games[ShelfSortedRows[gi]], tiltPx);
    end;

    Frame.Draw(pbShelf.Canvas, 0, 0, True);
  finally
    Frame.Free;
  end;
end;

end.
