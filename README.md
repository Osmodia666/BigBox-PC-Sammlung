# BigBox-PC-Sammlung

Eine Sammlungsverwaltung für alte PC-/Amiga-Spiele in der klassischen "Big Box"-Verpackung – als Windows-Programm und als mobile Web-App, beide auf derselben CSV-Datei arbeitend.

## Bestandteile

| Teil | Was es ist |
|---|---|
| **PC-App** (Quellcode in `source/`) | Lazarus/Free-Pascal-Windows-Programm. Tabellenansicht + optische Regalansicht, Bearbeiten-Dialog, DOSBox-/ScummVM-Start, Online-Abgleich, Nextcloud-Sync, Tauschbörse. Die fertig gebaute `SpieleSammlung.exe` liegt direkt im Repo-Root neben den benötigten DLLs – einfach herunterladen und starten, ohne selbst bauen zu müssen. |
| **Web-App** (`docs/index.html`) | Mobile/Desktop-Begleit-App, gehostet über GitHub Pages. Kamera-Erfassung (Cover fotografieren, Barcode scannen), Nextcloud-/Google-Drive-Sync, Tauschbörse/Wunschliste. Live unter [osmodia666.github.io/BigBox-PC-Sammlung](https://osmodia666.github.io/BigBox-PC-Sammlung/). |
| **Mobile-Mockup** (`mobile-app/BigBoxMobile.html`) | Leichtgewichtige, rein clientseitige Variante ohne Cloud-Anbindung (z. B. als eigenständige Datei nutzbar, keine Internetverbindung nötig). |

Beide Haupt-Apps lesen/schreiben dasselbe pipe-getrennte CSV-Format (siehe unten) und können darüber synchronisiert werden.

## Funktionen

- Sammlung erfassen: Titel, Publisher, Entwickler, Jahr, Medium, Zustand, Genre, Wert, Cover-Bild
- **Regal-Ansicht**: Spiele als schräg gestellte Boxen in einem virtuellen Bücherregal, alphabetisch sortiert, mit Sortieroptionen
- **Online-Abgleich**: automatisches Nachladen von Jahr/Entwickler/Publisher über [RAWG](https://rawg.io/apidocs) und Cover-Bildern über [IGDB](https://api-docs.igdb.com/) (Twitch-App)
- **DOSBox-/ScummVM-Integration** (nur PC-App): Spiel direkt aus der Sammlung heraus starten, inkl. eigener `dosbox.conf`-Einstellungen pro Spiel
- **Cloud-Sync**: WebDAV (Nextcloud, ownCloud, Seafile, pCloud, Koofr, Yandex.Disk, Box, …) in beiden Apps; zusätzlich Google Drive in der Web-App
- **Tauschbörse**: Spiele als "tauschbar" markieren (eigenes Abzeichen auf dem Cover), eigene Tauschliste veröffentlichen und die Listen von Freunden abonnieren – ganz ohne eigenen Server, über einen von dir selbst gehosteten Freigabelink
- **Kamera-Erfassung** (nur Web-App): Cover abfotografieren, Barcode fotografieren und automatisch erkennen lassen
- Eigene RAWG-/IGDB-Zugangsdaten je Gerät hinterlegbar (siehe unten) – nichts ist im Quellcode fest eingetragen

## PC-App: einfach nutzen oder selbst bauen

**Nur nutzen:** `SpieleSammlung.exe` im Repo-Root herunterladen – `libcrypto-4-x64.dll` und `libssl-4-x64.dll` liegen direkt daneben und werden für RAWG/IGDB/Nextcloud-Anfragen (HTTPS) benötigt, also alle drei Dateien zusammen in denselben Ordner legen und starten.

**Selbst bauen** (z. B. um am Code etwas zu ändern): der komplette Quellcode liegt in `source/`.

Voraussetzungen:

- [Lazarus](https://www.lazarus-ide.org/) (getestet mit FPC 3.2.x)
- Online-Paket **BGRABitmapPack** über den Lazarus-Online-Paketmanager installieren (für die Regal-Grafik)

`source/SpieleSammlung.lpi` in Lazarus öffnen, Paketabhängigkeiten auflösen lassen, kompilieren. Das Projekt ist so eingestellt, dass die fertige `SpieleSammlung.exe` automatisch eine Ebene höher landet – also direkt im Repo-Root neben den beiden DLLs.

Beim ersten Start legt das Programm eine leere `spiele.csv` neben der `.exe` an. Über **Einstellungen…** in der Werkzeugleiste lässt sich jederzeit eine vorhandene Datei öffnen oder eine neue an anderer Stelle anlegen (z. B. in einem lokal synchronisierten Nextcloud-Ordner).

## Web-App einrichten

`docs/index.html` ist eine vollständig eigenständige, clientseitige Datei – kein Build-Schritt nötig. Über **GitHub Pages** aus diesem Repo veröffentlicht (Settings → Pages → Branch `main`, Ordner `/docs`), erreichbar unter [osmodia666.github.io/BigBox-PC-Sammlung](https://osmodia666.github.io/BigBox-PC-Sammlung/).

Alle Daten (Sammlung, Zugangsdaten, Freundesliste) liegen ausschließlich lokal im Browser (IndexedDB/localStorage) – es gibt keinen eigenen Server.

## API-Zugangsdaten (RAWG / IGDB)

Für den Online-Abgleich braucht jedes Gerät eigene, kostenlose Zugangsdaten:

1. **RAWG-Key**: auf [rawg.io/apidocs](https://rawg.io/apidocs) registrieren (keine Zahlungsdaten nötig)
2. **IGDB/Twitch**: kostenloses Twitch-Konto, unter [dev.twitch.tv/console/apps](https://dev.twitch.tv/console/apps) eine neue App anlegen (Redirect-URL z. B. `http://localhost`) → liefert Client-ID und Client-Secret

Eintragen:
- **PC-App**: Button "Einstellungen…" in der Werkzeugleiste
- **Web-App**: "Mehr" → "API-Schlüssel"

Die Werte werden ausschließlich lokal gespeichert (PC: `settings.ini` neben der CSV-Datei; Web: `localStorage` im Browser) und nicht synchronisiert.

## Cloud-Sync einrichten

1. In Nextcloud (oder einem anderen WebDAV-Anbieter) ein App-Passwort anlegen
2. In der PC-App unter "Einstellungen…" bzw. in der Web-App unter "Mehr" → "Sync" die WebDAV-Datei-URL, Benutzername und App-Passwort eintragen
3. Falls von einer anderen Domain (z. B. der GitHub-Pages-Adresse) zugegriffen wird, muss der WebDAV-Server CORS-Anfragen von dieser Adresse erlauben (bei Nextcloud z. B. über die App "Custom CORS")

Abrufen und Hochladen laufen bewusst nicht automatisch nacheinander ab – vor dem Übernehmen einer neueren Version wird immer erst nachgefragt.

## Tauschbörse

Spiele lassen sich im Bearbeiten-Dialog als "Tauschbar" markieren (Abzeichen auf dem Cover). Die eigene Tauschliste kann als Datei exportiert oder direkt auf Nextcloud veröffentlicht werden; Freunde tragen den daraus entstehenden öffentlichen Freigabelink ein, um zu sehen, was gerade tauschbar ist. Es gibt dafür keinen eigenen Server – jeder Link zeigt direkt auf die (öffentlich freigegebene) Datei des jeweiligen Freundes.

## CSV-Dateiformat

Pipe-getrennt (`|`), UTF-8, mit Kopfzeile:

```
Name|Sprache|Medium|Zustand|Inhalt|Vollständig|Publisher|Jahr|Entwickler|Plattform|CoverBase64|CoverExt|Wert|Genre|ExePath|UseDosBox|DosBoxConfig|UseScummVM|ScummVMPath|Tauschbar
```

Cover-Bilder werden Base64-kodiert direkt in der Zeile gespeichert (kein separater Bildordner nötig). Beide Apps schreiben/lesen exakt dieses Format, sodass dieselbe Datei problemlos zwischen PC- und Web-App synchronisiert werden kann.

## Unterstützen

Wer mag, kann das Projekt über [paypal.me/ChristopherStein](https://paypal.me/ChristopherStein) unterstützen (Link auch in beiden Apps hinterlegt).
