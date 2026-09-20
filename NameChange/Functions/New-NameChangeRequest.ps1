function New-NameChangeRequest {
    [CmdletBinding()]
    param(
        # One row: SamAccountName, NewFirstName (optional), NewLastName (optional), NewUsername (optional), KeepOldEmail (optional)
        [Parameter(Mandatory)]
        [PSCustomObject]$Row,

        [string]$LogFile
    )

    # Old email addresses are kept as aliases unless someone explicitly says not to:
    # mail sent to the old address must keep arriving, or the person disappears to everyone outside
    $keepOld = if ($null -ne $Row.KeepOldEmail -and "$($Row.KeepOldEmail)".Trim()) {
        "$($Row.KeepOldEmail)".Trim() -notin @("No", "False", "0")
    } else { $true }

    $userObj = [pscustomobject]@{
        CorrelationId = [guid]::NewGuid().ToString()
        Raw    = [pscustomobject]@{
            SamAccountName = "$($Row.SamAccountName)".Trim()
            NewFirstName   = "$($Row.NewFirstName)".Trim()
            NewLastName    = "$($Row.NewLastName)".Trim()
            NewUsername    = "$($Row.NewUsername)".Trim()   # Blank = keep the current one
            KeepOldEmail   = $keepOld
        }
        Errors = [System.Collections.Generic.List[object]]::new()
        Plan   = @()
        Identity = $null
        Status  = "Pending"   # Renamed | NoChange | NotFound | Failed | Invalid | Pending
        StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
        StepDurations  = @{}
    }

    Write-Log -Message "[$($userObj.CorrelationId.Substring(0,8))] [New-NameChangeRequest] Request -> $($userObj.Raw.SamAccountName) : $($userObj.Raw.NewFirstName) $($userObj.Raw.NewLastName)" `
        -Level "INFO" -LogFile $LogFile

    return $userObj
}
