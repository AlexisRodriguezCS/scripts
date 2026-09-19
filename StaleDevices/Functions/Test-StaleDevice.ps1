function Test-StaleDevice {
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

    $stepName = "Test-StaleDevice"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config, $Now) -StepAction {
        param($PipelineObject, $LogFile, $Config, $Now)

        $raw = $PipelineObject.Raw

        # Kiosks, conference room PCs, spares in a drawer...
        if ($Config.ExcludeDevices -and $raw.DeviceName -in $Config.ExcludeDevices) {
            $PipelineObject.Status = "Excluded"
            return
        }

        $raw.DaysSinceSync = [int]($Now - [datetime]$raw.LastSync).TotalDays

        if ($raw.DaysSinceSync -ge $Config.RetireAfterDays) {
            $PipelineObject.Status = "Stale"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($raw.DeviceName) ($($raw.Owner)) : STALE - no check-in for $($raw.DaysSinceSync) days" `
                      -Level "INFO" -LogFile $LogFile
        } else {
            $PipelineObject.Status = "Active"
        }
    }
}
