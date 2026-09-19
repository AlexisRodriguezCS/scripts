#Requires -Version 7.0
<#
    "My password doesn't work" / "I can't sign in": everything that happened to the account, in one timeline,
    with a plain-English summary on top. Read-only.

    .\UserActivity\Get-UserActivity.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com
    .\UserActivity\Get-UserActivity.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Days 30
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory)]
    [string]$UserPrincipalName,

    # Entra keeps sign-in and audit logs for 30 days (P1/P2)
    [ValidateRange(1, 30)]
    [int]$Days = 14
)

Import-Module "$PSScriptRoot\UserActivity.psm1" -Force

if (-Not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
    throw "Missing module: Microsoft.Graph"
}

$Config = Get-Config -Script "UserActivity" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\UserActivity.log"

Connect-MgGraph -TenantId $Config.TenantId -ClientId $Config.ClientId -CertificateThumbprint $Config.CertThumbprint -NoWelcome

$result = Invoke-UserActivityReport -UserPrincipalName $UserPrincipalName -Days $Days -LockoutServer $Config.LockoutServer -LogFile $LogFile

Write-Host "`n=== $UserPrincipalName ===" -ForegroundColor Cyan
$result.Summary | ForEach-Object { Write-Host "- $_" }
Write-Host "`nFull timeline ($($result.Events) events): $($result.ReportFile)"
