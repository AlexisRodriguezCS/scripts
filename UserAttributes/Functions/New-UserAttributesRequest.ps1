function New-UserAttributesRequest {
    [CmdletBinding()]
    param(
        # One row: SamAccountName + any managed attribute columns (empty values are ignored)
        [Parameter(Mandatory)]
        [PSCustomObject]$Row,

        [string]$LogFile
    )

    # Only attributes that were actually given a value
    $changes = @{}
    foreach ($property in $Row.PSObject.Properties) {
        if ($property.Name -ne "SamAccountName" -and -not [string]::IsNullOrWhiteSpace("$($property.Value)")) {
            $changes[$property.Name] = "$($property.Value)"
        }
    }

    # Same pipeline object shape as the other scripts
    $userObj = [pscustomobject]@{
        CorrelationId = [guid]::NewGuid().ToString()
        Raw    = [pscustomobject]@{
            SamAccountName = "$($Row.SamAccountName)".Trim()
            Changes        = $changes
        }
        Errors = [System.Collections.Generic.List[object]]::new()       # Errors will go here
        Plan   = @()          # Actions planned for execution
        Identity = $null      # Identity object (looked up from AD)
        Status  = "Pending"   # Updated | NoChange | NotFound | Failed | Invalid | Pending
        StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
        StepDurations  = @{}
    }

    Write-Log -Message "[$($userObj.CorrelationId.Substring(0,8))] [New-UserAttributesRequest] Request -> $($userObj.Raw.SamAccountName) : $($changes.Keys -join ', ')" `
        -Level "INFO" -LogFile $LogFile

    return $userObj
}
