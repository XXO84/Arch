$ErrorActionPreference = 'Stop'

$player = Join-Path $PSScriptRoot '..\TrinitySrc\src\game\player.cpp'
$playerH = Join-Path $PSScriptRoot '..\TrinitySrc\src\game\player.h'
if (-not (Test-Path -LiteralPath $player -PathType Leaf)) { throw "player.cpp not found: $player" }
if (-not (Test-Path -LiteralPath $playerH -PathType Leaf)) { throw "player.h not found: $playerH" }

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

# Current resource mapping: recent PSM resolver uses Stamina=19, Spirit=20;
# 17/18 are legacy/secondary spirit-like resources. Trinity's initial mapping
# treated 20 as stamina, which caused v1.1.0 to pin the wrong gauge.
$stamPattern = 'bool\s+IsStaminaType\(int32_t\s+t\)\s*\{[^\r\n}]*\}'
$spiritPattern = 'bool\s+IsSpiritType\(int32_t\s+t\)\s*\{[^\r\n}]*\}'
$stamMatches = [regex]::Matches($s, $stamPattern)
$spiritMatches = [regex]::Matches($s, $spiritPattern)
if ($stamMatches.Count -ne 1) { throw "Expected exactly one IsStaminaType definition, found $($stamMatches.Count)." }
if ($spiritMatches.Count -ne 1) { throw "Expected exactly one IsSpiritType definition, found $($spiritMatches.Count)." }
$s = [regex]::Replace($s, $stamPattern, 'bool IsStaminaType(int32_t t) { return t == 19; } // current player stamina', 1)
$s = [regex]::Replace($s, $spiritPattern, 'bool IsSpiritType(int32_t t) { return t == 20 || t == 17 || t == 18; } // current + legacy spirit resources', 1)

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

$pattern = '(?s)\r?\n\s*// Hook the damage-apply dispatcher for the damage multipliers\..*?&g_damageHookTarget\);'
$s = [regex]::Replace($s, $pattern, "`r`n        // Absolute Survival: damage-multiplier hook intentionally omitted.")
if ($s.Contains('mem::InstallHook("player: damage-apply"')) { throw 'Damage multiplier hook was not removed.' }

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

    bool Player::Ready()
    {
        return g_hpEntries[0].load(std::memory_order_relaxed) >= kMinPointer;
    }
"@
if (-not $s.Contains($readyNeedle)) { throw 'Player::Ready block changed.' }
$s = $s.Replace($readyNeedle, $forceBlock)
Set-Content -LiteralPath $player -Value $s -Encoding utf8

$h = Get-Content -Raw -LiteralPath $playerH
$declNeedle = '        static void RefreshSelf();'
if (-not $h.Contains($declNeedle)) { throw 'Player::RefreshSelf declaration changed.' }
$h = $h.Replace($declNeedle, "        static void RefreshSelf();`r`n`r`n        // Fallback hard-lock for current builds whose resource writes bypass StatCommit.`r`n        static void ForceAbsoluteResources();")
Set-Content -LiteralPath $playerH -Value $h -Encoding utf8

Write-Host 'player.cpp patched: stamina=type19, spirit=type20/17/18, commit guard + hard-lock fallback.'