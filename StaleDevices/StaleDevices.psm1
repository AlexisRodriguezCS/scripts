# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-PipelineStep.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-StaleDeviceCleanup.ps1
. $PSScriptRoot\Functions\Get-DeviceData.ps1
. $PSScriptRoot\Functions\Test-StaleDevice.ps1
. $PSScriptRoot\Functions\New-StaleDevicePlan.ps1

# Load actions
. $PSScriptRoot\Actions\Invoke-DeviceRetire.ps1
. $PSScriptRoot\Actions\Remove-DeviceRecord.ps1

Export-ModuleMember -Function *
