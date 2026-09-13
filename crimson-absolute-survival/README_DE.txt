Crimson Desert - Absolute Survival v1.2.0 AUDITED-2.02
======================================================

ZIEL
- Absolute Spielerschutz ohne Inventar-/Itemverbrauch zu veraendern.
- Gegen den aktuellen Crimson-Desert-Stand 2.02.00 quellenbasiert gepruefte
  Runtime-Pfade verwenden und bei unbekannten Signaturen sauber aussteigen.

AKTUELLER SPIELSTAND
- Offizieller Patch: Crimson Desert 2.02.00 vom 11.09.2026.
- Diese ASI wurde fuer den 2.02-Audit neu gebaut. Ein echter Laufzeittest gegen
  DEINE konkrete CrimsonDesert.exe bleibt trotzdem erforderlich; deshalb schreibt
  v1.2.0 ein detailliertes Runtime-Log.

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

STACK 999 - SICHERHEITSKORREKTUR
v1.1.1 setzte die Max-Stack-Definition noch global fuer jede Itemdefinition.
Das ist nach aktuellem Modding-Stand NICHT sicher: globale Stackability kann
spezielle Buff-/Containeritems beim Start zerstoeren, und Gear-Stacks koennen
Equip-Kollisionen verursachen.

v1.2.0 macht deshalb NUR Folgendes:
- Eine Itemdefinition wird nur angehoben, wenn ihr originaler Stack-Cap bereits
  aktiv ist UND der originale Max-Stack groesser als 1 ist.
- Original Max-Stack 1 bleibt unangetastet: Waffen, Ruestungen, Spezialitems,
  Container usw. werden NICHT zwangsweise stackbar gemacht.
- Ein vorhandener Cap >= 999 wird NICHT reduziert.
- Ergebnis: bereits nativ stackbare Items erhalten mindestens 999, ohne
  Non-Stackable-Gear zu konvertieren.

ABSICHTLICH NORMAL / UNVERAENDERT
- Itemmengen
- Itemverbrauch
- Munition
- Traenke und Verbrauchsgegenstaende
- Loot-/Dropmengen
- ausgehender Spielerschaden
- Inventar-Slotanzahl
- keine Item-Erzeugung
- keine unterschiedlichen Waffen/Ruestungsinstanzen werden zusammengelegt
- kein Teleport / keine Zeit- oder World-Hacks

DIAGNOSELOG
%LOCALAPPDATA%\CrimsonDesert_AbsoluteSurvival\AbsoluteSurvival.log

Das Log zeigt unter anderem:
- erkannte CrimsonDesert.exe-Dateiversion
- ob direkte Stamina-/Spirit-Hooks gefunden wurden
- ob normaler/Abyss-Haltbarkeitshook gefunden wurde
- ob Safe-Stack angewendet wurde
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
