#Requires -Version 7.0
<#
    Read-only security, cost and compliance checks. Nothing is changed.

    Everything:        .\Audits\Audit.ps1 -Client "ClientA"
    One check:         .\Audits\Audit.ps1 -Client "ClientA" -Check Licenses
    Offboarding check: .\Audits\Audit.ps1 -Client "ClientA" -Check OffboardingCheck -Path .\leavers.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [ValidateSet("All", "Mfa", "AdminRoles", "MailForwarding", "AppCredentials", "ConditionalAccess", "EmailSecurity", "PrivilegedAccess", "RiskyUsers", "Groups", "SharedMailboxes", "Licenses", "AccessReview", "OffboardingCheck")]
    [string[]]$Check = "All",

    # Leavers CSV (SamAccountName), for OffboardingCheck
    [string]$Path
)

Import-Module "$PSScriptRoot\Audits.psm1" -Force

$Config = Get-Config -Script "Audits" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\$($Config.LogPath)"

# "All" = every check that doesn't need extra input
$checks = if ($Check -contains "All") {
    @("Mfa", "AdminRoles", "MailForwarding", "AppCredentials", "ConditionalAccess", "EmailSecurity", "PrivilegedAccess", "RiskyUsers", "Groups", "SharedMailboxes", "Licenses", "AccessReview") + $(if ($Path) { "OffboardingCheck" })
} else { $Check }

if ("OffboardingCheck" -in $checks -and -not $Path) {
    throw "OffboardingCheck needs -Path to a CSV of leavers (SamAccountName column)"
}

# ------------------------
# AUTHENTICATE (only what the chosen checks need)
# ------------------------
Connect-MgGraph -TenantId $Config.TenantId `
                -ClientId $Config.ClientId `
                -CertificateThumbprint $Config.CertThumbprint `
                -NoWelcome

if ($checks | Where-Object { $_ -in @("MailForwarding", "SharedMailboxes") }) {
    Connect-ExchangeOnline -AppId $Config.ClientId `
                           -CertificateThumbprint $Config.CertThumbprint `
                           -Organization $Config.TenantDomain `
                           -ShowBanner:$false
}

$results = @(Invoke-Audit -Checks $checks -Config $Config -LogFile $LogFile -Path $Path)
$results | Format-Table Check, Checked, Flagged, ReportFile -AutoSize | Out-Host

$flagged = @($results | Where-Object { $_.Flagged -gt 0 -or $_.Error })
if ($flagged) {
    $summary = ($flagged | ForEach-Object { if ($_.Error) { "$($_.Check): failed ($($_.Error))" } else { "$($_.Check): $($_.Flagged)" } }) -join "`n"
    Send-Alert -Config $Config -LogFile $LogFile -Title "Audit ($Client): needs attention" -Message $summary
    exit 1
}
