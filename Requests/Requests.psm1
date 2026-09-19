# Load shared
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1
. $PSScriptRoot\..\Modules\Shared\Test-ProtectedAccount.ps1
. $PSScriptRoot\..\Modules\Shared\New-RandomPassword.ps1

# Load help desk actions
. $PSScriptRoot\Actions\Get-RequestUser.ps1
. $PSScriptRoot\Actions\Invoke-AccountUnlock.ps1
. $PSScriptRoot\Actions\Invoke-PasswordReset.ps1
. $PSScriptRoot\Actions\Invoke-GroupAccessRequest.ps1

# Load functions
. $PSScriptRoot\Functions\ConvertTo-RequestRow.ps1
. $PSScriptRoot\Functions\Invoke-Request.ps1
. $PSScriptRoot\Functions\Set-RequestStatus.ps1
. $PSScriptRoot\Functions\Test-RequestApproval.ps1

Export-ModuleMember -Function *
