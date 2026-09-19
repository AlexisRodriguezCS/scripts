#Requires -Version 7.0
<#
    Clean up Intune devices that stopped checking in: retire them, and delete the record once they're very old.

    Review only (default): .\StaleDevices\StaleDevices.ps1 -Client "ClientA"
    Make the changes:      .\StaleDevices\StaleDevices.ps1 -Client "ClientA" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\StaleDevices.psm1" -Force

if (-Not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
    throw "Missing module: Microsoft.Graph"
}

$Config = Get-Config -Script "StaleDevices" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\StaleDevices.log"

# ------------------------
# AUTHENTICATE (read access is needed even for a review)
# ------------------------
Connect-MgGraph -TenantId $Config.TenantId `
                -ClientId $Config.ClientId `
                -CertificateThumbprint $Config.CertThumbprint `
                -NoWelcome

$result = Invoke-StaleDeviceCleanup -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent
$result

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Stale devices ($Client): needs attention" `
               -Message "Failed: $($result.Failed). Report: $($result.ReportFile)"
    exit 1
}

if (-not $Apply -and $result.ToChange -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Stale devices ($Client): $($result.ToChange) to review" `
               -Message "Review the list, then run with -Apply. Report: $($result.ReportFile)"
}
