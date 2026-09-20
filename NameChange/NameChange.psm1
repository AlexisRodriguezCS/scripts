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

# Reused from onboarding (same sync trigger)
. $PSScriptRoot\..\Onboarding\Functions\Invoke-EntraSync.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-UserNameChange.ps1
. $PSScriptRoot\Functions\New-NameChangeRequest.ps1
. $PSScriptRoot\Functions\Test-NameChangeData.ps1
. $PSScriptRoot\Functions\Get-NameChangeIdentity.ps1
. $PSScriptRoot\Functions\New-NameChangePlan.ps1
. $PSScriptRoot\Functions\Start-NameChange.ps1

# Load actions
. $PSScriptRoot\Actions\Rename-UserAccount.ps1
. $PSScriptRoot\Actions\Set-UserLogonName.ps1
. $PSScriptRoot\Actions\Update-UserEmailAddress.ps1

Export-ModuleMember -Function *
