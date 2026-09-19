function Get-MoverIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "Get-MoverIdentity"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        if ($PipelineObject.Status -ne "Valid") { return }

        $id  = $PipelineObject.CorrelationId.Substring(0,8)
        $raw = $PipelineObject.Raw

        # Look up the user (read-only, runs in dry run too)
        try {
            $adUser = Get-ADUser -Filter "SamAccountName -eq '$($raw.SamAccountName)'" `
                                 -Properties DisplayName, Title, Department, Manager, MemberOf -ErrorAction Stop
        }
        catch {
            throw "AD lookup failed: $($_.Exception.Message)"
        }

        if (-not $adUser) {
            $PipelineObject.Status = "NotFound"
            Write-Log -Message "[$id] [$stepName] Lookup -> $($raw.SamAccountName) : NOT_FOUND" -Level "WARN" -LogFile $LogFile
            return
        }

        # New manager comes in as a SamAccountName; AD stores it as a DN
        $managerDn = $null
        if ($raw.Manager) {
            $manager = Get-ADUser -Filter "SamAccountName -eq '$($raw.Manager)'" -ErrorAction Stop
            if (-not $manager) {
                $PipelineObject.Errors.Add("Manager $($raw.Manager) not found in AD")
                $PipelineObject.Status = "Invalid"
                Write-Log -Message "[$id] [$stepName] Manager -> $($raw.Manager) : NOT_FOUND" -Level "WARN" -LogFile $LogFile
                return
            }
            $managerDn = $manager.DistinguishedName
        }

        $PipelineObject.Identity = [PSCustomObject]@{
            SamAccountName    = $raw.SamAccountName
            DisplayName       = $adUser.DisplayName
            DistinguishedName = $adUser.DistinguishedName
            EntraUPN          = "$($raw.SamAccountName)@$($Config.TenantDomain)"  # Same format New-OnboardingIdentity assigns
            MemberOf          = @($adUser.MemberOf)
            ManagerDN         = $managerDn
            Current           = $adUser
        }

        Write-Log -Message "[$id] [$stepName] Lookup -> $($raw.SamAccountName) : FOUND ($($adUser.DistinguishedName))" -Level "INFO" -LogFile $LogFile
    }
}
