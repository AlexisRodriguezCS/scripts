#Requires -Version 7.0
<#
    Warn people before their mailbox is full (default 80%, 90%, 95%). Runs daily; each warning is sent once a month at most.

    Preview:     .\MailboxQuota\MailboxQuota.ps1 -Client "ClientA"
    Send emails: .\MailboxQuota\MailboxQuota.ps1 -Client "ClientA" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\MailboxQuota.psm1" -Force

foreach ($module in @("ExchangeOnlineManagement", "Microsoft.Graph")) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

$Config = Get-Config -Script "MailboxQuota" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\MailboxQuota.log"

# ------------------------
# AUTHENTICATE (Exchange to read sizes; Graph only needed to send)
# ------------------------
Connect-ExchangeOnline -AppId $Config.ClientId -CertificateThumbprint $Config.CertThumbprint -Organization $Config.TenantDomain -ShowBanner:$false
if ($Apply) {
    Connect-MgGraph -TenantId $Config.TenantId -ClientId $Config.ClientId -CertificateThumbprint $Config.CertThumbprint -NoWelcome
}

$result = Invoke-MailboxQuotaWarning -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent `
                                     -SentLogPath "$PSScriptRoot\Logs\SentWarnings_$Client.json"
$result

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Mailbox size warnings ($Client): needs attention" `
               -Message "Failed: $($result.Failed). Report: $($result.ReportFile)"
    exit 1
}
