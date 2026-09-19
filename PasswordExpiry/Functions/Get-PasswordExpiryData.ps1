function Get-PasswordExpiryData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [string]$LogFile
    )

    Write-Log -Message "[Get-PasswordExpiryData] Fetching users with expiring passwords from AD" -Level "DEBUG" -LogFile $LogFile

    $searchBase = if ($Config.SearchBase) { @{ SearchBase = $Config.SearchBase } } else { @{} }

    $users = Get-ADUser @searchBase -Filter "Enabled -eq 'True' -and PasswordNeverExpires -eq 'False'" `
                       -Properties DisplayName, mail, "msDS-UserPasswordExpiryTimeComputed" -ErrorAction Stop

    # Build pipeline objects
    $pipelineObjects = foreach ($user in $users) {
        $raw = $user."msDS-UserPasswordExpiryTimeComputed"

        # 0 = must change at next logon, max value = never expires; nothing to remind about
        if (-not $raw -or $raw -eq [long]::MaxValue) { continue }

        [pscustomobject]@{
            CorrelationId = [guid]::NewGuid().ToString()
            Raw    = [pscustomobject]@{
                SamAccountName = $user.SamAccountName
                DisplayName    = $user.DisplayName
                Mail           = $user.mail
                ExpiresOn      = [datetime]::FromFileTime($raw)
                DaysLeft       = $null
                Threshold      = $null   # Which reminder this is (14, 7, 1 days)
                SentKey        = $null
            }
            Errors = [System.Collections.Generic.List[object]]::new()
            Plan   = @()
            Identity = $null
            Status  = "Pending"   # NotDue | Due | AlreadySent | Expired | Sent | Invalid | Failed
            StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
            StepDurations  = @{}
        }
    }

    Write-Log -Message "[Get-PasswordExpiryData] Fetched $(@($pipelineObjects).Count) users" -Level "INFO" -LogFile $LogFile

    return $pipelineObjects
}
