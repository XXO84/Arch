Crimson Desert - Absolute Survival v1.0.0
==========================================

Basis
-----
Trinity by XeTrinityz, MIT License.
Pinned source commit:
70c9a00dd6e10b2081d706a837756844c11f5c2b

Permanent aktiv, ohne Hotkey
----------------------------
- God Mode / HP bleibt voll
- kein Kampf-, Fall-, Umwelt- oder sonstiger HP-Schaden am Spieler
- Infinite Stamina / kein Ausdauerverbrauch
- Infinite Spirit / kein Spirit-Ressourcenverbrauch

Absichtlich NICHT enthalten
---------------------------
- keine Inventar-Aenderung
- kein Item-Gain-Hook
- kein Item-Consumption-Hook
- keine Munitions-, Trank- oder Itemmengen-Aenderung
- keine Outgoing-Damage-Aenderung
- kein Teleport
- kein World-/Time-Hack
- kein Inventory Editor
- kein Overlay / kein Mod-Menue

Technik
-------
Die Mod nutzt nur Trinitys aktuellen Player-Resolver, AOB-Signatur-Scanner,
MinHook und den zentralen Stat-Commit-Hook. HP, Stamina und Spirit werden fuer
die aktiven Protagonisten am eigentlichen Commit-Punkt wieder auf voll gesetzt.
Damit kann ein letaler HP-Hit nicht zwischen Frames sichtbar werden.

Installation
------------
Ein ASI Loader muss vorhanden sein. Lege
CrimsonDesert_AbsoluteSurvival.asi in den Ordner, aus dem dein Loader ASI-Plugins
laedt (typisch der bin64-Ordner neben CrimsonDesert.exe).

Nur im Singleplayer verwenden.

Kompatibilitaet
---------------
Die Mod verwendet Signatur-Scanning statt fester Adressen. Nach einem Spielupdate
kann eine Signatur nicht mehr passen; dann wird der betroffene Hook nicht gesetzt,
statt blind eine alte feste Adresse zu patchen.
