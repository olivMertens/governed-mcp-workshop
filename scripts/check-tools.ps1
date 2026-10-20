#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('terraform', 'low-code')][string]$Track = 'terraform'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$failed = $false

function Test-WorkshopTool {
    param([string]$Name, [string[]]$Arguments, [scriptblock]$Accept, [string]$Requirement)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-Output "FAIL $Name missing; required: $Requirement. See docs/GETTING-STARTED.md."
        $script:failed = $true
        return
    }
    if ($Name -eq 'func' -and $command.CommandType -in @('Application', 'ExternalScript')) {
        $package = Join-Path (Split-Path $command.Source -Parent) 'node_modules/azure-functions-core-tools'
        $launcher = Get-Item -LiteralPath $command.Source
        if ($launcher.LinkType) {
            $target = $launcher.ResolveLinkTarget($true)
            if ($target -and $target.FullName -match '[/\\]azure-functions-core-tools[/\\]lib[/\\]main\.js$') {
                $package = Split-Path (Split-Path $target.FullName -Parent) -Parent
            }
        }
        $npmShim = Test-Path -LiteralPath (Join-Path $package 'package.json')
        if (-not $npmShim -and $launcher.Extension -in @('.ps1', '.cmd', '.js')) {
            $npmShim = (Get-Content -LiteralPath $launcher.FullName -Raw) -match 'azure-functions-core-tools[/\\]lib[/\\]main\.js'
        }
        $binary = Join-Path $package $(if ($IsWindows) { 'bin/func.exe' } else { 'bin/func' })
        if ($npmShim -and -not (Test-Path -LiteralPath $binary -PathType Leaf)) {
            Write-Output "FAIL func npm shim has no runtime binary; finish the documented Core Tools installation. No first-run download was started."
            $script:failed = $true
            return
        }
    }
    $output = & $Name @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or -not (& $Accept $output)) {
        Write-Output "FAIL $Name incompatible or command failed; required: $Requirement. See docs/GETTING-STARTED.md."
        $script:failed = $true
        return
    }
    Write-Output "PASS $Name ($Requirement; expected HTTP N/A)"
}

Test-WorkshopTool git @('--version') {
    param($text)
    $text -match 'git version (\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge [version]'2.0.0'
} 'Git 2+'
Test-WorkshopTool az @('version', '--output', 'json') {
    param($text)
    [version](($text | ConvertFrom-Json).'azure-cli') -ge [version]'2.88.0'
} 'Azure CLI >= 2.88.0'
if ($Track -eq 'terraform') {
    Test-WorkshopTool terraform @('version', '-json') {
        param($text)
        $version = [version](($text | ConvertFrom-Json).terraform_version)
        $version -ge [version]'1.16.6' -and $version.Major -eq 1
    } 'Terraform >= 1.16.6, < 2'
}
Test-WorkshopTool dotnet @('--list-sdks') { param($text) $text -match '(?m)^10\.\d+\.\d+ ' } '.NET SDK 10'
Test-WorkshopTool node @('--version') {
    param($text)
    $text.Trim() -match '^v(\d+\.\d+\.\d+)$' -and [version]$Matches[1] -ge [version]'22.19.0'
} 'Node.js >= 22.19.0'
Test-WorkshopTool func @('--version') {
    param($text)
    $text.Trim() -match '^4\.(\d+)\.(\d+)$' -and [version]$text.Trim() -ge [version]'4.5.0'
} 'Functions Core Tools >= 4.5.0, < 5 (not the Preview v5 CLI)'
Write-Output "PASS PowerShell $($PSVersionTable.PSVersion) (expected HTTP N/A)"
if ($failed) { throw 'Tool checks failed. Resolve every FAIL before continuing. No Azure permissions or quota were checked.' }
Write-Output 'PASS local tools only; Azure context, permissions, quota and deployment remain separate checks.'
