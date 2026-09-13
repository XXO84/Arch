$ErrorActionPreference = 'Stop'

$player = Join-Path $PSScriptRoot '..\TrinitySrc\src\game\player.cpp'
if (-not (Test-Path -LiteralPath $player -PathType Leaf)) {
    throw "player.cpp not found: $player"
}

$s = Get-Content -Raw -LiteralPath $player

$replacements = [ordered]@{
    'if (st.godMode    && InSet(g_hpEntries,     kMaxPlayers,     e)) PinEntry(e);' = 'if (InSet(g_hpEntries,     kMaxPlayers,     e)) PinEntry(e);'
    'if (st.infStamina && InSet(g_stamEntries,   kMaxStatEntries, e)) PinEntry(e);' = 'if (InSet(g_stamEntries,   kMaxStatEntries, e)) PinEntry(e);'
    'if (st.infSpirit  && InSet(g_spiritEntries, kMaxStatEntries, e)) PinEntry(e);' = 'if (InSet(g_spiritEntries, kMaxStatEntries, e)) PinEntry(e);'
}

foreach ($old in $replacements.Keys) {
    if (-not $s.Contains($old)) {
        throw "Pinned upstream line missing: $old"
    }
    $s = $s.Replace($old, $replacements[$old])
}

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
if (-not $s.Contains($oldActive)) {
    throw 'AnyStatFeatureActive upstream block changed.'
}
$s = $s.Replace($oldActive, $newActive)

# Do not install the battle-damage multiplier dispatcher. Absolute Survival
# protects HP at the lower stat-commit choke point and leaves outgoing damage normal.
$pattern = '(?s)\r?\n\s*// Hook the damage-apply dispatcher for the damage multipliers\..*?&g_damageHookTarget\);'
$s = [regex]::Replace($s, $pattern, "`r`n        // Absolute Survival: damage-multiplier hook intentionally omitted.")
if ($s.Contains('mem::InstallHook("player: damage-apply"')) {
    throw 'Damage multiplier hook was not removed.'
}

Set-Content -LiteralPath $player -Value $s -Encoding utf8
Write-Host 'player.cpp patched for permanent HP/Stamina/Spirit protection.'
