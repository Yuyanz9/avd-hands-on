#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'templates')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'AzureCli.ps1')
Get-Command az -ErrorAction Stop | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

foreach ($phase in @('network', 'avd')) {
    Invoke-TrainingAzureCli -Arguments @(
        'bicep', 'build',
        '--file', (Join-Path $root "infra\$phase.bicep"),
        '--outfile', (Join-Path $OutputDirectory "$phase.json"),
        '--only-show-errors'
    ) | Out-Host
}

Write-Host 'Built Network and AVD ARM JSON. No Azure resources were deployed.'
