#Requires -Version 7.0
<#
    Email users before their password expires (14, 7 and 1 days by default).
    Meant to run once a day on a schedule. Safe to run more often: each reminder is only sent once.

    Preview:     .\PasswordExpiry\PasswordExpiry.ps1 -Client "ClientA"
    Send emails: .\PasswordExpiry\PasswordExpiry.ps1 -Client "ClientA" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\PasswordExpiry.psm1" -Force

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
foreach ($module in @("ActiveDirectory", "Microsoft.Graph")) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

$Config = Get-Config -Script "PasswordExpiry" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\$($Config.LogPath)"

# ------------------------
# AUTHENTICATE
# ------------------------
if ($Apply) {
    Connect-MgGraph -TenantId $Config.TenantId `
                    -ClientId $Config.ClientId `
                    -CertificateThumbprint $Config.CertThumbprint `
                    -NoWelcome
}

$result = Invoke-PasswordExpiryReminder -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent `
                                        -SentLogPath "$PSScriptRoot\Logs\SentReminders_$Client.json"
$result

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Password reminders ($Client): needs attention" `
               -Message "Failed or no email: $($result.Failed). Report: $($result.ReportFile)"
    exit 1
}
