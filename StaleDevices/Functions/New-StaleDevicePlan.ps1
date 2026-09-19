function New-StaleDevicePlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "New-StaleDevicePlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        if ($PipelineObject.Status -ne "Stale") { return }

        $raw = $PipelineObject.Raw

        # Very old: the device is gone, remove the record. Otherwise: retire (removes company data on next check-in).
        # A retire already sent (retirePending) isn't sent again.
        $action = if ($raw.DaysSinceSync -ge $Config.DeleteAfterDays) { "DeleteRecord" }
                  elseif ($raw.ManagementState -ne "retirePending") { "Retire" }

        if (-not $action) {
            $PipelineObject.Status = "Active"   # nothing left to do until it's old enough to delete
            return
        }

        $PipelineObject.Plan = @(@{ Action = $action; Target = $raw.DeviceName; Result = $null })

        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $action -> $($raw.DeviceName) : PENDING ($($raw.DaysSinceSync) days)" `
                  -Level "INFO" -LogFile $LogFile
    }
}
