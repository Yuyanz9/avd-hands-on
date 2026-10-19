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
