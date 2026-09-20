function New-MoverPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "New-MoverPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        if ($PipelineObject.Status -ne "Valid") { return }

        $raw      = $PipelineObject.Raw
        $identity = $PipelineObject.Identity
        $plan     = @()

        # Only role groups are managed here; anything granted by hand (outside the prefix) is left alone
        $prefix = if ($Config.ManagedGroupPrefix) { $Config.ManagedGroupPrefix } else { "GRP_ROLE_" }

        # Action: attributes (title, department, manager) - only what changed
        $desired = @{ Title = $raw.Title; Department = $raw.Department }
        if ($identity.ManagerDN) { $desired.Manager = $identity.ManagerDN }
        $plan += @(Get-UserAttributeChanges -Current $identity.Current -Desired $desired)

        # Current role groups: name -> DN
        $currentGroups = @{}
        foreach ($dn in $identity.MemberOf) {
            $name = ($dn -split '(?<!\\),')[0] -replace '^CN='
            if ($name -like "$prefix*") { $currentGroups[$name] = $dn }
        }
        $desiredGroups = @($raw.ADGroups -split ';' | Where-Object { $_ -like "$prefix*" })

        # Action: add new access first, then remove old (no gap where they have neither)
        foreach ($group in $desiredGroups | Where-Object { -not $currentGroups.ContainsKey($_) }) {
            $plan += @{ Action = "AddToGroup"; Target = $group; Result = $null }
        }
        foreach ($group in $currentGroups.Keys | Where-Object { $_ -notin $desiredGroups }) {
            $plan += @{ Action = "RemoveFromGroup"; Target = $currentGroups[$group]; Result = $null }
        }

        # Action: move to the new department OU (after group changes: moving changes the DN)
        $targetOu  = "OU=$($raw.Department),$($Config.DefaultOU)"
        $currentOu = $identity.DistinguishedName -replace '^CN=.+?(?<!\\),'
        if ($currentOu -ne $targetOu) {
            $plan += @{ Action = "MoveToDepartmentOU"; Target = $targetOu; Result = $null }
        }

        # Action: the new role's license, when the client maps roles to licenses.
        # A promotion from a Business Basic role to an E3 role is otherwise done by hand and forgotten.
        if ($Config.RoleLicenseSkuIds) {
            $roleSku = $Config.RoleLicenseSkuIds.PSObject.Properties |
                       Where-Object { $_.Name -eq $raw.Role } | Select-Object -First 1
            if ($roleSku) {
                $plan += @{ Action = "SwitchLicense"; Target = $roleSku.Value; Result = $null }
            }
        }

        # Action: department / Managers DLs in Exchange Online (checked at run time, needs a connection)
        $managedLists = @($Config.DistributionLists | Where-Object { $_ -ne $Config.DefaultDistributionList })
        $desiredLists = @($raw.DistributionList -split ';' | Where-Object { $_ -in $managedLists })
        $plan += @{ Action = "SyncDistributionLists"; Target = ($desiredLists -join ';'); Result = $null }

        $PipelineObject.Plan = $plan

        # Log planned actions
        foreach ($item in $PipelineObject.Plan) {
            $detail = if ($item.Action -eq "SetAttribute") { "$($item.Target): '$($item.Old)' -> '$($item.Value)'" } else { $item.Target }
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($item.Action) -> $detail : PENDING" `
              -Level "INFO" -LogFile $LogFile
        }
    }
}
