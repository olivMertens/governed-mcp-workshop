#requires -Version 7.4
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:StepNumber = 0
function Step([string]$Title, [string]$Why) {
    $script:StepNumber++
    Write-Output ''; Write-Output "== Step $($script:StepNumber): $Title =="; Write-Output "   Why: $Why"
}
Write-Output 'Module 01 validator - a local MCP client and server talk to each other on your machine, with no Azure.'
$project = Join-Path $PSScriptRoot 'server' 'Workshop.LocalMcp.csproj'
Step 'Offline - build the local server from locked packages' 'Proves you run exactly the pinned code, with no surprise package versions.'
Get-Command dotnet -ErrorAction Stop | Out-Null
& dotnet restore $project --locked-mode --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'FAIL locked package restore (expected HTTP N/A; check SDK, package access and lock file).' }
& dotnet build $project --no-restore --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'FAIL local server build (expected HTTP N/A).' }
Write-Output 'PASS locked local server build (expected HTTP N/A).'
$server = Join-Path $PSScriptRoot 'server' 'bin' 'Release' 'net10.0' 'Workshop.LocalMcp.dll'
Step 'Local - the client discovers and calls the server tools' 'Proves the MCP handshake, tool list and tool calls work before any cloud step.'
& dotnet $server --validate
if ($LASTEXITCODE -ne 0) { throw 'FAIL local MCP client/server checks (expected HTTP N/A).' }
