# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\Resolve-EntraUpn.ps1
. $PSScriptRoot\..\Modules\Shared\Test-ProtectedAccount.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-PipelineStep.ps1
. $PSScriptRoot\..\Modules\Shared\New-RandomPassword.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Save-UserSnapshot.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-UserOffboarding.ps1
. $PSScriptRoot\Functions\Import-OffboardingCsv.ps1
. $PSScriptRoot\Functions\Test-OffboardingData.ps1
. $PSScriptRoot\Functions\Get-OffboardingIdentity.ps1
. $PSScriptRoot\Functions\New-OffboardingPlan.ps1
. $PSScriptRoot\Functions\Start-Offboarding.ps1

# Load actions
. $PSScriptRoot\Actions\Disable-OffboardingAccount.ps1
. $PSScriptRoot\Actions\Remove-OffboardingGroupMember.ps1
. $PSScriptRoot\Actions\Remove-OffboardingDLMember.ps1
. $PSScriptRoot\Actions\Move-OffboardingUser.ps1
. $PSScriptRoot\Actions\Revoke-OffboardingSession.ps1
. $PSScriptRoot\Actions\Convert-OffboardingMailbox.ps1
. $PSScriptRoot\Actions\Set-OffboardingAutoReply.ps1
. $PSScriptRoot\Actions\Grant-OffboardingMailboxAccess.ps1
. $PSScriptRoot\Actions\Grant-OffboardingOneDriveAccess.ps1
. $PSScriptRoot\Actions\Remove-OffboardingLicense.ps1

Export-ModuleMember -Function *
