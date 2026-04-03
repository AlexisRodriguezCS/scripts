[CmdletBinding()]
param(
    [string]$Path = "$PSScriptRoot\Data\test.csv",
    [Parameter(Mandatory)]
    [string]$Client
)

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
$requiredModules = @("ActiveDirectory", "ExchangeOnlineManagement", "Microsoft.Graph")

foreach ($module in $requiredModules) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Required module not found: $module. Run 'Install-Module $module -Scope CurrentUser'"
    }
}

# Dot-source shared modules
. "$PSScriptRoot\..\Modules\Shared\Write-Log.ps1"
. "$PSScriptRoot\..\Modules\Shared\Get-Config.ps1"

# Dot-source functions
. "$PSScriptRoot\Functions\Invoke-UserOnboarding.ps1"
. "$PSScriptRoot\Functions\Import-OnboardingCsv.ps1"
. "$PSScriptRoot\Functions\ConvertTo-OnboardingStandard.ps1"
. "$PSScriptRoot\Functions\Test-OnboardingData.ps1"
. "$PSScriptRoot\Functions\Set-OnboardingPolicy.ps1"
. "$PSScriptRoot\Functions\New-OnboardingPlan.ps1"
. "$PSScriptRoot\Functions\New-OnboardingIdentity.ps1"
. "$PSScriptRoot\Functions\Start-Onboarding.ps1"
. "$PSScriptRoot\Functions\Invoke-EntraSync.ps1"
. "$PSScriptRoot\Functions\New-OnboardingUser.ps1"
. "$PSScriptRoot\Functions\Invoke-PipelineStep.ps1"

# Dot-source actions
. "$PSScriptRoot\Actions\Add-OnboardingGroupMember.ps1"
. "$PSScriptRoot\Actions\Add-OnboardingDLMember.ps1"
. "$PSScriptRoot\Actions\Set-OnboardingLicense.ps1"
. "$PSScriptRoot\Actions\Wait-ForEntraUser.ps1"

# Load config
$Config = Get-Config -Script "Onboarding" -Client $Client

# Create logs folder if it doesn't exist
if (-Not (Test-Path "$PSScriptRoot\Logs")) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" | Out-Null
}

# Set log file path
$LogFile = "$PSScriptRoot\$($Config.LogPath)"

# ------------------------
# AUTHENTICATE
# ------------------------
Connect-MgGraph -TenantId $Config.TenantId `
                -ClientId $Config.ClientId `
                -CertificateThumbprint $Config.CertThumbprint `
                -NoWelcome

Connect-ExchangeOnline -AppId $Config.ClientId `
                       -CertificateThumbprint $Config.CertThumbprint `
                       -Organization $Config.TenantDomain `
                       -ShowBanner:$false

# Run pipeline
Invoke-UserOnboarding -Path $Path -LogFile $LogFile -Config $Config