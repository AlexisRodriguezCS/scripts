# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-PipelineStep.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Save-UserSnapshot.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-InactiveAccountReview.ps1
. $PSScriptRoot\Functions\Get-InactiveAccountData.ps1
. $PSScriptRoot\Functions\Get-AdminAccountId.ps1
. $PSScriptRoot\Functions\Test-InactiveAccount.ps1
. $PSScriptRoot\Functions\New-InactiveAccountPlan.ps1
. $PSScriptRoot\Functions\Start-InactiveAccountCleanup.ps1

# Load actions
. $PSScriptRoot\Actions\Disable-InactiveAccount.ps1
. $PSScriptRoot\Actions\Remove-InactiveGuest.ps1

Export-ModuleMember -Function *
