#requires -Version 7.4
<#
.SYNOPSIS
    Module 99 offline validation. Checks files, README structure and clean-up safety. Touches no Azure resource.
.PARAMETER Offline
    Run only the offline checks (the only mode for this module).
#>
[CmdletBinding()]
param([switch]$Offline)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$moduleDir = Join-Path $root 'modules/99-cleanup'
$failures = 0

function Pass([string]$name, [string]$detail = '') { Write-Output "PASS $name $detail".TrimEnd() }
function Fail([string]$name, [string]$detail = '') { $script:failures++; Write-Output "FAIL $name $detail".TrimEnd() }
function Check([string]$name, [bool]$ok, [string]$detail = '') { if ($ok) { Pass $name $detail } else { Fail $name $detail } }
$script:StepNumber = 0
function Step([string]$Title, [string]$Why) {
    $script:StepNumber++
    Write-Output ''; Write-Output "== Step $($script:StepNumber): $Title =="; Write-Output "   Why: $Why"
}
Write-Output 'Module 99 validator - the clean-up script exists, is documented and is safe by default (offline).'

Step 'Offline - clean-up files and README structure' 'Proves the scripts and the bilingual guide exist and follow the workshop contract.'
Check 'file: cleanup.ps1 exists' (Test-Path (Join-Path $moduleDir 'cleanup.ps1'))
Check 'file: cleanup.sh exists' (Test-Path (Join-Path $moduleDir 'cleanup.sh'))
Check 'file: README.md exists' (Test-Path (Join-Path $moduleDir 'README.md'))
Check 'file: README.fr.md exists' (Test-Path (Join-Path $moduleDir 'README.fr.md'))

$sections = @(
    'Goal', 'Why it matters', 'What you deploy', 'Prerequisites and required roles', 'Steps',
    'What you should see', 'Validate', 'Troubleshooting', 'Clean up', 'Go further', 'Sources'
)
$readme = Join-Path $moduleDir 'README.md'
if (Test-Path $readme) {
    $text = Get-Content -Raw -LiteralPath $readme
    $positions = foreach ($s in $sections) {
        $m = [regex]::Match($text, "(?m)^##\s+$([regex]::Escape($s))\b")
        if ($m.Success) { $m.Index } else { -1 }
    }
    $missing = @($sections | Where-Object -FilterScript { $text -notmatch "(?m)^##\s+$([regex]::Escape($_))\b" })
    Check 'README.md: all sections present' ($missing.Count -eq 0) ("missing: $($missing -join ', ')")
    $ordered = ($positions -notcontains -1) -and (@($positions | Sort-Object) -join ',' -eq ($positions -join ','))
    Check 'README.md: sections in contract order' $ordered
    Check 'README.md: has source links' ([regex]::Matches($text, 'https://learn\.microsoft\.com/').Count -ge 1)
}

$readmeFr = Join-Path $moduleDir 'README.fr.md'
if ((Test-Path $readme) -and (Test-Path $readmeFr)) {
    $en = ([regex]::Matches((Get-Content -Raw $readme), '(?m)^##\s')).Count
    $fr = ([regex]::Matches((Get-Content -Raw $readmeFr), '(?m)^##\s')).Count
    Check 'README.fr.md: same section count as EN' ($en -eq $fr) "(EN $en, FR $fr)"
}

$scripts = @('cleanup.ps1', 'cleanup.sh') | ForEach-Object { Join-Path $moduleDir $_ } | Where-Object { Test-Path $_ }
$all = ($scripts | ForEach-Object { Get-Content -Raw -LiteralPath $_ }) -join "`n"
Step 'Offline - the clean-up script is safe by default' 'Proves it only reports until you pass -Apply, never destroys everything and holds no ID or secret.'
Check 'safety: no blanket terraform destroy' ($all -notmatch '(?m)^\s*&?\s*terraform\s+destroy\b')
Check 'safety: no hard-coded GUIDs' ($all -notmatch '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
Check 'safety: no client secret literals' ($all -notmatch '(?i)client_?secret\s*[=:]\s*["'']?[A-Za-z0-9~._-]{16,}')
Check 'safety: reports by default (-Apply switch)' ($all -match '\[switch\]\$Apply')

Write-Output "RESULT: $(if ($failures -eq 0) { 'PASS' } else { 'FAIL' }) ($failures failure(s))"
exit $failures
