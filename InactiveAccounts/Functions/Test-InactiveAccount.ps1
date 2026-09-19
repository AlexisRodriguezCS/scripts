function Test-InactiveAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        # Injectable for tests
        [datetime]$Now = (Get-Date)
    )

    $stepName = "Test-InactiveAccount"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config, $Now) -StepAction {
        param($PipelineObject, $LogFile, $Config, $Now)

        $raw = $PipelineObject.Raw

        # Break-glass, service and shared accounts are never touched
        if ($raw.UPN -in @($Config.ExcludeAccounts)) {
            $PipelineObject.Status = "Excluded"
            return
        }

        $threshold = if ($raw.UserType -eq "Guest") { $Config.GuestInactiveDays } else { $Config.MemberInactiveDays }

        # Never signed in: count from when the account was created (so brand new hires aren't caught)
        if ($raw.LastSignIn) {
            $raw.DaysInactive = [int]($Now - [datetime]$raw.LastSignIn).TotalDays
            $raw.Reason = "No sign-in for $($raw.DaysInactive) days"
        } else {
            $raw.DaysInactive = [int]($Now - [datetime]$raw.CreatedDate).TotalDays
            $raw.Reason = "Never signed in (created $($raw.DaysInactive) days ago)"
        }

        if ($raw.DaysInactive -ge $threshold) {
            $PipelineObject.Status = "Inactive"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($raw.UPN) ($($raw.UserType)) : INACTIVE - $($raw.Reason)" `
                      -Level "INFO" -LogFile $LogFile
        } else {
            $PipelineObject.Status = "Active"
        }
    }
}
