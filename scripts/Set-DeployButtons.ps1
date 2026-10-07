#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$Repository,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$TemplateCommit,

    [ValidatePattern('^([A-Za-z0-9._-]+/)*[A-Za-z0-9._-]*$')]
    [string]$TemplatePathPrefix = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$readmePath = Join-Path $root 'README.md'
$linksPath = Join-Path $root 'resources\deploy-links.json'
$readme = Get-Content -LiteralPath $readmePath -Raw
$manifest = Get-Content -LiteralPath $linksPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$TemplateCommit = $TemplateCommit.ToLowerInvariant()
$prefix = $TemplatePathPrefix.Trim('/')
$segments = @($prefix -split '/')
if ($segments -contains '.' -or $segments -contains '..') {
    throw 'TemplatePathPrefix must not contain dot path segments.'
}
if ($prefix) {
    $prefix += '/'
}

foreach ($phase in @('network', 'avd')) {
    $template = Join-Path $root "templates\$phase.json"
    if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
        throw "Missing compiled template: $template. Run Build-Templates.ps1 first."
    }
    $entry = @($manifest.links | Where-Object { $_.phase -eq $phase })
    if ($entry.Count -ne 1) {
        throw "Expected one link entry for $phase."
    }
    $uri = "https://raw.githubusercontent.com/$Repository/$TemplateCommit/${prefix}templates/$phase.json"
    $buttonUri = 'https://portal.azure.com/#create/Microsoft.Template/uri/' + [uri]::EscapeDataString($uri)
    $start = "<!-- deploy-button-${phase}:start -->"
    $end = "<!-- deploy-button-${phase}:end -->"
    if ([regex]::Matches($readme, [regex]::Escape($start)).Count -ne 1 -or
        [regex]::Matches($readme, [regex]::Escape($end)).Count -ne 1) {
        throw "Expected exactly one start and end marker for $phase."
    }
    $pattern = [regex]::Escape($start) + '.*?' + [regex]::Escape($end)
    $matches = [regex]::Matches($readme, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($matches.Count -ne 1) {
        throw "Expected exactly one managed README button region for $phase."
    }
    $replacement = "$start`n[![Deploy to Azure](https://aka.ms/deploytoazurebutton)]($buttonUri)`n$end"
    $readme = [regex]::Replace(
        $readme, $pattern, $replacement,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $entry[0].templateUri = $uri
    $entry[0].deployToAzureUrl = $buttonUri
    $entry[0].localTemplateSha256 = (Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash
}

$manifest.status = 'fixed-templates-with-configured-urls-not-live-validated'
$manifest.publication = @{
    repository = $Repository
    templateCommit = $TemplateCommit
    templatePathPrefix = $prefix.TrimEnd('/')
    rawUrlsVerified = $false
}
Set-Content -LiteralPath $readmePath -Value $readme.TrimEnd() -Encoding utf8
$manifest | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $linksPath -Encoding utf8
Write-Host 'Updated local README buttons. No repository was created or pushed, and URL availability has not been verified.'
