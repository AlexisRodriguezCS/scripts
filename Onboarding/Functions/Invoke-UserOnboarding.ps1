function Invoke-UserOnboarding {
    [CmdletBinding()]
    param(
        [string]$Path, # CSV path (bulk)
        [PSCustomObject[]]$Rows, # or rows built from parameters (single)
        [Parameter(Mandatory)]
        [string]$LogFile, # Log file path
        [Parameter(Mandatory)]
        [PSCustomObject]$Config, # Get config object
        [bool]$Apply
    )

    $pipelineStart = Get-Date

    # Call import function
    $users = if ($Rows) { Import-OnboardingCsv -Rows $Rows -LogFile $LogFile } else { Import-OnboardingCsv -Path $Path -LogFile $LogFile }

    Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile

    # Create all user(s) first
    $processed = @()

    foreach ($user in $users) {
        # 1. Convert data
        ConvertTo-OnboardingStandard -PipelineObject $user -LogFile $LogFile
        # 2. Validate data
        Test-OnboardingData -PipelineObject $user -LogFile $LogFile

        # User failed validation
        if ($user.Status -eq "Invalid") {
            Write-Log -Message "[$($user.CorrelationId)] [INVALID] Validation failed: $($user.Raw.FirstName) $($user.Raw.LastName)" `
                -Level "ERROR" -LogFile $LogFile
            continue
        }
        
        # 3. Apply policies
        Set-OnboardingPolicy -PipelineObject $user -Config $Config -LogFile $LogFile
        # 4. Plan onboarding actions
        New-OnboardingPlan -PipelineObject $user -LogFile $LogFile -Config $Config
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

        # Stop the run if the same failure keeps repeating (AD down, expired certificate, lost permission)
        $processed += $user
        if (Test-CircuitBreaker -Processed $processed -Config $Config -LogFile $LogFile) {
            foreach ($rest in $users | Where-Object Status -eq "Pending") { $rest.Status = "Stopped" }
            break
        }
    }

    $anyCreated = $users | Where-Object { $_.Status -eq "Created" }

    # Sync Once for all users
    if ($anyCreated) {
        # A failed sync is not fatal: WaitForEntra retries until the scheduled sync cycle picks the users up
        try { Invoke-EntraSync -Config $Config -LogFile $LogFile }
        catch { Write-Log -Message "$($_.Exception.Message) - relying on scheduled sync" -Level "WARN" -LogFile $LogFile }
    } else {
        Write-Log -Message "No new users created, skipping sync." -Level "INFO" -LogFile $LogFile
    }

    if ($Apply) {
        # Complete onboarding for each user
        $onboarded = @()

        foreach ($user in $users | Where-Object { $_.Status -in @("Created","AlreadyExists") }) {
            # Execute onboarding
            $null = Start-Onboarding -PipelineObject $user -LogFile $LogFile -Config $Config

            # Groups and licenses are the calls most likely to hit an outage, so the breaker runs here too
            $onboarded += $user
            if (Test-CircuitBreaker -Processed $onboarded -Config $Config -LogFile $LogFile) {
                # The accounts exist but never got their access, so they need attention too.
                # Users already onboarded keep Created / AlreadyExists, so skip the ones that ran.
                $handled = @($onboarded.CorrelationId)
                foreach ($rest in $users | Where-Object { $_.Status -in @("Created","AlreadyExists") -and $_.CorrelationId -notin $handled }) {
                    $rest.Status = "Stopped"
                }
                break
            }
        }
    }

    # Count from final status so failures in any step (validation, creation, onboarding) are included
    $successCount = @($users | Where-Object Status -eq "Created").Count
    $alreadyCount = @($users | Where-Object Status -eq "AlreadyExists").Count
    $failedCount  = @($users | Where-Object Status -in @("Failed","Invalid")).Count
    $stoppedCount = @($users | Where-Object Status -eq "Stopped").Count

    $pipelineDuration = (Get-Date) - $pipelineStart

    # Finish logging
    Write-Log -Message "
    === Pipeline Finished ===
    Total: $($users.Count)
    Created: $successCount
    Already Exists: $alreadyCount
    Failed: $failedCount
    Stopped: $stoppedCount
    Total Duration: $($pipelineDuration.TotalSeconds) sec
        " -Level "INFO" -LogFile $LogFile

    # Generate report
    $reportDir  = "$PSScriptRoot\..\..\Reports"
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\OnboardingReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $null = New-Report -Users $users -ReportFile $reportFile
    Write-Log -Message "Report generated: $reportFile" -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total        = $users.Count
        Created      = $successCount
        AlreadyExist = $alreadyCount
        Failed       = $failedCount
        Stopped      = $stoppedCount
        DurationSec  = $pipelineDuration.TotalSeconds
        Users        = @($users | ForEach-Object {
            [pscustomobject]@{
                Name     = "$($_.Raw.FirstName) $($_.Raw.LastName)"
                Username = $_.Identity.UserPrincipalName
                Status   = $_.Status
                Errors   = ($_.Errors | ForEach-Object { if ($_ -is [string]) { $_ } else { "$($_.Step): $($_.Exception)" } }) -join '; '
            }
        })
        Credentials  = @($users | Where-Object { $_.PSObject.Properties["TempPassword"] -or $_.PSObject.Properties["TemporaryAccessPass"] } | ForEach-Object {
            [pscustomobject]@{
                Name                = $_.Identity.DisplayName
                Username            = $_.Identity.UserPrincipalName
                TempPassword        = $_.TempPassword
                TemporaryAccessPass = $_.TemporaryAccessPass
            }
        })
    }
}
