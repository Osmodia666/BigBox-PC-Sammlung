unit Theme3;

{$mode objfpc}{$H+}

interface

uses Graphics;

// Hinweis: TColor erwartet intern das Format $00BBGGRR (Blau-Gruen-Rot),
// nicht das aus CSS gewohnte $RRGGBB. Die folgenden Werte sind daher
// bereits byte-vertauscht, damit sie die im Kommentar genannte RGB-Farbe
// tatsaechlich ergeben. Bei neuen Farben: Bytes von "#RRGGBB" umdrehen
// zu "$BBGGRR", oder die RGBHex()-Hilfsfunktion aus Unit1.pas nutzen.
const
  clAppBg        = TColor($F5F5F7);  // #f7f5f5
  clSidebar      = TColor($1D1816);  // #16181d
  clSidebarBtn   = TColor($2C2522);  // #22252c
  clAccent       = TColor($3CB1E8);  // #e8b13c
  clRowEven      = TColor($E6EDF0);  // #f0ede6
  clRowSelBg     = TColor($C8EEFC);  // #fceec8
  clBorder       = TColor($C4CCD0);  // #d0ccc4
  clTextMuted    = TColor($8A8A77);  // #778a8a
  clDetailBg     = TColor($F7FAFB);  // #fbfaf7
  clCoverTop     = TColor($A56E3A);  // #3a6ea5
  clCoverBottom  = TColor($5E3A1C);  // #1c3a5e

  // Datenträger-Badges (Medium)
  clMediumDisketteBg   = TColor($FBECE4);  // #e4ecfb
  clMediumDisketteText = TColor($A95B3A);  // #3a5ba9
  clMediumDvdBg        = TColor($FBE4ED);  // #ede4fb
  clMediumDvdText      = TColor($C94F7A);  // #7a4fc9

  // Zustand-Badges (von neuwertig bis akzeptabel)
  clZustandNeuBg        = TColor($E6F5E1);  // #e1f5e6
  clZustandNeuText       = TColor($467D2E);  // #2e7d46
  clZustandNeuwertigBg   = TColor($F0F3DF);  // #dff3f0
  clZustandNeuwertigText = TColor($74801E);  // #1e8074
  clZustandSehrGutBg     = TColor($F8F3E1);  // #e1f3f8
  clZustandSehrGutText   = TColor($947A1F);  // #1f7a94
  clZustandGutBg         = TColor($D6F3FC);  // #fcf3d6
  clZustandGutText       = TColor($0A89B4);  // #b4890a
  clZustandAkzBg         = TColor($DEE6FB);  // #fbe6de
  clZustandAkzText       = TColor($2A50B5);  // #b5502a

  FontDisplay = 'Segoe UI Semibold';
  FontBody    = 'Segoe UI';

implementation

end.
