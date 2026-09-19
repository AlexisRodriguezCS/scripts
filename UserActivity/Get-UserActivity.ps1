#Requires -Version 7.0
<#
    "My password doesn't work" / "I can't sign in": everything that happened to the account, in one timeline,
    with a plain-English summary on top. Read-only.

    Cloud / hybrid:  .\UserActivity\Get-UserActivity.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Days 30
    On-prem only:    .\UserActivity\Get-UserActivity.ps1 -Client "ClientB" -SamAccountName jdoe
                     (clients whose config has "Environment": "OnPrem"; AD only, no Entra)
#>
[CmdletBinding(DefaultParameterSetName = "Cloud")]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory, ParameterSetName = "Cloud")]
    [string]$UserPrincipalName,

    [Parameter(Mandatory, ParameterSetName = "OnPrem")]
    [string]$SamAccountName,

    # Entra keeps sign-in and audit logs for 30 days (P1/P2)
    [ValidateRange(1, 30)]
    [int]$Days = 14
)

Import-Module "$PSScriptRoot\UserActivity.psm1" -Force

$Config  = Get-Config -Script "UserActivity" -Client $Client -RootPath "$PSScriptRoot\.."
$onPrem  = $Config.Environment -eq "OnPrem"

if ($onPrem -and -not $SamAccountName) { throw "$Client is on-prem only: use -SamAccountName" }

$required = if ($onPrem) { @("ActiveDirectory") } else { @("Microsoft.Graph") }
foreach ($module in $required) {
    if (-Not (Get-Module -ListAvailable -Name $module)) { throw "Missing module: $module" }
}

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\UserActivity.log"

if ($onPrem) {
    $result = Invoke-UserActivityReport -SamAccountName $SamAccountName -OnPremOnly -Days $Days -LockoutServer $Config.LockoutServer -LogFile $LogFile
} else {
    Connect-MgGraph -TenantId $Config.TenantId -ClientId $Config.ClientId -CertificateThumbprint $Config.CertThumbprint -NoWelcome
    $result = Invoke-UserActivityReport -UserPrincipalName $UserPrincipalName -Days $Days -LockoutServer $Config.LockoutServer -LogFile $LogFile
}

Write-Host "`n=== $($result.User) ===" -ForegroundColor Cyan
$result.Summary | ForEach-Object { Write-Host "- $_" }
Write-Host "`nFull timeline ($($result.Events) events): $($result.ReportFile)"
