#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$readme = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw
$repo = 'Yuyanz9/avd-hands-on'
$buttons = [ordered]@{
    network = 'network.json'
    'network-validation' = 'network-validation.json'
    avd = 'avd.json'
    'session-host' = 'session-host.json'
}
$portalUriPrefix = 'https://portal.azure.com/#create/Microsoft.Template/uri/'

foreach ($button in $buttons.GetEnumerator()) {
    $pattern = "(?s)<!-- deploy-button-$([regex]::Escape($button.Key)):start -->(?<content>.*?)<!-- deploy-button-$([regex]::Escape($button.Key)):end -->"
    $blocks = [regex]::Matches($readme, $pattern)
    if ($blocks.Count -ne 1) {
        throw "Expected exactly one README deploy-button block for '$($button.Key)'."
    }

    $links = [regex]::Matches($blocks[0].Groups['content'].Value, '\]\((?<url>https://portal\.azure\.com/#create/Microsoft\.Template/uri/[^)]+)\)')
    if ($links.Count -ne 1) {
        throw "Expected exactly one Azure deploy link in the '$($button.Key)' block."
    }

    $portalUrl = $links[0].Groups['url'].Value
    $templateUrl = [Uri]::UnescapeDataString($portalUrl.Substring($portalUriPrefix.Length))
    $expectedUrl = "https://raw.githubusercontent.com/$repo/main/templates/$($button.Value)"
    if ($templateUrl -cne $expectedUrl) {
        throw "Deploy button '$($button.Key)' must reference '$expectedUrl'; found '$templateUrl'."
    }

    $templatePath = Join-Path $root "templates\$($button.Value)"
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Deploy template not found: $templatePath"
    }

    Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json | Out-Null
    Write-Host "Validated deploy button '$($button.Key)' -> '$($button.Value)'."
}
