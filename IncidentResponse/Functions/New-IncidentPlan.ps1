function New-IncidentPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [string]$LogFile
    )

    $identity = $PipelineObject.Identity
    $evidence = $PipelineObject.Evidence
    $plan = @()

    # Lock out first: disable, new password nobody knows, kill every session
    $plan += @{ Action = "DisableAccount"; Target = $identity.EntraUPN; Result = $null }
    $plan += @{ Action = "ResetPassword";  Target = $identity.EntraUPN; Result = $null }
    $plan += @{ Action = "RevokeSessions"; Target = $identity.EntraUPN; Result = $null }

    # Apps the user consented to keep their own refresh tokens: revoking sessions doesn't stop them,
    # so a "document viewer" with Mail.Read carries on reading mail after the account is disabled
    if ($evidence.Grants.Count) {
        $plan += @{ Action = "RevokeAppConsents"; Target = "$($evidence.Grants.Count) app consent(s)"; Result = $null }
    }

    # Then stop email leaving
    if ($evidence.Forwarding) {
        $plan += @{ Action = "RemoveForwarding"; Target = ($evidence.Forwarding -join ', '); Result = $null }
    }

    # Rules that forward, redirect, delete, or hide mail in folders nobody checks (classic attacker moves).
    # Disabled, not deleted, so they stay as evidence.
    $hiddenFolders = "RSS Feeds|RSS Subscriptions|Conversation History|Archive|Junk"
    foreach ($rule in $evidence.Rules | Where-Object Enabled) {
        $suspicious = $rule.ForwardTo -or $rule.RedirectTo -or $rule.ForwardAsAttachmentTo -or $rule.DeleteMessage -or
                      ("$($rule.MoveToFolder)" -match $hiddenFolders)
        if ($suspicious) {
            $plan += @{ Action = "DisableInboxRule"; Target = $rule.Name; RuleIdentity = "$($rule.Identity)"; Result = $null }
        }
    }

    $PipelineObject.Plan = $plan

    foreach ($item in $plan) {
        Write-Log -Message "[$($identity.EntraUPN)] [New-IncidentPlan] $($item.Action) -> $($item.Target) : PENDING" -Level "INFO" -LogFile $LogFile
    }
}
