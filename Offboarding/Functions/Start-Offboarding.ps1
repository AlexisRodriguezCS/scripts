function Start-Offboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $correlationId = $PipelineObject.CorrelationId.Substring(0,8)
    $sam           = $PipelineObject.Raw.SamAccountName

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-Log -Message "[$correlationId] [Offboarding] SKIP → $sam : Status $($PipelineObject.Status)" `
            -Level "WARN" -LogFile $LogFile
        return $PipelineObject
    }

    # Retry configurations
    $retryConfig = @{
        DisableAccount     = @{ MaxRetries = 3; DelaySeconds = 5 }
        RemoveFromGroup    = @{ MaxRetries = 3; DelaySeconds = 5 }
        MoveToDisabledOU   = @{ MaxRetries = 3; DelaySeconds = 5 }
        RevokeSessions     = @{ MaxRetries = 4; DelaySeconds = 5 }
        ConvertMailbox     = @{ MaxRetries = 3; DelaySeconds = 10 }
        SetAutoReply       = @{ MaxRetries = 3; DelaySeconds = 5 }
        GrantMailboxAccess = @{ MaxRetries = 3; DelaySeconds = 5 }
        ShareOneDrive      = @{ MaxRetries = 3; DelaySeconds = 10 }
        RemoveLicenses     = @{ MaxRetries = 4; DelaySeconds = 5 }
    }

    foreach ($actionItem in $PipelineObject.Plan) {
        $action = $actionItem.Action
        $target = $actionItem.Target

        # Initialize result
        $actionItem.Result = $null

        if (-not $retryConfig.ContainsKey($action)) {
            Add-PipelineError -PipelineObject $PipelineObject `
                              -Step $action `
                              -Message "Unknown action: $action" `
                              -LogFile $LogFile

            Write-Log -Message "[$correlationId] [Offboarding] $action -> $target : FAILED (unknown action)" `
                -Level "ERROR" -LogFile $LogFile

            return $PipelineObject
        }

        $retryParams = $retryConfig[$action]
        $attempt = 0
        $success = $false

        while (-not $success -and $attempt -lt $retryParams.MaxRetries) {
            $attempt++
            try {
                # Call action function
                $identity = $PipelineObject.Identity
                $result = switch ($action) {
                    "DisableAccount"     { Disable-OffboardingAccount -Identity $identity -LogFile $LogFile }
                    "RemoveFromGroup"    { Remove-OffboardingGroupMember -Identity $identity -Target $target -LogFile $LogFile }
                    "MoveToDisabledOU"   { Move-OffboardingUser -Identity $identity -Target $target -LogFile $LogFile }
                    "RevokeSessions"     { Revoke-OffboardingSession -Identity $identity -LogFile $LogFile }
                    "ConvertMailbox"     { Convert-OffboardingMailbox -Identity $identity -LogFile $LogFile }
                    "SetAutoReply"       { Set-OffboardingAutoReply -Identity $identity -Target $target -Config $Config -LogFile $LogFile }
                    "GrantMailboxAccess" { Grant-OffboardingMailboxAccess -Identity $identity -Target $target -LogFile $LogFile }
                    "ShareOneDrive"      { Grant-OffboardingOneDriveAccess -Identity $identity -Target $target -LogFile $LogFile }
                    "RemoveLicenses"     { Remove-OffboardingLicense -Identity $identity -LogFile $LogFile }
                }

                # Results for reporting
                $actionItem.Result = switch ($result) {
                    "Removed"       { "Removed from $target" }
                    "NotMember"     { "Not in $target" }
                    "AlreadyShared" { "Already shared" }
                    "NoMailbox"     { "No mailbox" }
                    "NoLicenses"    { "No licenses" }
                    "NoOneDrive"    { "No OneDrive" }
                    default         { $result }
                }

                $success = $true

                # Single-line log per action
                Write-Log -Message "[$correlationId] [Offboarding] $action -> $target : $($actionItem.Result)" `
                          -Level "INFO" -LogFile $LogFile
            }
            catch {
                # Retry logging
                if ($attempt -lt $retryParams.MaxRetries) {
                    Write-Log -Message "[$correlationId] [Offboarding] $action -> $target : RETRY ($attempt)" `
                        -Level "WARN" -LogFile $LogFile
                    $delay = ($retryParams.DelaySeconds * $attempt) + (Get-Random -Minimum 1 -Maximum 3)
                    Start-Sleep -Seconds $delay
                } else {
                    # All retries exhausted → mark structured pipeline error
                    Add-PipelineError -PipelineObject $PipelineObject `
                                    -Step $action `
                                    -Message "Failed during $action → $target" `
                                    -Exception $_.Exception `
                                    -LogFile $LogFile

                    $actionItem.Result = "Failed"
                    Write-Log -Message "[$correlationId] [Offboarding] $action -> $target : FAILED" `
                        -Level "ERROR" -LogFile $LogFile
                }
            }
        }

        # Abort if the account could not be disabled; don't strip access from a still-active account
        if ($action -eq "DisableAccount" -and -not $success) {
            Write-Log -Message "[$correlationId] [Offboarding] DisableAccount -> $sam : FAILED (aborting)" `
                -Level "ERROR" -LogFile $LogFile

            return $PipelineObject
        }
    }

    $PipelineObject.Status = if ($PipelineObject.Errors.Count -gt 0) { "Failed" } else { "Offboarded" }

    return $PipelineObject
}
