function New-MoverRequest {
    [CmdletBinding()]
    param(
        # One row: SamAccountName, Title, Department, Role, Manager (optional), EmploymentType (optional)
        [Parameter(Mandatory)]
        [PSCustomObject]$Row,

        [string]$LogFile
    )

    $employmentType = if ("$($Row.EmploymentType)".Trim()) { "$($Row.EmploymentType)".Trim() } else { "Regular Full-Time" }

    # Same pipeline object shape as onboarding, so Set-OnboardingPolicy can decide the new access
    $userObj = [pscustomobject]@{
        CorrelationId = [guid]::NewGuid().ToString()
        Raw    = [pscustomobject]@{
            SamAccountName   = "$($Row.SamAccountName)".Trim()
            Title            = "$($Row.Title)".Trim()
            Department       = "$($Row.Department)".Trim()
            Role             = "$($Row.Role)".Trim()
            Manager          = "$($Row.Manager)".Trim()   # New manager's SamAccountName (optional)
            EmploymentType   = $employmentType
            DistributionList = $null     # Filled by Set-OnboardingPolicy
            ADGroups         = $null
            License          = $null
        }
        Errors = [System.Collections.Generic.List[object]]::new()
        Plan   = @()
        Identity = $null
        Status  = "Pending"   # Moved | NotFound | Failed | Invalid | Pending
        StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
        StepDurations  = @{}
    }

    Write-Log -Message "[$($userObj.CorrelationId.Substring(0,8))] [New-MoverRequest] Request -> $($userObj.Raw.SamAccountName) : $($userObj.Raw.Department) / $($userObj.Raw.Title) / $($userObj.Raw.Role)" `
        -Level "INFO" -LogFile $LogFile

    return $userObj
}
