function Test-MoverData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "Test-MoverData"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        $raw = $PipelineObject.Raw
        $samPattern = '^[^"/\\\[\]:;|=,+*?<>@'' ]{1,20}$'

        if ($raw.SamAccountName -notmatch $samPattern) { $PipelineObject.Errors.Add("SamAccountName is missing or invalid") }
        if ($raw.Manager -and $raw.Manager -notmatch $samPattern) { $PipelineObject.Errors.Add("Manager must be a SamAccountName") }

        foreach ($field in "Title", "Department", "Role") {
            if ([string]::IsNullOrWhiteSpace($raw.$field)) { $PipelineObject.Errors.Add("$field is missing") }
        }

        # Department must be a real one (it becomes the OU and the department DL); use the configured spelling
        if ($Config.Departments -and $raw.Department) {
            $match = $Config.Departments | Where-Object { $_ -eq $raw.Department }
            if ($match) { $raw.Department = @($match)[0] }
            else { $PipelineObject.Errors.Add("Department '$($raw.Department)' is not one of: $($Config.Departments -join ', ')") }
        }

        # Log success if no errors or log warnings if there are errors
        if ($PipelineObject.Errors.Count -eq 0) {
            $PipelineObject.Status = "Valid"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Validation -> $($raw.SamAccountName): Valid" `
                      -Level "INFO" -LogFile $LogFile
        } else {
            $PipelineObject.Status = "Invalid"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Validation -> $($raw.SamAccountName): Invalid $($PipelineObject.Errors -join ', ')" `
                      -Level "WARN" -LogFile $LogFile
        }
    }
}
