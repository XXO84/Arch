Crimson Desert - Absolute Survival v1.2.0 AUDITED-2.02 NO-STACK
===============================================================

ZIEL
- Absolute Spielerschutz ohne Inventar-, Item- oder Stack-Verhalten zu veraendern.
- Gegen den aktuellen Crimson-Desert-Stand 2.02.00 quellenbasiert gepruefte
  Runtime-Pfade verwenden und bei unbekannten Signaturen sauber aussteigen.

AKTUELLER SPIELSTAND
- Offizieller Patch: Crimson Desert 2.02.00 vom 11.09.2026.
- Diese ASI wurde fuer den 2.02-Audit neu gebaut. Ein echter Laufzeittest gegen
  DEINE konkrete CrimsonDesert.exe bleibt trotzdem erforderlich; deshalb schreibt
  die Mod ein detailliertes Runtime-Log.

PERMANENT AKTIV - KEIN HOTKEY
- God Mode / HP bleibt voll.
- Eingehende negative Health-Deltas fuer aufgeloeste Protagonisten werden am
  Damage-Apply-Pfad auf 0 gesetzt, sofern die Signatur des Spielbuilds passt.
- Zusaetzlicher StatCommit-Pin + Hard-Lock fuer HP als Fallback.
- Dadurch Schutz gegen Kampf-, Fall-, Umwelt- und sonstigen HP-Schaden.
- Infinite Stamina.
- Infinite Spirit / bekannte Neben-/Legacy-Aktionsressourcen.
- Kein Haltbarkeitsverbrauch fuer normale Waffen/Werkzeuge/Ausruestung.
- Kein Haltbarkeitsverbrauch fuer Abyss-/Spezialausruestung.

RESSOURCEN - DREIFACHER SCHUTZ
1. Direkter stamina-ab00 Cost-Hook: negative Kosten werden fuer eindeutig
   aufgeloeste Spieler-Stamina-/Action-Entries auf 0 gesetzt.
2. Direkter spirit-delta Hook: negative Spirit-Kosten werden fuer eindeutig
   aufgeloeste Spieler-Spirit-Entries auf 0 gesetzt.
3. StatCommit + permanenter Hard-Lock: bereits aufgeloeste HP/Stamina/Spirit-
   Entries werden auf Max gehalten, falls ein Spielupdate einen anderen
   Schreibpfad verwendet.

Bekannte Runtime-Zuordnung im Audit:
- Health: 0
- Stamina: 19
- Spirit / bekannte Action-/Legacy-Pools: 17, 18, 20, 21

HALTBARKEIT
- Normaler Durability-Delta-Pfad wird pattern-gescannt.
- Separater Abyss-Durability-Delta-Pfad wird pattern-gescannt.
- Fuer Abyss existieren Primary + Fallback-Signatur.
- Der aeltere Maintenance-Write-Hook wird ABSICHTLICH NICHT installiert: der
  gepflegte Runtime-RE deaktiviert ihn ebenfalls aus Gruenden der Startstabilitaet.
- Bereits beschaedigte Ausruestung wird nicht automatisch repariert; weiterer
  Verbrauch soll ab Aktivierung blockiert werden.

STACK / INVENTAR
- KOMPLETT ENTFERNT.
- Kein Inventory-Modul wird in diese ASI kompiliert.
- Kein SetAllMaxStackSizes-Aufruf.
- Keine Aenderung an Stack-Limits oder Stackability.
- Waffen/Ruestungen bleiben exakt nach Originalspiel stackbar oder nicht stackbar.
- Itemmengen und Itemverbrauch bleiben vollstaendig original.

ABSICHTLICH NORMAL / UNVERAENDERT
- Stack-Limits und Stackability
- Itemmengen
- Itemverbrauch
- Munition
- Traenke und Verbrauchsgegenstaende
- Loot-/Dropmengen
- ausgehender Spielerschaden
- Inventar-Slotanzahl
- keine Item-Erzeugung
- kein Teleport / keine Zeit- oder World-Hacks

DIAGNOSELOG
%LOCALAPPDATA%\CrimsonDesert_AbsoluteSurvival\AbsoluteSurvival.log

Das Log zeigt unter anderem:
- erkannte CrimsonDesert.exe-Dateiversion
- ob direkte Stamina-/Spirit-Hooks gefunden wurden
- ob normaler/Abyss-Haltbarkeitshook gefunden wurde
- ausdrueckliche Meldung, dass Inventory/Stack NICHT einkompiliert ist
- Anzahl der live aufgeloesten HP-/Stamina-/Spirit-Entries
- Trinitys eigene AOB-/Hook-Warnungen

WICHTIG FUER FEHLERBERICHTE
Wenn eine Funktion in deinem 2.02.00-Build nicht greift, sende dieses Log.
Dann kann der konkrete fehlende Hook/AOB korrigiert werden, statt zu raten.

BASIS / LIZENZEN
- Trinity by XeTrinityz (MIT), gepinnt auf Commit
  70c9a00dd6e10b2081d706a837756844c11f5c2b
- SafetyHook by cursey (Boost Software License 1.0), gepinnt auf Commit
  f44cc070a8340f2f26649553c49533475417304d

INSTALLATION
Ein funktionierender ASI Loader muss vorhanden sein.
CrimsonDesert_AbsoluteSurvival.asi in den Ordner legen, aus dem der Loader
ASI-Plugins laedt (typischerweise bin64).
Alte Absolute-Survival-ASI vorher ersetzen, nicht parallel behalten.

Nur im Singleplayer verwenden.

BUILD
Windows Server 2022 / Visual Studio 2022 / x64 Release via GitHub Actions.
Der Build-Workflow prueft MZ/PE-Header und AMD64 Machine 0x8664 vor Packaging.
