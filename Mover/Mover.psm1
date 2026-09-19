# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\Resolve-EntraUpn.ps1
. $PSScriptRoot\..\Modules\Shared\Test-ProtectedAccount.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-PipelineStep.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Test-CircuitBreaker.ps1
. $PSScriptRoot\..\Modules\Shared\Save-UserSnapshot.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Reused from the other scripts (same rules, same actions)
. $PSScriptRoot\..\Onboarding\Functions\Set-OnboardingPolicy.ps1
. $PSScriptRoot\..\Onboarding\Actions\Add-OnboardingGroupMember.ps1
. $PSScriptRoot\..\Offboarding\Actions\Remove-OffboardingGroupMember.ps1
. $PSScriptRoot\..\Offboarding\Actions\Move-OffboardingUser.ps1
. $PSScriptRoot\..\UserAttributes\Actions\Set-UserAttribute.ps1
. $PSScriptRoot\..\UserAttributes\Functions\Get-UserAttributeChanges.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-UserMover.ps1
. $PSScriptRoot\Functions\New-MoverRequest.ps1
. $PSScriptRoot\Functions\Test-MoverData.ps1
. $PSScriptRoot\Functions\Get-MoverIdentity.ps1
. $PSScriptRoot\Functions\New-MoverPlan.ps1
. $PSScriptRoot\Functions\Start-Mover.ps1

# Load actions
. $PSScriptRoot\Actions\Sync-MoverDLMembership.ps1

Export-ModuleMember -Function *
