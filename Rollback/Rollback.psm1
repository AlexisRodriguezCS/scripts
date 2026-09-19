# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1

# Reused actions (same behavior as the scripts that made the change)
. $PSScriptRoot\..\UserAttributes\Actions\Set-UserAttribute.ps1
. $PSScriptRoot\..\UserAttributes\Functions\Get-UserAttributeChanges.ps1
. $PSScriptRoot\..\Offboarding\Actions\Remove-OffboardingGroupMember.ps1
. $PSScriptRoot\..\Offboarding\Actions\Move-OffboardingUser.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-RestoreFromSnapshot.ps1
. $PSScriptRoot\Functions\New-RestorePlan.ps1

Export-ModuleMember -Function *
