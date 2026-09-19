function New-OffboardingPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "New-OffboardingPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        # Nothing to plan for users that failed validation or don't exist
        if ($PipelineObject.Status -ne "Valid") { return }

        $identity = $PipelineObject.Identity
        $plan = @()

        # Action: Disable account first so the user loses access immediately
        $plan += @{ Action = "DisableAccount"; Target = $identity.SamAccountName; Result = $null }

        # Action: Kill M365 sessions right away (AD disable only reaches Entra on the next sync)
        $plan += @{ Action = "RevokeSessions"; Target = $identity.EntraUPN; Result = $null }

        # Action: Remove company data from their phones and laptops (Intune retire)
        $plan += @{ Action = "RetireDevices"; Target = $identity.EntraUPN; Result = $null }

        # Action: Remove from every AD group (logged in the plan so they can be restored)
        foreach ($group in $identity.MemberOf) {
            $plan += @{ Action = "RemoveFromGroup"; Target = $group; Result = $null }
        }

        # Action: Move to disabled OU (skip if already there)
        if ($identity.DistinguishedName -notlike "*,$($Config.DisabledOU)") {
            $plan += @{ Action = "MoveToDisabledOU"; Target = $Config.DisabledOU; Result = $null }
        }

        # Action: Remove from cloud distribution lists (onboarding adds these in Exchange Online, not AD)
        $plan += @{ Action = "RemoveFromDistributionLists"; Target = $identity.EntraUPN; Result = $null }

        # Action: Convert mailbox to shared (must happen BEFORE license removal or the mailbox is deleted)
        $plan += @{ Action = "ConvertMailbox"; Target = $identity.EntraUPN; Result = $null }

        # Action: Out of office pointing senders to the manager (or the default contact)
        $contact = if ($PipelineObject.Raw.Manager) { $PipelineObject.Raw.Manager } else { $Config.DefaultContact }
        $plan += @{ Action = "SetAutoReply"; Target = $contact; Result = $null }

        # Action: Hand the manager the mailbox and OneDrive
        if ($PipelineObject.Raw.Manager) {
            $plan += @{ Action = "GrantMailboxAccess"; Target = $PipelineObject.Raw.Manager; Result = $null }
            $plan += @{ Action = "ShareOneDrive"; Target = $PipelineObject.Raw.Manager; Result = $null }
        }

        # Action: Remove all licenses
        # Action: Hide from the address book (after mailbox handoff: the manager still has access, new senders can't find them)
        $plan += @{ Action = "HideFromAddressBook"; Target = $identity.EntraUPN; Result = $null }

        $plan += @{ Action = "RemoveLicenses"; Target = $identity.EntraUPN; Result = $null }

        $PipelineObject.Plan = $plan

        # Log planned actions
        foreach ($item in $PipelineObject.Plan) {
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($item.Action) -> $($item.Target) : PENDING" `
              -Level "INFO" -LogFile $LogFile
        }
    }
}
