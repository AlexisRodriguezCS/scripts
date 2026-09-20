function Revoke-IncidentAppConsent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Consents this user personally gave to apps. Attackers get a user to approve a "document
    # viewer" that asks for Mail.Read and offline_access: that app keeps reading their mail
    # with its own refresh token, so disabling the account and killing sessions isn't enough.
    $grants = @($PipelineObject.Evidence.Grants)
    if (-not $grants.Count) { return "NoAppConsents" }

    foreach ($grant in $grants) {
        Remove-MgOauth2PermissionGrant -OAuth2PermissionGrantId $grant.Id -ErrorAction Stop
        Write-Log -Message "[$($PipelineObject.Identity.EntraUPN)] [Revoke-IncidentAppConsent] Revoked $($grant.Scope) granted to app $($grant.ClientId)" `
                  -Level "INFO" -LogFile $LogFile
    }

    return "Revoked $($grants.Count) app consent(s)"
}
