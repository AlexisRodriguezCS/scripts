function Invoke-UserOnboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path, # CSV path
        [Parameter(Mandatory)]
        [string]$LogFile, # Log file path
        [Parameter(Mandatory)]
        [PSCustomObject]$Config, # Get config object
        [bool]$Apply
    )

    $pipelineStart = Get-Date

    # Call import function
    $users = Import-OnboardingCsv -Path $Path -LogFile $LogFile

    $successCount = 0
    $failedCount = 0
    $alreadyCount = 0

    Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile

    # Create all user(s) first
    foreach ($user in $users) {
        # 1. Convert data
        ConvertTo-OnboardingStandard -PipelineObject $user -LogFile $LogFile
        # 2. Validate data
        Test-OnboardingData -PipelineObject $user -LogFile $LogFile

        # User failed validation
        if ($user.Status -eq "Invalid") {
            $failedCount++
            Write-Log -Message "[$($user.CorrelationId)] [INVALID] Validation failed: $($user.Raw.FirstName) $($user.Raw.LastName)" `
                -Level "ERROR" -LogFile $LogFile
            continue
        }
        
        # 3. Apply policies
        Set-OnboardingPolicy -PipelineObject $user -Config $Config -LogFile $LogFile
        # 4. Plan onboarding actions
        New-OnboardingPlan -PipelineObject $user -LogFile $LogFile
        # 5. Build onboarding data
        New-OnboardingIdentity -PipelineObject $user -LogFile $LogFile -Config $Config
        # 6. Create user
        if ($Apply) {
            New-OnboardingUser -PipelineObject $user -LogFile $LogFile
        } else {
            Write-Log -Message "[$($user.CorrelationId)] [DRY RUN] Not creating user: $($user.Raw.FirstName) $($user.Raw.LastName)" `
                -Level "INFO" -LogFile $LogFile
        }
        # Log line break
        Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile
    }

    $anyCreated = $users | Where-Object { $_.Status -eq "Created" }

    # Sync Once for all users
    if ($anyCreated) {
        Invoke-EntraSync -Config $Config -LogFile $LogFile
    } else {
        Write-Log -Message "No new users created, skipping sync." -Level "INFO" -LogFile $LogFile
    }

    if ($Apply) {
        # Complete onboarding for each user
        foreach ($user in $users | Where-Object { $_.Status -in @("Created","AlreadyExists") }) {
            # Execute onboarding
            Start-Onboarding -PipelineObject $user -LogFile $LogFile -Config $Config

            switch ($user.Status) {
                "Failed"        { $failedCount++ }
                "Created"       { $successCount++ }
                "AlreadyExists" { $alreadyCount++ }
            }
        }
    }

    $pipelineDuration = (Get-Date) - $pipelineStart

    # Finish logging
    Write-Log -Message "
    === Pipeline Finished ===
    Total: $($users.Count)
    Created: $successCount
    Already Exists: $alreadyCount
    Failed: $failedCount
    Total Duration: $($pipelineDuration.TotalSeconds) sec
        " -Level "INFO" -LogFile $LogFile

    # Generate report
    $reportFile = "$PSScriptRoot\..\..\Reports\OnboardingReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $null = New-Report -Users $users -ReportFile $reportFile
    Write-Log -Message "Report generated: $reportFile" -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total        = $users.Count
        Created      = $successCount
        AlreadyExist = $alreadyCount
        Failed       = $failedCount
        DurationSec  = $pipelineDuration.TotalSeconds
    }
}
