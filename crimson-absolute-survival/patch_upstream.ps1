$ErrorActionPreference = 'Stop'

$srcRoot = Join-Path $PSScriptRoot '..\TrinitySrc\src'
$player = Join-Path $srcRoot 'game\player.cpp'
$playerH = Join-Path $srcRoot 'game\player.h'
$inventory = Join-Path $srcRoot 'game\inventory.cpp'
$loggerH = Join-Path $srcRoot 'core\logger.h'
foreach ($p in @($player,$playerH,$inventory,$loggerH)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Required upstream file not found: $p" }
}

# ---------------------------------------------------------------------------
# Player: permanent HP / stamina / spirit protection.
# ---------------------------------------------------------------------------
$s = Get-Content -Raw -LiteralPath $player

$replacements = [ordered]@{
    'if (st.godMode    && InSet(g_hpEntries,     kMaxPlayers,     e)) PinEntry(e);' = 'if (InSet(g_hpEntries,     kMaxPlayers,     e)) PinEntry(e);'
    'if (st.infStamina && InSet(g_stamEntries,   kMaxStatEntries, e)) PinEntry(e);' = 'if (InSet(g_stamEntries,   kMaxStatEntries, e)) PinEntry(e);'
    'if (st.infSpirit  && InSet(g_spiritEntries, kMaxStatEntries, e)) PinEntry(e);' = 'if (InSet(g_spiritEntries, kMaxStatEntries, e)) PinEntry(e);'
}
foreach ($old in $replacements.Keys) {
    if (-not $s.Contains($old)) { throw "Pinned upstream line missing: $old" }
    $s = $s.Replace($old, $replacements[$old])
}

# Newer runtime RE maps the live player stamina entry to type 19 and the main
# spirit pool to type 20. Keep 17/18 and the older Trinity type 21 in the
# protected spirit set too. This deliberately protects every known player
# action-resource gauge 17..21 except 19 is classified as stamina.
$stamPattern = 'bool\s+IsStaminaType\(int32_t\s+t\)\s*\{[^\r\n}]*\}'
$spiritPattern = 'bool\s+IsSpiritType\(int32_t\s+t\)\s*\{[^\r\n}]*\}'
if ([regex]::Matches($s, $stamPattern).Count -ne 1) { throw 'Expected exactly one IsStaminaType definition.' }
if ([regex]::Matches($s, $spiritPattern).Count -ne 1) { throw 'Expected exactly one IsSpiritType definition.' }
$s = [regex]::Replace($s, $stamPattern, 'bool IsStaminaType(int32_t t) { return t == 19; } // current player stamina', 1)
$s = [regex]::Replace($s, $spiritPattern, 'bool IsSpiritType(int32_t t) { return t == 20 || t == 17 || t == 18 || t == 21; } // current + known legacy spirit/action pools', 1)

$oldActive = @"
        bool AnyStatFeatureActive(const State& st)
        {
            return st.godMode || st.infStamina || st.infSpirit ||
                   st.dmgInMult != 1.0f || st.dmgOutMult != 1.0f;
        }
"@
$newActive = @"
        bool AnyStatFeatureActive(const State& st)
        {
            static_cast<void>(st);
            return true; // Absolute Survival is permanently active.
        }
"@
if (-not $s.Contains($oldActive)) { throw 'AnyStatFeatureActive upstream block changed.' }
$s = $s.Replace($oldActive, $newActive)

# Redundant incoming-damage guard. Keep Trinity's pattern-scanned damage hook,
# but hard-zero only negative HEALTH deltas whose targetOwner is one of the
# freshly resolved protagonists. Outgoing damage and every NPC-vs-NPC hit stay
# untouched. The lower StatCommit pin + hard-lock remain as fall/script fallback.
$damageGatePattern = 'if\s*\(delta\s*<\s*0\s*&&\s*statusId\s*==\s*StatType_Health\)\s*delta\s*=\s*ScaleDamage\(reinterpret_cast<uintptr_t>\(targetOwner\),\s*sourceCtx,\s*delta\);'
if ([regex]::Matches($s, $damageGatePattern).Count -ne 1) { throw 'Expected exactly one damage-apply gate.' }
$damageGateReplacement = @'
if (delta < 0 && statusId == StatType_Health &&
                InSet(g_targetOwners, kMaxPlayers, reinterpret_cast<uintptr_t>(targetOwner)))
                delta = 0;
'@
$s = [regex]::Replace($s, $damageGatePattern, $damageGateReplacement, 1)

# Add hard-lock and diagnostics helpers. The hard-lock is independent from
# StatCommit so resource writes introduced/moved by a game update are restored.
$readyNeedle = @"
    bool Player::Ready()
    {
        return g_hpEntries[0].load(std::memory_order_relaxed) >= kMinPointer;
    }
"@
$forceBlock = @"
    void Player::ForceAbsoluteResources()
    {
        for (int i = 0; i < kMaxPlayers; ++i)
        {
            const uintptr_t hp = g_hpEntries[i].load(std::memory_order_relaxed);
            if (hp >= kMinPointer) PinEntry(hp);
        }
        for (int i = 0; i < kMaxStatEntries; ++i)
        {
            const uintptr_t stamina = g_stamEntries[i].load(std::memory_order_relaxed);
            if (stamina >= kMinPointer) PinEntry(stamina);
            const uintptr_t spirit = g_spiritEntries[i].load(std::memory_order_relaxed);
            if (spirit >= kMinPointer) PinEntry(spirit);
        }
    }

    bool Player::IsTrackedStaminaEntry(std::uintptr_t entry)
    {
        return InSet(g_stamEntries, kMaxStatEntries, static_cast<uintptr_t>(entry));
    }

    bool Player::IsTrackedSpiritEntry(std::uintptr_t entry)
    {
        return InSet(g_spiritEntries, kMaxStatEntries, static_cast<uintptr_t>(entry));
    }

    void Player::GetResolvedCounts(int* hp, int* stamina, int* spirit)
    {
        int h = 0, s = 0, p = 0;
        for (int i = 0; i < kMaxPlayers; ++i)
            if (g_hpEntries[i].load(std::memory_order_relaxed) >= kMinPointer) ++h;
        for (int i = 0; i < kMaxStatEntries; ++i)
        {
            if (g_stamEntries[i].load(std::memory_order_relaxed) >= kMinPointer) ++s;
            if (g_spiritEntries[i].load(std::memory_order_relaxed) >= kMinPointer) ++p;
        }
        if (hp) *hp = h;
        if (stamina) *stamina = s;
        if (spirit) *spirit = p;
    }

    bool Player::Ready()
    {
        return g_hpEntries[0].load(std::memory_order_relaxed) >= kMinPointer;
    }
"@
if (-not $s.Contains($readyNeedle)) { throw 'Player::Ready block changed.' }
$s = $s.Replace($readyNeedle, $forceBlock)
Set-Content -LiteralPath $player -Value $s -Encoding utf8

$h = Get-Content -Raw -LiteralPath $playerH
if (-not $h.Contains('#pragma once')) { throw 'player.h header marker missing.' }
if (-not $h.Contains('#include <cstdint>')) { $h = $h.Replace('#pragma once', "#pragma once`r`n#include <cstdint>") }
$declNeedle = '        static void RefreshSelf();'
if (-not $h.Contains($declNeedle)) { throw 'Player::RefreshSelf declaration changed.' }
$decl = @"
        static void RefreshSelf();

        // Absolute Survival 2.02 audit helpers.
        static void ForceAbsoluteResources();
        static bool IsTrackedStaminaEntry(std::uintptr_t entry);
        static bool IsTrackedSpiritEntry(std::uintptr_t entry);
        static void GetResolvedCounts(int* hp, int* stamina, int* spirit);
"@
$h = $h.Replace($declNeedle, $decl.TrimEnd())
Set-Content -LiteralPath $playerH -Value $h -Encoding utf8

# ---------------------------------------------------------------------------
# Inventory: SAFE 999 stacks only for definitions that are ALREADY stackable.
# Do not flip non-stackable gear, special buffs or containers to stackable.
# Also never reduce an existing cap >= 999.
# ---------------------------------------------------------------------------
$inv = Get-Content -Raw -LiteralPath $inventory
$readNeedle = @"
                    Read64(def + kOff_ItemDef_MaxStackCount, &origVal);
                    Read8(def + kOff_ItemDef_ApplyMaxStackCap, &origCap);
                    g_origMaxStack[row]  = origVal;
"@
$readReplacement = @"
                    Read64(def + kOff_ItemDef_MaxStackCount, &origVal);
                    Read8(def + kOff_ItemDef_ApplyMaxStackCap, &origCap);
                    // 2.02 safety audit: only an already-active cap >1 is proof
                    // this definition is natively stackable. Non-stackable gear,
                    // special buff items and containers remain byte-identical.
                    if (origCap == 0 || origVal <= 1 || origVal >= value) continue;
                    g_origMaxStack[row]  = origVal;
"@
if (-not $inv.Contains($readNeedle)) { throw 'Inventory max-stack capture block changed.' }
$inv = $inv.Replace($readNeedle, $readReplacement)
Set-Content -LiteralPath $inventory -Value $inv -Encoding utf8

# ---------------------------------------------------------------------------
# File diagnostics: Trinity logger also appends every hook/scanner message to
# %LOCALAPPDATA%\CrimsonDesert_AbsoluteSurvival\AbsoluteSurvival.log.
# ---------------------------------------------------------------------------
$lg = Get-Content -Raw -LiteralPath $loggerH
$lockNeedle = '            std::lock_guard<std::mutex> lock(Mutex());'
if ([regex]::Matches($lg, [regex]::Escape($lockNeedle)).Count -lt 2) { throw 'Logger lock layout changed.' }
# Only patch the lock inside Log(): use the block that immediately follows line.text.
$logBlockNeedle = @"
            line.text  = msg;

            std::lock_guard<std::mutex> lock(Mutex());
            if (s_console)
"@
$logBlockReplacement = @"
            line.text  = msg;

            std::lock_guard<std::mutex> lock(Mutex());
            AppendToFile(line);
            if (s_console)
"@
if (-not $lg.Contains($logBlockNeedle)) { throw 'Logger::Log insertion point changed.' }
$lg = $lg.Replace($logBlockNeedle, $logBlockReplacement)
$lineNeedle = '        struct Line { Level lvl = Info; std::string stamp, text; };'
$lineReplacement = @"
        struct Line { Level lvl = Info; std::string stamp, text; };

        static void AppendToFile(const Line& l)
        {
            char root[MAX_PATH]{};
            const DWORD n = GetEnvironmentVariableA("LOCALAPPDATA", root, MAX_PATH);
            if (n == 0 || n >= MAX_PATH) return;
            const std::string dir = std::string(root) + "\\CrimsonDesert_AbsoluteSurvival";
            CreateDirectoryA(dir.c_str(), nullptr);
            const std::string path = dir + "\\AbsoluteSurvival.log";
            FILE* fp = nullptr;
            if (fopen_s(&fp, path.c_str(), "a") != 0 || !fp) return;
            std::fprintf(fp, "%s [%d] %s\n", l.stamp.c_str(), static_cast<int>(l.lvl), l.text.c_str());
            std::fclose(fp);
        }
"@
if (-not $lg.Contains($lineNeedle)) { throw 'Logger Line declaration changed.' }
$lg = $lg.Replace($lineNeedle, $lineReplacement.TrimEnd())
Set-Content -LiteralPath $loggerH -Value $lg -Encoding utf8

Write-Host 'AUDITED patch applied: resource IDs, incoming damage guard, hard-lock, safe native stacks, file diagnostics.'