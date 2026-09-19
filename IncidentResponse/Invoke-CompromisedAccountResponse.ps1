#Requires -Version 7.0
<#
    Someone got phished: collect evidence, then lock the account down. IT runs this by hand.

    Evidence only (safe, changes nothing):
      .\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com
    Contain:
      .\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory)]
    [string]$UserPrincipalName,

    # How far back to pull sign-ins
    [ValidateRange(1, 30)]
    [int]$SignInDays = 7,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\IncidentResponse.psm1" -Force

foreach ($module in @("Microsoft.Graph", "ExchangeOnlineManagement")) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

$Config = Get-Config -Script "IncidentResponse" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\IncidentResponse.log"

# ------------------------
# AUTHENTICATE (evidence needs Graph + Exchange even without -Apply)
# ------------------------
Connect-MgGraph -TenantId $Config.TenantId -ClientId $Config.ClientId -CertificateThumbprint $Config.CertThumbprint -NoWelcome
Connect-ExchangeOnline -AppId $Config.ClientId -CertificateThumbprint $Config.CertThumbprint -Organization $Config.TenantDomain -ShowBanner:$false

$result = Invoke-IncidentResponse -UserPrincipalName $UserPrincipalName -LogFile $LogFile -SignInDays $SignInDays -Apply $Apply.IsPresent
$result

# Always tell the team: an incident is never routine
$state = if ($Apply) { $result.Status } else { "evidence collected, NOT contained yet" }
Send-Alert -Config $Config -LogFile $LogFile -Title "Security incident ($Client): $UserPrincipalName $state" `
           -Message ((($result.FollowUp | ForEach-Object { "- $_" }) -join "`n") + "`nEvidence: $($result.Evidence)")

if ($result.Status -eq "Failed") { exit 1 }
