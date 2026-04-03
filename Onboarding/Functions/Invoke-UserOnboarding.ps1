function Invoke-UserOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path, # CSV path
        [Parameter(Mandatory)]
        [string]$LogFile, # Log file path
        [Parameter(Mandatory)]
        [PSCustomObject]$Config # Get config object
    )

    $pipelineStart = Get-Date

    Write-Log -Message "=== Pipeline started. ===" -Level "INFO" -LogFile $LogFile

    # Call import function
    $users = Import-OnboardingCsv -Path $Path -LogFile $LogFile

    $successCount = 0
    $failedCount = 0
    $alreadyCount = 0
    $skippedCount = 0

    # Create all user(s) first
    foreach ($user in $users) {

        # 1. Convert data
        ConvertTo-OnboardingStandard -PipelineObject $user -LogFile $LogFile
        # 2. Validate data
        Test-OnboardingData -PipelineObject $user -LogFile $LogFile

        # User has errors and will be skipped
        if ($user.Status -eq "Skipped") {
            $skippedCount++
            Write-Log -Message "[$($user.CorrelationId)] [SKIP] User processed with errors: $($user.Raw.FirstName) $($user.Raw.LastName)" `
                -Level "WARN" -LogFile $LogFile
            Write-Log -Message " " -LogFile $LogFile
            continue
        }
        
        # 3. Apply policies
        Set-OnboardingPolicy -PipelineObject $user -Config $Config -LogFile $LogFile
        # 4. Plan onboarding actions
        New-OnboardingPlan -PipelineObject $user -LogFile $LogFile
        # 5. Build onboarding data
        New-OnboardingIdentity -PipelineObject $user -LogFile $LogFile -Config $Config
        # 6. Create user
        New-OnboardingUser -PipelineObject $user -LogFile $LogFile

        # Log line break
        Write-Log -Message " " -LogFile $LogFile
    }

    # # Sync Once for all users
    # $anyCreated = $users | Where-Object { $_.Status -eq "Created" }

    # if ($anyCreated) {
    #     Write-Log -Message "== Syncing to Entra. ==" -Level "INFO" -LogFile $LogFile
    #     Invoke-EntraSync -Config $Config -LogFile $LogFile
    # } else {
    #     Write-Log -Message "== No new users created, skipping sync. ==" -Level "INFO" -LogFile $LogFile
    # }

    # Complete onboarding for each user
    foreach ($user in $users | Where-Object { $_.Status -in @("Created","AlreadyExists") }) {

        # Execute onboarding
        Start-Onboarding -PipelineObject $user -LogFile $LogFile -Config $Config

        if ($user.Status -eq "Failed") {
            $failedCount++
            Write-Log -Message "[$($user.CorrelationId)] [FAIL] Onboarding failed: $($user.Raw.FirstName) $($user.Raw.LastName)" `
                -Level "ERROR" -LogFile $LogFile
            Write-Log -Message " " -LogFile $LogFile
            continue
        }

        switch ($user.Status) {
            "Created"       { $successCount++ }
            "AlreadyExists" { $alreadyCount++ }
        }

        Write-Log -Message "" -LogFile $LogFile
    }

    $pipelineDuration = (Get-Date) - $pipelineStart

    # Finish logging
    Write-Log -Message "
    === Pipeline Finished ===
    Total: $($users.Count)
    Created: $successCount
    Already Exists: $alreadyCount
    Failed: $failedCount
    Skipped (Validation): $skippedCount
    Total Duration: $($pipelineDuration.TotalSeconds) sec
        " -Level "INFO" -LogFile $LogFile
}
