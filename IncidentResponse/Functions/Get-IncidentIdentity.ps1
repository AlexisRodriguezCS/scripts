function Get-IncidentIdentity {
    [CmdletBinding()]
    param(
        # Entra sign-in name of the compromised account
        [Parameter(Mandatory)]
        [string]$UserPrincipalName,

        [string]$LogFile
    )

    $user = Get-MgUser -UserId $UserPrincipalName `
        -Property "id,displayName,userPrincipalName,accountEnabled,onPremisesSyncEnabled,onPremisesSamAccountName" `
        -ErrorAction Stop

    # Same pipeline object shape as the other scripts
    [pscustomobject]@{
        CorrelationId = [guid]::NewGuid().ToString()
        Raw    = [pscustomobject]@{
            SamAccountName = if ($user.OnPremisesSyncEnabled) { $user.OnPremisesSamAccountName } else { $user.UserPrincipalName }
            UserPrincipalName = $user.UserPrincipalName
        }
        Identity = [pscustomobject]@{
            Id             = $user.Id
            DisplayName    = $user.DisplayName
            EntraUPN       = $user.UserPrincipalName
            Synced         = [bool]$user.OnPremisesSyncEnabled             # Synced users must be disabled/reset in AD
            SamAccountName = $user.OnPremisesSamAccountName
        }
        Evidence = $null
        Errors   = [System.Collections.Generic.List[object]]::new()
        Plan     = @()
        Status   = "Valid"   # Contained | Failed | Valid (dry run)
        StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
        StepDurations  = @{}
    }
}
