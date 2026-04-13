function Import-OnboardingCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$LogFile
    )

    Write-Log -Message "[Import-OnboardingCsv] Import -> File : Started ($Path)" -Level "DEBUG" -LogFile $LogFile

    # Check file exists
    if (-Not (Test-Path $Path)) {
        Write-Log -Message "CSV not found: $Path" -Level "ERROR" -LogFile $LogFile
        throw "CSV file not found"
    }

    # Import CSV
    $csv = Import-Csv -Path $Path

    # Build pipeline objects
    $pipelineObjects = foreach ($row in $csv) {
        $userObj = [pscustomobject]@{
            CorrelationId = [guid]::NewGuid().ToString()
            Raw    = [pscustomobject]@{
            FirstName        = $row.FirstName
            LastName         = $row.LastName
            Title            = $row.Title
            Manager          = $row.Manager
            Location         = $row.Location
            Department       = $row.Department
            Role             = $row.Role
            EmploymentType   = $row.EmploymentType
            StartDate        = $row.StartDate
            DistributionList = $null 
            ADGroups         = $null
            License          = $null
        }
            Errors = [System.Collections.Generic.List[object]]::new()       # Errors will go here
            Plan   = @()        # Actions planned for execution
            Identity = $null      # Identity object 
            Status  = "Pending"     # Created | AlreadyExists | Failed | Skipped | Pending
            StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
            StepDurations  = @{}
        }

        Write-Log -Message "[$($userObj.CorrelationId.Substring(0,8))] [Import-OnboardingCsv] Import -> $($row.FirstName) $($row.LastName) : Imported" -Level "INFO" -LogFile $LogFile
        
        # Add object to pipelineObjects
        $userObj
    }

    Write-Log -Message "[Import-OnboardingCsv] Import -> File : Completed (Total: $($pipelineObjects.Count))" -Level "DEBUG" -LogFile $LogFile

    # Return pipelineObjects for next stage
    return $pipelineObjects
}
