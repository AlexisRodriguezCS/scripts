function Get-InactiveAccountData {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    Write-Log -Message "[Get-InactiveAccountData] Fetching enabled users from Entra" -Level "DEBUG" -LogFile $LogFile

    # signInActivity needs Entra ID P1 and AuditLog.Read.All
    $users = Get-MgUser -All -Filter "accountEnabled eq true" `
        -Property "id,displayName,userPrincipalName,userType,createdDateTime,signInActivity,onPremisesSyncEnabled,onPremisesSamAccountName" `
        -ErrorAction Stop

    # Build pipeline objects
    $pipelineObjects = foreach ($user in $users) {
        $activity = $user.SignInActivity

        # Latest of any sign-in type (interactive, non-interactive, successful)
        $lastSignIn = @($activity.LastSuccessfulSignInDateTime, $activity.LastSignInDateTime, $activity.LastNonInteractiveSignInDateTime) |
                      Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1

        [pscustomobject]@{
            CorrelationId = [guid]::NewGuid().ToString()
            Raw    = [pscustomobject]@{
                SamAccountName = if ($user.OnPremisesSyncEnabled) { $user.OnPremisesSamAccountName } else { $user.UserPrincipalName }  # Name shown in reports
                Id             = $user.Id
                UPN            = $user.UserPrincipalName
                DisplayName    = $user.DisplayName
                UserType       = $user.UserType          # Member | Guest
                Synced         = [bool]$user.OnPremisesSyncEnabled
                OnPremSam      = $user.OnPremisesSamAccountName
                CreatedDate    = $user.CreatedDateTime
                LastSignIn     = $lastSignIn
                DaysInactive   = $null
                Reason         = $null
            }
            Errors = [System.Collections.Generic.List[object]]::new()
            Plan   = @()
            Identity = [pscustomobject]@{ SamAccountName = $user.OnPremisesSamAccountName; EntraUPN = $user.UserPrincipalName }
            Status  = "Pending"   # Active | Excluded | Inactive | Disabled | Removed | Failed
            StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
            StepDurations  = @{}
        }
    }

    Write-Log -Message "[Get-InactiveAccountData] Fetched $(@($pipelineObjects).Count) enabled users" -Level "INFO" -LogFile $LogFile

    return $pipelineObjects
}
