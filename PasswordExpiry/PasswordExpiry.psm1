# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-PipelineStep.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-PasswordExpiryReminder.ps1
. $PSScriptRoot\Functions\Get-PasswordExpiryData.ps1
. $PSScriptRoot\Functions\Test-PasswordExpiry.ps1
. $PSScriptRoot\Functions\New-PasswordExpiryPlan.ps1
. $PSScriptRoot\Functions\Start-PasswordExpiryReminder.ps1

# Load actions
. $PSScriptRoot\Actions\Send-PasswordExpiryEmail.ps1

Export-ModuleMember -Function *
