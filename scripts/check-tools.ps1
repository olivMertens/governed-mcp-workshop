#requires -Version 7.4
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$failed = $false

function Test-WorkshopTool {
    param([string]$Name, [string[]]$Arguments, [scriptblock]$Accept, [string]$Requirement)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Output "FAIL $Name missing; required: $Requirement. See docs/GETTING-STARTED.md."
        $script:failed = $true
        return
    }
    $output = & $Name @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or -not (& $Accept $output)) {
        Write-Output "FAIL $Name incompatible or command failed; required: $Requirement. See docs/GETTING-STARTED.md."
        $script:failed = $true
        return
    }
    Write-Output "PASS $Name ($Requirement)"
}

Test-WorkshopTool git @('--version') {
    param($text)
    $text -match 'git version (\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge [version]'2.0.0'
} 'Git 2+'
Test-WorkshopTool az @('version', '--output', 'json') {
    param($text)
    [version](($text | ConvertFrom-Json).'azure-cli') -ge [version]'2.88.0'
} 'Azure CLI >= 2.88.0'
Test-WorkshopTool terraform @('version', '-json') {
    param($text)
    $version = [version](($text | ConvertFrom-Json).terraform_version)
    $version -ge [version]'1.16.5' -and $version.Major -eq 1
} 'Terraform >= 1.16.5, < 2'
Test-WorkshopTool dotnet @('--list-sdks') { param($text) $text -match '(?m)^10\.\d+\.\d+ ' } '.NET SDK 10'
Test-WorkshopTool node @('--version') {
    param($text)
    $text.Trim() -match '^v(\d+\.\d+\.\d+)$' -and [version]$Matches[1] -ge [version]'22.19.0'
} 'Node.js >= 22.19.0'
Test-WorkshopTool func @('--version') {
    param($text)
    $text.Trim() -match '^4\.(\d+)\.(\d+)$' -and [version]$text.Trim() -ge [version]'4.5.0'
} 'Functions Core Tools >= 4.5.0, < 5 (not the Preview v5 CLI)'
Write-Output "PASS PowerShell $($PSVersionTable.PSVersion)"
if ($failed) { throw 'Tool checks failed. Resolve every FAIL before continuing. No Azure permissions or quota were checked.' }
Write-Output 'PASS local tools only; Azure context, permissions, quota and deployment remain separate checks.'
