function Set-UserLogonName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Already renamed by an earlier run
    $existing = Get-ADUser -Filter "SamAccountName -eq '$($Identity.NewSamAccountName)'" -ErrorAction SilentlyContinue
    if ($existing) { return "AlreadyRenamed" }

    # Both names change together: SamAccountName is what old systems use,
    # UserPrincipalName is what Microsoft 365 uses to sign in
    Set-ADUser -Identity $Identity.DistinguishedName `
               -SamAccountName $Identity.NewSamAccountName `
               -UserPrincipalName $Identity.NewUpn `
               -ErrorAction Stop

    Write-Log -Message "[Set-UserLogonName] $($Identity.SamAccountName) -> $($Identity.NewSamAccountName): the old username stops working, tell them before they next sign in" `
              -Level "WARN" -LogFile $LogFile

    return "Signs in as $($Identity.NewUpn)"
}
