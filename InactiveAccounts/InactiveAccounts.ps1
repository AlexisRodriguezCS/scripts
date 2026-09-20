#Requires -Version 7.0
<#
    Find accounts nobody uses: disable inactive members, remove inactive guests.

    Review only (default):  .\InactiveAccounts\InactiveAccounts.ps1 -Client "ClientA"
    Make the changes:       .\InactiveAccounts\InactiveAccounts.ps1 -Client "ClientA" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\InactiveAccounts.psm1" -Force

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
foreach ($module in @("ActiveDirectory", "Microsoft.Graph")) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

$Config = Get-Config -Script "InactiveAccounts" -Client $Client -RootPath "$PSScriptRoot\.."

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\InactiveAccounts.log"

# ------------------------
# AUTHENTICATE (read access is needed even for a review)
# ------------------------
Connect-MgGraph -TenantId $Config.TenantId `
                -ClientId $Config.ClientId `
                -CertificateThumbprint $Config.CertThumbprint `
                -NoWelcome

$result = Invoke-InactiveAccountReview -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent
$result

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Inactive accounts ($Client): needs attention" `
               -Message "Failed: $($result.Failed). Report: $($result.ReportFile)"
    exit 1
}

# Review-only runs still tell someone there is cleanup to approve
if (-not $Apply -and $result.Inactive -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Inactive accounts ($Client): $($result.Inactive) to review" `
               -Message "Review the list, then run with -Apply. Report: $($result.ReportFile)"
}
