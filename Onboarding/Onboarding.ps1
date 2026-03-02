[CmdletBinding()]
param(
    [string]$Path = "$PSScriptRoot\Data\users.csv"
)

# Dot-source shared modules
. "$PSScriptRoot\..\Modules\Shared\Write-Log.ps1"
. "$PSScriptRoot\..\Modules\Shared\Invoke-WithRetry.ps1"
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

# Dot-source actions
. "$PSScriptRoot\Actions\New-OnboardingUser.ps1"
. "$PSScriptRoot\Actions\Add-OnboardingGroupMember.ps1"
. "$PSScriptRoot\Actions\Add-OnboardingDLMember.ps1"
. "$PSScriptRoot\Actions\Set-OnboardingLicense.ps1"

# Load config
$Config = Get-Config -Script "Onboarding"

# Set log file path
$LogFile = "$PSScriptRoot\$($Config.LogPath)"

# Run pipeline
Invoke-UserOnboarding -Path $Path -LogFile $LogFile -Config $Config