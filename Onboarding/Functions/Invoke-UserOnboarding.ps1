function Invoke-UserOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path, # CSV path
        [string]$LogFile, # Log file path
        [PSCustomObject]$Config # Get config object
    )

    Write-Log -Message "=== Pipeline started. ===" -Level "INFO" -LogFile $LogFile

    # Call import function
    $users = Import-OnboardingCsv -Path $Path -LogFile $LogFile

    $successCount = 0
    $failedCount = 0
    $alreadyCount = 0
    $skippedCount = 0

    Write-Log -Message "== Starting looping over users. ==" -Level "INFO" -LogFile $LogFile

    # Loop through users
    foreach ($user in $users) {

        # Convert data
        $user = ConvertTo-OnboardingStandard -PipelineObject $user

        # Validate data
        $user = Test-OnboardingData -LogFile $LogFile -PipelineObject $user 

        # User has errors and will be skipped
        if ($user.Status -eq "Skipped") {
            $skippedCount++
            Write-Log -Message "[SKIP] User processed with errors: $($user.Raw.FirstName) $($user.Raw.LastName) will be skipped" -Level "WARN" -LogFile $LogFile
            # Log line break
            Write-Log -Message " " -LogFile $LogFile
            continue
        }
        
        # Apply policies
        $user = Set-OnboardingPolicy -PipelineObject $user -Config $Config -LogFile $LogFile

        # # Plan onboarding actions
        $user = New-OnboardingPlan -PipelineObject $user -LogFile $LogFile

        # # Build onboarding data
        $user = New-OnboardingIdentity -PipelineObject $user -LogFile $LogFile -Config $Config

        # # Execute onboarding
        $user = Start-Onboarding -PipelineObject $user -LogFile $LogFile -Config $Config

        switch ($user.Status) {
            "Created"       { $successCount++ }
            "AlreadyExists" { $alreadyCount++ }
            "Failed"        { $failedCount++ }
        }

        # Log line break
        Write-Log -Message " " -LogFile $LogFile
    }

    Write-Log -Message "== Finished looping over users. ==" -Level "INFO" -LogFile $LogFile

    # Finish logging
    Write-Log -Message "
    === Pipeline Finished ===
    Total: $($users.Count)
    Created: $successCount
    Already Exists: $alreadyCount
    Failed: $failedCount
    Skipped (Validation): $skippedCount
        " -Level "INFO" -LogFile $LogFile
}
