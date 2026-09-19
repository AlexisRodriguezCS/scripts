function Get-UserAttributesIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "Get-UserAttributesIdentity"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        # Only proceed if validation passed
        if ($PipelineObject.Status -ne "Valid") { return }

        $id      = $PipelineObject.CorrelationId.Substring(0,8)
        $sam     = $PipelineObject.Raw.SamAccountName
        $changes = $PipelineObject.Raw.Changes

        # Look up the user in AD with every attribute we might change (read-only, runs in dry run too)
        try {
            $adUser = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties ($script:ManagedUserAttributes + "DisplayName") -ErrorAction Stop
        }
        catch {
            throw "AD lookup failed: $($_.Exception.Message)"
        }

        if (-not $adUser) {
            $PipelineObject.Status = "NotFound"
            Write-Log -Message "[$id] [$stepName] Lookup -> $sam : NOT_FOUND" -Level "WARN" -LogFile $LogFile
            return
        }

        # Manager comes in as a SamAccountName; AD stores it as a DN
        if ($changes.ContainsKey("Manager")) {
            $manager = Get-ADUser -Filter "SamAccountName -eq '$($changes.Manager)'" -ErrorAction Stop
            if (-not $manager) {
                $PipelineObject.Errors.Add("Manager $($changes.Manager) not found in AD")
                $PipelineObject.Status = "Invalid"
                Write-Log -Message "[$id] [$stepName] Manager -> $($changes.Manager) : NOT_FOUND" -Level "WARN" -LogFile $LogFile
                return
            }
            $changes.Manager = $manager.DistinguishedName
        }

        # Store Identity object (Current keeps the before values for the plan)
        $PipelineObject.Identity = [PSCustomObject]@{
            SamAccountName    = $sam
            DisplayName       = $adUser.DisplayName
            DistinguishedName = $adUser.DistinguishedName
            EntraUPN          = Resolve-EntraUpn -SamAccountName $sam -AdUpn $adUser.UserPrincipalName -Config $Config
            Current           = $adUser
        }

        Write-Log -Message "[$id] [$stepName] Lookup -> $sam : FOUND ($($adUser.DistinguishedName))" -Level "INFO" -LogFile $LogFile
    }
}
