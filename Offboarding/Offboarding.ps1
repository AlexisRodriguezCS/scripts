#Requires -Version 7.0
<#
    One person:
      .\Offboarding\Offboarding.ps1 -Client "ClientA" -SamAccountName jsmith -Manager maryjohnson@contoso.com
    Many people (CSV: SamAccountName, Manager):
      .\Offboarding\Offboarding.ps1 -Client "ClientA" -Path .\Offboarding\Data\test.csv

    Add -Apply to make the changes.
#>
[CmdletBinding(DefaultParameterSetName = "Single")]
param(
    [Parameter(Mandatory, ParameterSetName = "Bulk")]
    [string]$Path,

    [Parameter(Mandatory, ParameterSetName = "Single")]
    [string]$SamAccountName,

    # Manager's UPN: gets the mailbox + OneDrive (optional)
    [Parameter(ParameterSetName = "Single")]
    [string]$Manager,

    [Parameter(Mandatory)]
    [string]$Client,

    # IT only: allow admin/VIP accounts (the HR request queue never sets this)
    [switch]$AllowProtected,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\Offboarding.psm1" -Force

# Load config first: what this client needs depends on whether they have Microsoft 365
$Config = Get-Config -Script "Offboarding" -Client $Client -RootPath "$PSScriptRoot\.."
if ($AllowProtected) { $Config | Add-Member -NotePropertyName AllowProtected -NotePropertyValue $true -Force }

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
# "OnPrem" = Active Directory only: no mailbox, no license, no OneDrive to hand over.
# A dry run reads AD to build the plan, so the cloud modules are only needed to apply.
$hasCloud = "$($Config.Environment)" -ne "OnPrem"

$requiredModules = @("ActiveDirectory")
if ($Apply -and $hasCloud) { $requiredModules += @("ExchangeOnlineManagement", "Microsoft.Graph", "PnP.PowerShell") }

foreach ($module in $requiredModules) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

# Create logs folder if it doesn't exist
if (-Not (Test-Path "$PSScriptRoot\Logs")) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" | Out-Null
}

# Set log file path
$LogFile = "$PSScriptRoot\Logs\Offboarding.log"

# ------------------------
# AUTHENTICATE
# ------------------------
if ($Apply -and $hasCloud) {
    Connect-MgGraph -TenantId $Config.TenantId `
                    -ClientId $Config.ClientId `
                    -CertificateThumbprint $Config.CertThumbprint `
                    -NoWelcome

    Connect-ExchangeOnline -AppId $Config.ClientId `
                        -CertificateThumbprint $Config.CertThumbprint `
                        -Organization $Config.TenantDomain `
                        -ShowBanner:$false

    # SharePoint admin site, used to hand OneDrive to the manager
    Connect-PnPOnline -Url $Config.SharePointAdminUrl `
                      -ClientId $Config.ClientId `
                      -Thumbprint $Config.CertThumbprint `
                      -Tenant $Config.TenantDomain
}

# Run pipeline
$result = if ($PSCmdlet.ParameterSetName -eq "Bulk") {
    Invoke-UserOffboarding -Path $Path -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent
} else {
    Invoke-UserOffboarding -Rows @([pscustomobject]@{ SamAccountName = $SamAccountName; Manager = $Manager }) `
                           -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent
}

# A leaver that can't be found still has access somewhere, so flag it too
if ($result.Failed -gt 0 -or $result.NotFound -gt 0 -or $result.Stopped -gt 0) {
    # Stopped = the circuit breaker cut the run short, so those leavers still have access
    $stopped = if ($result.Stopped) { ", Stopped before being offboarded: $($result.Stopped)" } else { "" }
    Send-Alert -Config $Config -LogFile $LogFile -Title "Offboarding ($Client): needs attention" `
               -Message "Failed: $($result.Failed), Not found: $($result.NotFound)$stopped. Report: $($result.ReportFile)"
    exit 1
}
