function Invoke-TrainingAzureCli {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $PSNativeCommandUseErrorActionPreference = $false
    $output = & az @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Azure CLI failed (exit $exitCode): az $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    $output
}

function Restore-TrainingEnvironment {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Values
    )

    foreach ($key in $Values.Keys) {
        if ($null -eq $Values[$key]) {
            # An originally absent variable is not the same as an empty variable.
            $path = "Env:\$key"
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path
            }
        } else {
            [Environment]::SetEnvironmentVariable($key, $Values[$key], 'Process')
        }
    }
}

function Assert-TrainingResourceGroup {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory)]
        [string]$NamePrefix
    )

    $json = Invoke-TrainingAzureCli -Arguments @(
        'group', 'show', '--name', $ResourceGroupName,
        '--subscription', $SubscriptionId, '--query', 'tags',
        '--output', 'json', '--only-show-errors'
    )
    $tags = ($json -join [Environment]::NewLine) | ConvertFrom-Json -AsHashtable
    if ($null -eq $tags -or $tags['training'] -ne 'avd-hands-on' -or $tags['participant'] -ne $NamePrefix) {
        throw "Resource group '$ResourceGroupName' is not this participant's training group. Use a new dedicated group; existing unrelated groups will not be changed."
    }
}
