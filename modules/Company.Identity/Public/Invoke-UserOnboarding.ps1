function Invoke-UserOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path # CSV path
    )

    Write-LogAndVerbose -Message "=== Pipeline started. ===" -Level "INFO"

    # Call import function
    $users = Import-OnboardingCsv -Path $Path

    Write-LogAndVerbose -Message "== Starting looping over users. ==" -Level "INFO"
    # Loop through users
    foreach ($user in $users) {

        # Convert data
        $user = ConvertTo-OnboardingStandard -PipelineObject $user

        # Validate data
        $user = Test-OnboardingData -PipelineObject $user

        # User has errors and will be skipped
        if ($user.Errors.Count -gt 0) {
            Write-LogAndVerbose -Message "User processed with errors: $($user.Raw.FirstName) $($user.Raw.LastName) will be skipped" -Level "WARN"
            continue
        }
        
        # User was successfully processed
        Write-LogAndVerbose -Message "User processed successfully: $($user.Raw.FirstName) $($user.Raw.LastName)" -Level "INFO"
    }

    Write-LogAndVerbose -Message "== Finished looping over users. ==" -Level "INFO"

    # Finish logging
    Write-LogAndVerbose -Message "=== Pipeline finished. Total users: $($users.Count) ===" -Level "INFO"
}
