# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\Resolve-EntraUpn.ps1
. $PSScriptRoot\..\Modules\Shared\Test-ProtectedAccount.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-PipelineStep.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Save-UserSnapshot.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Load actions (first: defines the managed attribute list the functions use)
. $PSScriptRoot\Actions\Set-UserAttribute.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-UserAttributesUpdate.ps1
. $PSScriptRoot\Functions\New-UserAttributesRequest.ps1
. $PSScriptRoot\Functions\Test-UserAttributesData.ps1
. $PSScriptRoot\Functions\Get-UserAttributesIdentity.ps1
. $PSScriptRoot\Functions\Get-UserAttributeChanges.ps1
. $PSScriptRoot\Functions\New-UserAttributesPlan.ps1
. $PSScriptRoot\Functions\Start-UserAttributesUpdate.ps1

Export-ModuleMember -Function *
