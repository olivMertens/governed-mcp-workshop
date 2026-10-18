#requires -Version 7.4
<#
.SYNOPSIS
    Module 06 (Observe and inventory) validator.

.DESCRIPTION
    Offline checks only (-Offline). Prints one PASS or FAIL line per check.
    Makes no Azure, Microsoft Graph or Entra calls and deploys nothing.

.PARAMETER Offline
    Run the offline checks. Required in this version.

.EXAMPLE
    pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
#>
[CmdletBinding()]
param(
    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Offline) {
    throw 'FAIL: only -Offline is supported for module 06. No live checks are scripted.'
}

$root      = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
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
$kqlPath    = Join-Path $moduleDir 'queries/mcp-traffic.kql'
$readme     = if (Test-Path $readmePath) { Get-Content -Raw $readmePath } else { '' }
$kql        = if (Test-Path $kqlPath) { Get-Content -Raw $kqlPath } else { '' }

# 1. Required files exist.
foreach ($f in @('README.md', 'README.fr.md', 'validate.ps1', 'validate.sh', 'cleanup.ps1', 'cleanup.sh', 'queries/mcp-traffic.kql')) {
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
Check 'README sections present and in order' {
    ($positions -notcontains -1) -and (@($positions | Sort-Object) -join ',' -eq ($positions -join ','))
} 'a contract section is missing or out of order'

# 3. French README mirrors the same section count.
$frText = if (Test-Path $frPath) { Get-Content -Raw $frPath } else { '' }
Check 'README.fr.md has the same section count' {
    ([regex]::Matches($frText, '(?m)^## ')).Count -eq ([regex]::Matches($readme, '(?m)^## ')).Count
} 'section count differs from README.md'

# 4. Steps list PowerShell before bash.
Check 'Steps give PowerShell before bash' {
    $steps = [regex]::Match($readme, '(?s)## Steps(.*?)## What you should see').Groups[1].Value
    $ps = $steps.IndexOf('PowerShell'); $sh = $steps.IndexOf('bash')
    ($ps -ge 0) -and ($sh -gt $ps)
} 'PowerShell block must come before bash'

# 5. Preview labels on the preview features.
Check 'Preview label on API Center, BYO and Agent 365' {
    ($readme -match 'API Center') -and ($readme -match 'BYO') -and ($readme -match 'Agent 365') -and
    ($readme -match '\*\*Preview\*\*')
} 'Preview label missing'

# 6. KQL reads metadata only.
$forbiddenKql = @('RequestBody', 'ResponseBody', 'gen_ai.tool.call.arguments', 'gen_ai.tool.call.result', 'context.Request.Body', 'Authorization')
Check 'KQL selects no body, argument, result or token fields' {
    $hits = $forbiddenKql | Where-Object { $kql.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
    -not $hits
} 'KQL references a forbidden field'

Check 'KQL filters on api.type Mcp' {
    ($kql -match 'customDimensions\[[''"]api\.type[''"]\]') -and ($kql -match '[''"]Mcp[''"]')
} 'KQL does not filter on api.type == Mcp'

# 7. Payload logging is never enabled as an instruction.
Check 'README does not instruct enabling payload logging' {
    -not ($readme -match '(?i)(turn on|enable|set)[^\n]{0,60}(payload logging|gen_ai\.tool\.call\.(arguments|result))' -and
          $readme -notmatch '(?i)(off|must stay off|do not turn on|never)')
} 'README tells the reader to enable payload logging'

# 8. No secrets or tokens in the module.
$secretPatterns = @(
    'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
    '(?i)(client_secret|password|api[_-]?key)\s*[:=]\s*[''"]?[A-Za-z0-9/+_\-]{12,}',
    'InstrumentationKey=[0-9a-f-]{36}',
    '(?i)Bearer\s+[A-Za-z0-9._\-]{20,}'
)
Check 'no secrets or tokens in module files' {
    $files = Get-ChildItem -Path $moduleDir -Recurse -File | Where-Object { $_.Name -ne 'validate.ps1' }
    $bad = foreach ($f in $files) {
        $t = Get-Content -Raw $f.FullName
        foreach ($p in $secretPatterns) { if ($t -match $p) { $f.Name } }
    }
    -not $bad
} 'a secret-like string was found'

# 9. Synthetic data only: no real-looking tenant or subscription GUIDs.
Check 'only placeholder GUIDs in module files' {
    $files = Get-ChildItem -Path $moduleDir -Recurse -File | Where-Object { $_.Name -ne 'validate.ps1' }
    $bad = foreach ($f in $files) {
        $t = Get-Content -Raw $f.FullName
        $guids = [regex]::Matches($t, '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')
        foreach ($g in $guids) {
            if ($g.Value -notmatch '^0{8}-0{4}-0{4}-0{4}-0{12}$') { $f.Name }
        }
    }
    -not $bad
} 'a non-placeholder GUID was found'

# 10. Status is authored, never validated.
$progress = Get-Content -Raw (Join-Path $root 'docs/PROGRESS.md')
Check 'PROGRESS row 06 is not claimed as validated before live run' {
    $row = ($progress -split "`n" | Where-Object { $_ -match '^\|\s*06\s*\|' }) | Select-Object -First 1
    $row -and ($row -notmatch '\|\s*validated\s*\|')
} 'row 06 must not be validated in the offline build'

# 11. Sources recorded with a last-verified date.
$sources = Get-Content -Raw (Join-Path $root 'docs/sources.md')
Check 'docs/sources.md has module 06 entries with last-verified dates' {
    ($sources -match '(?m)^\|\s*06b?\b') -and ($sources -match '(?i)last verified')
} 'module 06 sources or last-verified dates missing'

# 12. No infra folder (module adds no Azure resources).
Check 'no infra folder (no Azure resources added)' {
    -not (Test-Path (Join-Path $moduleDir 'infra'))
} 'infra folder exists but the module adds no resources'

# 13. Log rules documented.
Check 'README states the log rules' {
    ($readme -match '(?i)zero body bytes|no bod') -and ($readme -match '(?i)token') -and ($readme -match '(?i)prompt')
} 'log rules (no bodies, tokens, prompts) not stated'

if ($failures -gt 0) {
    Write-Output "RESULT: $failures check(s) failed"
    exit 1
}
Write-Output 'RESULT: all offline checks passed'
exit 0
