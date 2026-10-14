#requires -Version 7.4
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Write-Output 'PASS no Azure resources or persistent tool data created by module 01 (expected HTTP N/A).'
Write-Output 'MANUAL CHECK: stop workshop-local in MCP: List Servers; stop Inspector with Ctrl+C in its terminal.'
Write-Output 'MANUAL CHECK: you may leave workshop-local configured but stopped; do not remove other servers.'
Write-Output 'KEEP private module 00 parameters and Terraform state. This script does not delete files or stop unrelated processes.'
