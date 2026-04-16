# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-PipelineStep.ps1
. $PSScriptRoot\Functions\Invoke-UserOnboarding.ps1
. $PSScriptRoot\Functions\Import-OnboardingCsv.ps1
. $PSScriptRoot\Functions\ConvertTo-OnboardingStandard.ps1
. $PSScriptRoot\Functions\Test-OnboardingData.ps1
. $PSScriptRoot\Functions\Set-OnboardingPolicy.ps1
. $PSScriptRoot\Functions\New-OnboardingPlan.ps1
. $PSScriptRoot\Functions\New-OnboardingIdentity.ps1
. $PSScriptRoot\Functions\Start-Onboarding.ps1
. $PSScriptRoot\Functions\New-OnboardingUser.ps1

# Load actions
. $PSScriptRoot\Actions\Add-OnboardingGroupMember.ps1
. $PSScriptRoot\Actions\Add-OnboardingDLMember.ps1
. $PSScriptRoot\Actions\Set-OnboardingLicense.ps1
. $PSScriptRoot\Actions\Wait-ForEntraUser.ps1

Export-ModuleMember -Function *