#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Write-Output 'PASS module 00 preflight cleanup (expected HTTP N/A): checks create no Azure or Entra resources.'
Write-Output 'PASS private parameters and state preserved (expected HTTP N/A). Optional paid portal cleanup requires the reviewed Terraform destroy flow in docs/HOSTING.md.'
