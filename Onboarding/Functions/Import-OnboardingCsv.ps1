function Import-OnboardingCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Write-LogAndVerbose -Message "== Starting CSV import: $Path ==" -Level "INFO"

    # Check file exists
    if (-Not (Test-Path $Path)) {
        Write-LogAndVerbose -Message "CSV not found: $Path" -Level "ERROR"
        throw "CSV file not found: $Path"
    }

    # Import CSV
    $csv = Import-Csv -Path $Path

    # Build pipeline objects
    $pipelineObjects = foreach ($row in $csv) {
        $userObj = [pscustomobject]@{
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
            Errors = @()        # Validation errors will go here
            Plan   = @()        # Actions planned for execution
            Identity = $null      # Identity object 
            Status  = $null     # Created | AlreadyExists | Failed | Skipped
        }

        Write-LogAndVerbose -Message "Imported user: $($row.FirstName) $($row.LastName)" -Level "INFO"
        
        # Add object to pipelineObjects
        $userObj
    }

    Write-LogAndVerbose -Message "== CSV import finished. Total users: $($pipelineObjects.Count) ==" -Level "INFO"

    # Return pipelineObjects for next stage
    return $pipelineObjects
}
