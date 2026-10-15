#requires -Version 7.4
<#
.SYNOPSIS
    Module 07 (Optional: other clients) validator.

.DESCRIPTION
    Offline checks only (-Offline). Prints one PASS or FAIL line per check.
    Makes no Azure, Microsoft Graph, Entra, Foundry or Copilot Studio calls.

.PARAMETER Offline
    Run the offline checks. Required in this version.

.EXAMPLE
    pwsh ./modules/07-clients/validate.ps1 -Offline
#>
[CmdletBinding()]
param(
    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Offline) {
    throw 'FAIL: only -Offline is supported for module 07. No live checks are scripted.'
}

$moduleDir = $PSScriptRoot
$failures  = 0

function Pass([string]$Name, [string]$Detail = '') {
    $suffix = if ($Detail) { " - $Detail" } else { '' }
    Write-Output "PASS $Name$suffix (offline)"
}

function Fail([string]$Name, [string]$Detail) {
    Write-Output "FAIL $Name - $Detail"
    $script:failures++
}

function Check([string]$Name, [scriptblock]$Test, [string]$FailDetail) {
    try {
        $ok = & $Test
        if ($ok) { Pass $Name } else { Fail $Name $FailDetail }
    }
    catch {
        Fail $Name "$FailDetail ($($_.Exception.Message))"
    }
}

$readmePath = Join-Path $moduleDir 'README.md'
$frPath     = Join-Path $moduleDir 'README.fr.md'
$readme     = if (Test-Path $readmePath) { Get-Content -Raw $readmePath } else { '' }
$readmeFr   = if (Test-Path $frPath) { Get-Content -Raw $frPath } else { '' }

# 1. Required files exist.
foreach ($f in @('README.md', 'README.fr.md', 'validate.ps1', 'validate.sh', 'cleanup.ps1', 'cleanup.sh')) {
    Check "file exists: $f" { Test-Path (Join-Path $moduleDir $f) } 'missing file'
}

# 2. README sections in contract order.
$sections = @(
    'Goal', 'Why it matters', 'What you deploy', 'Prerequisites and required roles', 'Steps',
    'What you should see', 'Validate', 'Troubleshooting', 'Clean up', 'Go further', 'Sources'
)
$positions = foreach ($s in $sections) {
    $m = [regex]::Match($readme, "(?m)^## $([regex]::Escape($s))\b")
    if ($m.Success) { $m.Index } else { -1 }
}
Check 'README sections present in contract order' {
    ($positions -notcontains -1) -and (-not ($positions | Where-Object { $_ -lt 0 })) -and
    (($positions | Sort-Object) -join ',' -eq ($positions -join ','))
} 'a section is missing or out of order'

# 3. French README mirrors the same sections.
Check 'French README has the same section count' {
    ([regex]::Matches($readmeFr, '(?m)^## ')).Count -eq ([regex]::Matches($readme, '(?m)^## ')).Count
} 'section count differs between EN and FR'

# 4. Required guidance is present.
Check 'states that this module creates no resources' {
    $readme -match 'creates no Azure' -and $readmeFr -match 'ne crée aucune ressource'
} 'missing "no resources" statement in EN or FR'

Check 'marks Preview features' {
    $readme -match 'Preview' -and $readmeFr -match 'préversion'
} 'Preview label missing in EN or FR'

Check 'never recommends the anonymous None option for Copilot Studio' {
    $readme -match 'never \*\*None\*\*' -and $readmeFr -match 'jamais \*\*Aucune\*\*'
} 'the None-option warning is missing in EN or FR'

Check 'states SSE is no longer supported' {
    $readme -match 'SSE is no longer supported' -and $readmeFr -match 'SSE n''est plus pris en charge'
} 'SSE statement missing in EN or FR'

Check 'Sources link the Foundry and Copilot Studio pages' {
    $readme -match 'mcp-authentication' -and $readme -match 'mcp-add-existing-server-to-agent'
} 'source links missing'

# 5. No secrets or tenant-specific identifiers in this folder.
$allText = (Get-ChildItem -Path $moduleDir -File | Get-Content -Raw) -join "`n"
Check 'no GUIDs or client secrets in module files' {
    -not ($allText -match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') -and
    -not ($allText -match '(?i)client[_ -]?secret\s*[:=]\s*\S+')
} 'a GUID or client secret pattern was found'

Write-Output ''
if ($failures -eq 0) {
    Write-Output 'RESULT: all offline checks passed'
    exit 0
}
Write-Output "RESULT: $failures offline check(s) failed"
exit 1
