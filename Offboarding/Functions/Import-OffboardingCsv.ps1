function Import-OffboardingCsv {
    [CmdletBinding()]
    param(
        # Bulk: CSV path
        [Parameter(Mandatory, ParameterSetName = "Bulk")]
        [string]$Path,
        # Single: rows already built from parameters
        [Parameter(Mandatory, ParameterSetName = "Rows")]
        [PSCustomObject[]]$Rows,
        [string]$LogFile
    )

    if ($PSCmdlet.ParameterSetName -eq "Rows") {
        $csv = $Rows
    }
    else {
        Write-Log -Message "[Import-OffboardingCsv] Import -> File : Started ($Path)" -Level "DEBUG" -LogFile $LogFile

        # Check file exists
        if (-Not (Test-Path $Path)) {
            Write-Log -Message "CSV not found: $Path" -Level "ERROR" -LogFile $LogFile
            throw "CSV file not found"
        }

        # Import CSV
        $csv = Import-Csv -Path $Path
    }

    # Build pipeline objects
    $pipelineObjects = foreach ($row in $csv) {
        $userObj = [pscustomobject]@{
            CorrelationId = [guid]::NewGuid().ToString()
            Raw    = [pscustomobject]@{
                SamAccountName = "$($row.SamAccountName)".Trim()
                Manager        = "$($row.Manager)".Trim()     # Optional: supervisor UPN, gets mailbox + OneDrive access
            }
            Errors = [System.Collections.Generic.List[object]]::new()       # Errors will go here
            Plan   = @()          # Actions planned for execution
            Identity = $null      # Identity object (looked up from AD)
            Status  = "Pending"   # Offboarded | NotFound | Failed | Invalid | Pending
            StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
            StepDurations  = @{}
        }

        Write-Log -Message "[$($userObj.CorrelationId.Substring(0,8))] [Import-OffboardingCsv] Import -> $($userObj.Raw.SamAccountName) : Imported" -Level "INFO" -LogFile $LogFile

        # Add object to pipelineObjects
        $userObj
    }

    Write-Log -Message "[Import-OffboardingCsv] Import -> File : Completed (Total: $(@($pipelineObjects).Count))" -Level "DEBUG" -LogFile $LogFile

    # Return pipelineObjects for next stage
    return $pipelineObjects
}
