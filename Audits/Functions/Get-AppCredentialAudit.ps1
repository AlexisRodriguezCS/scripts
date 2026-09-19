function Get-AppCredentialAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [string]$LogFile,
        # Injectable for tests
        [datetime]$Now = (Get-Date)
    )

    $warningDays = if ($Config.CredentialWarningDays) { $Config.CredentialWarningDays } else { 30 }

    $apps = Get-MgApplication -All -Property "id,appId,displayName,passwordCredentials,keyCredentials" -ErrorAction Stop

    foreach ($app in $apps) {
        # Secrets (passwords) and certificates both expire
        $credentials = @($app.PasswordCredentials | ForEach-Object { @{ Type = "Secret"; Name = $_.DisplayName; End = $_.EndDateTime } }) +
                       @($app.KeyCredentials      | ForEach-Object { @{ Type = "Certificate"; Name = $_.DisplayName; End = $_.EndDateTime } })

        foreach ($credential in $credentials) {
            $daysLeft = [int]([datetime]$credential.End - $Now).TotalDays

            $reason = if ($daysLeft -lt 0) { "Expired $(-$daysLeft) days ago" }
                      elseif ($daysLeft -le $warningDays) { "Expires in $daysLeft days" }

            New-AuditFinding -Check "AppCredentials" -Name $app.DisplayName `
                             -Detail "$($credential.Type) '$($credential.Name)' expires $(([datetime]$credential.End).ToString('yyyy-MM-dd'))" `
                             -Flagged ([bool]$reason) -Reason $reason
        }
    }
}
