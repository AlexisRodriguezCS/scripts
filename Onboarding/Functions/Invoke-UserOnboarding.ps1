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

    $successCount = 0
    $failedCount = 0
    $alreadyCount = 0
    $skippedCount = 0

    # Loop through users
    foreach ($user in $users) {

        # Convert data
        $user = ConvertTo-OnboardingStandard -PipelineObject $user

        # Validate data
        $user = Test-OnboardingData -PipelineObject $user

        # User has errors and will be skipped
        if ($user.Status -eq "Skipped") {
            $skippedCount++
            Write-LogAndVerbose -Message "[SKIP] User processed with errors: $($user.Raw.FirstName) $($user.Raw.LastName) will be skipped" -Level "WARN"
            # Log line break
            Write-LogAndVerbose -Message " "
            continue
        }
        
        # Apply policies
        $user = Set-OnboardingPolicy -PipelineObject $user

        # Plan onboarding actions
        $user = New-OnboardingPlan -PipelineObject $user

        # Build onboarding data
        $user = New-OnboardingIdentity -PipelineObject $user

        # Execute onboarding
        $user = Start-Onboarding -PipelineObject $user

        switch ($user.Status) {
            "Created"       { $successCount++ }
            "AlreadyExists" { $alreadyCount++ }
            "Failed"        { $failedCount++ }
        }

        # Log line break
        Write-LogAndVerbose -Message " "
    }

    Write-LogAndVerbose -Message "== Finished looping over users. ==" -Level "INFO"

    # Finish logging
    Write-LogAndVerbose -Message "
    === Pipeline Finished ===
    Total: $($users.Count)
    Created: $successCount
    Already Exists: $alreadyCount
    Failed: $failedCount
    Skipped (Validation): $skippedCount
        " -Level "INFO"
}
