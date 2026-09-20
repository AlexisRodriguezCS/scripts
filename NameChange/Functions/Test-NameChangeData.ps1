function Test-NameChangeData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "Test-NameChangeData"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        $raw        = $PipelineObject.Raw
        $samPattern = '^[^"/\\\[\]:;|=,+*?<>@'' ]{1,20}$'

        if ($raw.SamAccountName -notmatch $samPattern) {
            $PipelineObject.Errors.Add("SamAccountName is missing or invalid")
        }

        if (-not $raw.NewFirstName -and -not $raw.NewLastName -and -not $raw.NewUsername) {
            $PipelineObject.Errors.Add("Nothing to change: give a new first name, last name or username")
        }

        # Names go into the display name and the AD object name, which reject these characters
        foreach ($field in "NewFirstName", "NewLastName") {
            if ($raw.$field -and $raw.$field -match '[,\\#+<>;"=]') {
                $PipelineObject.Errors.Add("$field can't contain , \ # + < > ; "" or =")
            }
        }

        if ($raw.NewUsername -and $raw.NewUsername -notmatch $samPattern) {
            $PipelineObject.Errors.Add("NewUsername is invalid or longer than 20 characters")
        }

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
