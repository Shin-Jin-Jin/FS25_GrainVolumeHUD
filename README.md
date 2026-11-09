# Getreide Volumen HUD (FS25_GrainVolumeHUD)

Farming-Simulator-25-Mod: zeigt Schüttgut im Füllstand-HUD in einer wählbaren
Einheit statt in Litern. Flüssigkeiten bleiben in Litern.

## Einheiten
- **Kubikmeter (m³)** – Liter ÷ 1000
- **Bushel (bu)** – US-Bushel, Liter ÷ 35,239
- **Tonnen (t)** – nach echter Fülltyp-Dichte (Silage wiegt anders als Weizen)
- **Liter (l)** – unverändert

## Einstellen
Direkt im Spiel unter **Einstellungen → Allgemein → „Schüttgut-Einheit"**,
oder in `modSettings/GrainVolumeHUD.xml` (`unit = M3 | BUSHEL | TON | LITER`).
Die Einstellung gilt pro Spieler, auch im Multiplayer.

## Aufbau
- `scripts/GrainVolume.lua` – Klassifizierung (Schüttgut/Flüssigkeit) und Umrechnung
- `scripts/GrainVolumeHUD.lua` – Hook ins Füllstand-HUD
- `scripts/GrainVolumeSettings.lua` – Auswahl im Einstellungsmenü
- `translations/` – DE/EN

## Lizenz / Nutzung
Eigene Mod von Shin_Jin_Jin. Reine Anzeige, kein Eingriff ins Spielgeschehen.
