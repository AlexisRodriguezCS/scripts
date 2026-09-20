function Get-NameChangeIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "Get-NameChangeIdentity"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        if ($PipelineObject.Status -ne "Valid") { return }

        $id  = $PipelineObject.CorrelationId.Substring(0,8)
        $raw = $PipelineObject.Raw
        $sam = $raw.SamAccountName

        try {
            $adUser = Get-ADUser -Filter "SamAccountName -eq '$sam'" `
                                 -Properties GivenName, Surname, DisplayName, EmailAddress, proxyAddresses, adminCount, MemberOf -ErrorAction Stop
        }
        catch {
            throw "AD lookup failed: $($_.Exception.Message)"
        }

        if (-not $adUser) {
            $PipelineObject.Status = "NotFound"
            Write-Log -Message "[$id] [$stepName] Lookup -> $sam : NOT_FOUND" -Level "WARN" -LogFile $LogFile
            return
        }

        # Admins and VIPs aren't renamed from a request; IT does those by hand
        $protected = Test-ProtectedAccount -AdUser $adUser -Config $Config
        if ($protected) {
            $PipelineObject.Errors.Add($protected)
            $PipelineObject.Status = "Invalid"
            Write-Log -Message "[$id] [$stepName] Lookup -> $sam : PROTECTED" -Level "WARN" -LogFile $LogFile
            return
        }

        # What the name becomes: only the parts that were given change
        $newFirst = if ($raw.NewFirstName) { $raw.NewFirstName } else { $adUser.GivenName }
        $newLast  = if ($raw.NewLastName)  { $raw.NewLastName }  else { $adUser.Surname }

        # A new username has to be free, or two people end up fighting over it
        if ($raw.NewUsername -and $raw.NewUsername -ne $sam) {
            $taken = Get-ADUser -Filter "SamAccountName -eq '$($raw.NewUsername)'" -ErrorAction SilentlyContinue
            if ($taken) {
                $PipelineObject.Errors.Add("Username $($raw.NewUsername) is already taken by someone else")
                $PipelineObject.Status = "Invalid"
                Write-Log -Message "[$id] [$stepName] Username -> $($raw.NewUsername) : TAKEN" -Level "WARN" -LogFile $LogFile
                return
            }
        }

        $newSam = if ($raw.NewUsername) { $raw.NewUsername } else { $sam }

        $PipelineObject.Identity = [PSCustomObject]@{
            SamAccountName    = $sam
            NewSamAccountName = $newSam
            DistinguishedName = $adUser.DistinguishedName
            EntraUPN          = Resolve-EntraUpn -SamAccountName $sam -AdUpn $adUser.UserPrincipalName -Config $Config
            FirstName         = $newFirst
            LastName          = $newLast
            DisplayName       = "$newFirst $newLast"
            # UPN suffix stays whatever the account already has
            NewUpn            = "$newSam$($adUser.UserPrincipalName -replace '^[^@]+')"
            Current           = $adUser
        }

        Write-Log -Message "[$id] [$stepName] Lookup -> $sam : FOUND ($($adUser.DisplayName) -> $($PipelineObject.Identity.DisplayName))" `
                  -Level "INFO" -LogFile $LogFile
    }
}
