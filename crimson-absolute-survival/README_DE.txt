Crimson Desert - Absolute Survival v1.1.1
==========================================

WICHTIGE KORREKTUR GEGENUEBER v1.1.0
- v1.1.0 uebernahm aus der Trinity-Basis eine veraltete Ressourcentyp-Zuordnung.
- Fuer neuere Crimson-Desert-Builds wird Stamina als Stat-Typ 19 behandelt.
- Spirit wird als Typ 20 behandelt; 17/18 bleiben Legacy-/Neben-Spiritressourcen.
- v1.1.1 korrigiert diese Zuordnung und hat zusaetzlich einen aktiven Hard-Lock:
  bereits aufgeloeste Spieler-HP/Stamina/Spirit-Gauges werden dauerhaft auf Max
  gehalten, selbst wenn ein aktueller Spielbuild einen Write-Pfad ausserhalb des
  alten StatCommit-Funnels verwendet.

Basis:
- Trinity by XeTrinityz (MIT), gepinnt auf Commit
  70c9a00dd6e10b2081d706a837756844c11f5c2b
- SafetyHook by cursey (Boost Software License 1.0), gepinnt auf Commit
  f44cc070a8340f2f26649553c49533475417304d

Permanent aktiv, ohne Hotkey:
- God Mode / HP bleibt voll
- kein Kampf-, Fall-, Umwelt- oder sonstiger HP-Schaden am Spieler
- Infinite Stamina / kein Ausdauerverbrauch
- Infinite Spirit / kein Spirit-Ressourcenverbrauch
- kein Haltbarkeitsverbrauch fuer normale Waffen/Werkzeuge/Ausruestung
- kein Haltbarkeitsverbrauch fuer den separaten Abyss-/Spezialausruestungs-Pfad
- Max Stack Size = 999 fuer alle Itemdefinitionen

Stack-Regel fuer Waffen/Ruestung:
- Die Mod setzt nur die maximale Stack-Obergrenze auf 999.
- Ob zwei Ausruestungsgegenstaende zusammengefuehrt werden duerfen, entscheidet
  weiterhin die originale Identitaets-/Merge-Logik des Spiels.
- Unterschiedliche Instanzdaten werden NICHT gleichgemacht.

Absichtlich normal/unveraendert:
- Itemmengen
- Itemverbrauch
- Munition
- Traenke und Verbrauchsgegenstaende
- Loot-/Dropmengen
- ausgehender Spielerschaden
- Inventar-Slotanzahl
- keine Item-Erzeugung
- kein Teleport / keine Zeit- oder World-Hacks

Installation:
Ein funktionierender ASI Loader muss vorhanden sein.
CrimsonDesert_AbsoluteSurvival.asi in den Ordner legen, aus dem der Loader
ASI-Plugins laedt (typischerweise bin64).

Nur im Singleplayer verwenden.

Kompatibilitaet:
Die Mod nutzt AOB-/Signatur-Scanning statt fester absoluter Adressen. Haltbarkeits-
Hooks werden nur bei eindeutigem Muster installiert. Fuer HP/Stamina/Spirit wird
zusaetzlich der live aufgeloeste Protagonisten-Statblock verwendet; NPC-/Gegner-
Stats werden nicht gepinnt.

Build:
Windows Server 2022 / Visual Studio 2022 / x64 Release via GitHub Actions.