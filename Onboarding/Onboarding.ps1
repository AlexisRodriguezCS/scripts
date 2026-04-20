[CmdletBinding()]
param(
    [string]$Path = "$PSScriptRoot\Data\test2.csv",

    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\Onboarding.psm1" -Force

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
$requiredModules = @("ActiveDirectory", "ExchangeOnlineManagement", "Microsoft.Graph")

foreach ($module in $requiredModules) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

# Load config
$Config = Get-Config -Script "Onboarding" -Client $Client -RootPath "$PSScriptRoot\.."

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
}

# Run pipeline
$result = Invoke-UserOnboarding -Path $Path -LogFile $LogFile -Config $Config -Apply $Apply

if ($result.Failed -gt 0) {
    exit 1
}