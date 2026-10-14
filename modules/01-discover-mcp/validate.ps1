#requires -Version 7.4
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'server' 'Workshop.LocalMcp.csproj'
Get-Command dotnet -ErrorAction Stop | Out-Null
& dotnet restore $project --locked-mode --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'FAIL locked package restore (expected HTTP N/A; check SDK, package access and lock file).' }
& dotnet build $project --no-restore --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'FAIL local server build (expected HTTP N/A).' }
Write-Output 'PASS locked local server build (expected HTTP N/A).'
$server = Join-Path $PSScriptRoot 'server' 'bin' 'Release' 'net10.0' 'Workshop.LocalMcp.dll'
& dotnet $server --validate
if ($LASTEXITCODE -ne 0) { throw 'FAIL local MCP client/server checks (expected HTTP N/A).' }
