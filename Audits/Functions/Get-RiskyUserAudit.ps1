function Get-RiskyUserAudit {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    # Entra ID Protection's own verdict (needs Entra ID P2): leaked credentials, impossible travel, unfamiliar sign-ins...
    $risky = @(Get-MgRiskyUser -All -Filter "riskState eq 'atRisk' or riskState eq 'confirmedCompromised'" -ErrorAction Stop)

    foreach ($user in $risky) {
        $state = "$($user.RiskState)"
        $level = "$($user.RiskLevel)"

        $reason = if ($state -eq "confirmedCompromised") { "Confirmed compromised: run the compromised account response" }
                  elseif ($level -in @("high", "medium")) { "At risk ($level): check recent sign-ins, consider the compromised account response" }
                  else { "At risk (low): review when convenient" }

        New-AuditFinding -Check "RiskyUsers" -Name $user.UserPrincipalName `
                         -Detail "Risk: $level | State: $state | Updated: $($user.RiskLastUpdatedDateTime)" `
                         -Flagged $true -Reason $reason
    }
}
