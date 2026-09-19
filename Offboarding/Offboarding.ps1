#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Path = "$PSScriptRoot\Data\test.csv",

    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\Offboarding.psm1" -Force

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
$requiredModules = @("ActiveDirectory", "ExchangeOnlineManagement", "Microsoft.Graph", "PnP.PowerShell")

foreach ($module in $requiredModules) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

# Load config
$Config = Get-Config -Script "Offboarding" -Client $Client -RootPath "$PSScriptRoot\.."

# Create logs folder if it doesn't exist
if (-Not (Test-Path "$PSScriptRoot\Logs")) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" | Out-Null
}

# Set log file path
$LogFile = "$PSScriptRoot\$($Config.LogPath)"

# ------------------------
# AUTHENTICATE
# ------------------------
if ($Apply) {
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
$result = Invoke-UserOffboarding -Path $Path -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent

if ($result.Failed -gt 0) {
    exit 1
}
