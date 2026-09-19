# Load shared
. $PSScriptRoot\..\Modules\Shared\Write-Log.ps1
. $PSScriptRoot\..\Modules\Shared\Get-Config.ps1
. $PSScriptRoot\..\Modules\Shared\Resolve-EntraUpn.ps1
. $PSScriptRoot\..\Modules\Shared\Test-ProtectedAccount.ps1
. $PSScriptRoot\..\Modules\Shared\Send-Alert.ps1

# Load functions
. $PSScriptRoot\Functions\Invoke-Audit.ps1
. $PSScriptRoot\Functions\New-AuditFinding.ps1
. $PSScriptRoot\Functions\Export-AuditReport.ps1

# Load checks
. $PSScriptRoot\Functions\Get-MfaAudit.ps1
. $PSScriptRoot\Functions\Get-AdminRoleAudit.ps1
. $PSScriptRoot\Functions\Get-MailForwardingAudit.ps1
. $PSScriptRoot\Functions\Get-AppCredentialAudit.ps1
. $PSScriptRoot\Functions\Get-ConditionalAccessAudit.ps1
. $PSScriptRoot\Functions\Get-LicenseAudit.ps1
. $PSScriptRoot\Functions\Get-AccessReview.ps1
. $PSScriptRoot\Functions\Get-OffboardingCheck.ps1

Export-ModuleMember -Function *
