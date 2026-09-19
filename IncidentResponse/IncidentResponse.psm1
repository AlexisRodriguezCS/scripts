# Load shared
. $PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\New-Report.ps1
. $PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1
. $PSScriptRoot\..\Modules\Shared\Save-UserSnapshot.ps1
. $PSScriptRoot\..\Modules\Shared\New-RandomPassword.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Reused from offboarding (same action)
. $PSScriptRoot\..\Offboarding\Actions\Revoke-OffboardingSession.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-IncidentResponse.ps1
. $PSScriptRoot\Functions\Get-IncidentIdentity.ps1
. $PSScriptRoot\Functions\Save-IncidentEvidence.ps1
. $PSScriptRoot\Functions\New-IncidentPlan.ps1

# Load actions
. $PSScriptRoot\Actions\Disable-IncidentAccount.ps1
. $PSScriptRoot\Actions\Reset-IncidentPassword.ps1
. $PSScriptRoot\Actions\Remove-IncidentForwarding.ps1
. $PSScriptRoot\Actions\Disable-IncidentInboxRule.ps1

Export-ModuleMember -Function *
