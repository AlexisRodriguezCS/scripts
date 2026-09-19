function Invoke-Audit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Checks,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile,

        # Leavers CSV, only for OffboardingCheck
        [string]$Path
    )

    $runStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir = "$PSScriptRoot\..\..\Reports"

    foreach ($check in $Checks) {
        Write-Log -Message "[Audit] $check : Started" -Level "INFO" -LogFile $LogFile

        # One failing check (e.g. missing permission) shouldn't stop the others
        try {
            $findings = @(switch ($check) {
                "Mfa"              { Get-MfaAudit -LogFile $LogFile }
                "AdminRoles"       { Get-AdminRoleAudit -Config $Config -LogFile $LogFile }
                "MailForwarding"   { Get-MailForwardingAudit -LogFile $LogFile }
                "AppCredentials"   { Get-AppCredentialAudit -Config $Config -LogFile $LogFile }
                "ConditionalAccess" { Get-ConditionalAccessAudit -BackupFolder "$PSScriptRoot\..\..\Backups\ConditionalAccess" -LogFile $LogFile }
                "EmailSecurity"    { Get-EmailSecurityAudit -LogFile $LogFile }
                "PrivilegedAccess" { Get-PrivilegedAccessAudit -Config $Config -LogFile $LogFile }
                "RiskyUsers"       { Get-RiskyUserAudit -LogFile $LogFile }
                "Groups"           { Get-GroupHygieneAudit -LogFile $LogFile }
                "SharedMailboxes"  { Get-SharedMailboxAudit -LogFile $LogFile }
                "ExternalSharing"  { Get-ExternalSharingAudit -Config $Config -LogFile $LogFile }
                "Licenses"         { Get-LicenseAudit -Config $Config -LogFile $LogFile }
                "AccessReview"     { Get-AccessReview -Config $Config -OutputFolder "$reportDir\AccessReview_$runStamp" -LogFile $LogFile }
                "OffboardingCheck" { Get-OffboardingCheck -Path $Path -Config $Config -LogFile $LogFile }
            })

            $summary = Export-AuditReport -Check $check -Findings $findings -ReportDir $reportDir -RunStamp $runStamp
            Write-Log -Message "[Audit] $check : $($summary.Checked) checked, $($summary.Flagged) need attention -> $($summary.ReportFile)" `
                      -Level $(if ($summary.Flagged) { "WARN" } else { "INFO" }) -LogFile $LogFile
            $summary
        }
        catch {
            Write-Log -Message "[Audit] $check : FAILED $($_.Exception.Message)" -Level "ERROR" -LogFile $LogFile
            [pscustomobject]@{ Check = $check; Checked = 0; Flagged = 0; ReportFile = $null; CsvFile = $null; Error = $_.Exception.Message }
        }
    }
}
