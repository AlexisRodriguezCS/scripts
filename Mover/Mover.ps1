#Requires -Version 7.0
<#
    Role change: update title/department/manager and swap access to match the new role.

    One person:
      .\Mover\Mover.ps1 -Client "ClientA" -SamAccountName jsmith -Title "Finance Manager" -Department Finance -Role "Finance PowerUser" -Manager bwilliams
    Many people (CSV with the same column names):
      .\Mover\Mover.ps1 -Client "ClientA" -Path .\Mover\Data\test.csv

    Add -Apply to make the changes.
#>
[CmdletBinding(DefaultParameterSetName = "Single")]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory, ParameterSetName = "Bulk")]
    [string]$Path,

    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$SamAccountName,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$Title,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$Department,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$Role,
    [Parameter(ParameterSetName = "Single")] [string]$Manager,          # New manager's SamAccountName
    [Parameter(ParameterSetName = "Single")] [string]$EmploymentType = "Regular Full-Time",

    # IT only: allow admin/VIP accounts (the HR request queue never sets this)
    [switch]$AllowProtected,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\Mover.psm1" -Force

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
foreach ($module in @("ActiveDirectory", "ExchangeOnlineManagement")) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

# Same client rules as onboarding (groups, DLs, OUs)
$Config = Get-Config -Script "Onboarding" -Client $Client -RootPath "$PSScriptRoot\.."
if ($AllowProtected) { $Config | Add-Member -NotePropertyName AllowProtected -NotePropertyValue $true -Force }

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\Mover.log"

# Bulk = CSV rows, single = one row built from the parameters
$requests = if ($PSCmdlet.ParameterSetName -eq "Bulk") {
    @(Import-Csv -Path $Path)
} else {
    @([pscustomobject]@{ SamAccountName = $SamAccountName; Title = $Title; Department = $Department; Role = $Role; Manager = $Manager; EmploymentType = $EmploymentType })
}

# ------------------------
# AUTHENTICATE
# ------------------------
if ($Apply) {
    Connect-ExchangeOnline -AppId $Config.ClientId `
                           -CertificateThumbprint $Config.CertThumbprint `
                           -Organization $Config.TenantDomain `
                           -ShowBanner:$false
}

$result = Invoke-UserMover -Requests $requests -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent

# Return per-person results so a calling system (HR form, ticketing) can read them
$result.Users

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Role change ($Client): needs attention" `
               -Message "Failed: $($result.Failed) of $($result.Total). Report: $($result.ReportFile)"
    exit 1
}
