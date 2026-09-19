function Get-OffboardingIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "Get-OffboardingIdentity"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        # Only proceed if validation passed
        if ($PipelineObject.Status -ne "Valid") {
            Write-Log -Message "[SKIP] Identity lookup skipped due to validation state: $($PipelineObject.Status)" `
                      -Level "WARN" -LogFile $LogFile
            return
        }

        $id  = $PipelineObject.CorrelationId.Substring(0,8)
        $sam = $PipelineObject.Raw.SamAccountName

        # Look up the user in AD (read-only, runs in dry run too)
        try {
            $adUser = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties DisplayName, MemberOf, adminCount -ErrorAction Stop
        }
        catch {
            throw "AD lookup failed: $($_.Exception.Message)"
        }

        if (-not $adUser) {
            $PipelineObject.Status = "NotFound"
            Write-Log -Message "[$id] [$stepName] Lookup -> $sam : NOT_FOUND" -Level "WARN" -LogFile $LogFile
            return
        }

        # Admins and VIPs can't be offboarded from a request; IT has to do it by hand
        $protected = Test-ProtectedAccount -AdUser $adUser -Config $Config
        if ($protected) {
            $PipelineObject.Errors.Add($protected)
            $PipelineObject.Status = "Invalid"
            Write-Log -Message "[$id] [$stepName] Lookup -> $sam : PROTECTED" -Level "WARN" -LogFile $LogFile
            return
        }

        # Store Identity object
        $PipelineObject.Identity = [PSCustomObject]@{
            SamAccountName    = $sam
            DisplayName       = $adUser.DisplayName
            DistinguishedName = $adUser.DistinguishedName
            MemberOf          = @($adUser.MemberOf)
            EntraUPN          = Resolve-EntraUpn -SamAccountName $sam -AdUpn $adUser.UserPrincipalName -Config $Config
        }

        Write-Log -Message "[$id] [$stepName] Lookup -> $sam : FOUND ($($adUser.DistinguishedName))" -Level "INFO" -LogFile $LogFile
    }
}
