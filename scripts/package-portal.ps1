#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$BundlePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'portal-dist'),
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.workshop/portal.zip')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
& node (Join-Path $PSScriptRoot 'portal-server.mjs') --verify $BundlePath
if ($LASTEXITCODE -ne 0) { throw 'Portal verification failed; no package was created.' }
$output = [IO.Path]::GetFullPath($OutputPath)
$directory = Split-Path $output -Parent
if (Test-Path -LiteralPath $output) { throw 'Refusing to overwrite an existing package. Choose a new private output path.' }
if (-not (Test-Path -LiteralPath $directory)) { [void](New-Item -ItemType Directory -Path $directory) }
if ((Get-Item -LiteralPath $directory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Package output directory must not be linked.'
}
$manifest = Get-Content -LiteralPath (Join-Path $BundlePath 'site-manifest.json') -Raw | ConvertFrom-Json
$paths = @($manifest.files.path) + 'server.mjs', 'site-manifest.json'
$stream = [IO.File]::Open($output, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($path in $paths) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $BundlePath $path),
                $path, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
Write-Output "PASS ZIP contains exactly $($paths.Count) allowlisted files, including the integrity manifest and reviewed server. No Azure command executed."
