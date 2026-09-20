#Requires -Version 7.0
<#
    Update users' AD attributes. Only the values you give are changed; everything else is left alone.

    One person:
      .\UserAttributes\Set-UserAttributes.ps1 -Client "ClientA" -SamAccountName jdoe -Title "Senior Accountant"
    Many people (CSV: SamAccountName + any attribute columns, blank cells are skipped):
      .\UserAttributes\Set-UserAttributes.ps1 -Client "ClientA" -Path .\UserAttributes\Data\test.csv

    Add -Apply to make the changes.
#>
[CmdletBinding(DefaultParameterSetName = "Single")]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory, ParameterSetName = "Bulk")]
    [string]$Path,

    [Parameter(Mandatory, ParameterSetName = "Single")]
    [string]$SamAccountName,

    [Parameter(ParameterSetName = "Single")] [string]$Title,
    [Parameter(ParameterSetName = "Single")] [string]$Department,
    [Parameter(ParameterSetName = "Single")] [string]$Manager,        # Manager's SamAccountName
    [Parameter(ParameterSetName = "Single")] [string]$Office,
    [Parameter(ParameterSetName = "Single")] [string]$OfficePhone,
    [Parameter(ParameterSetName = "Single")] [string]$MobilePhone,
    [Parameter(ParameterSetName = "Single")] [string]$Company,
    [Parameter(ParameterSetName = "Single")] [string]$EmployeeID,
    [Parameter(ParameterSetName = "Single")] [string]$City,
    [Parameter(ParameterSetName = "Single")] [string]$State,
    [Parameter(ParameterSetName = "Single")] [string]$StreetAddress,
    [Parameter(ParameterSetName = "Single")] [string]$PostalCode,
    [Parameter(ParameterSetName = "Single")] [string]$Description,

    # IT only: allow admin/VIP accounts (the HR request queue never sets this)
    [switch]$AllowProtected,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\UserAttributes.psm1" -Force

if (-Not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    throw "Missing module: ActiveDirectory"
}

# Same client settings as onboarding (tenant domain)
$Config = Get-Config -Script "Onboarding" -Client $Client -RootPath "$PSScriptRoot\.."
if ($AllowProtected) { $Config | Add-Member -NotePropertyName AllowProtected -NotePropertyValue $true -Force }

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\UserAttributes.log"

# Bulk = CSV rows, single = one row with only the parameters that were passed
$requests = if ($PSCmdlet.ParameterSetName -eq "Bulk") {
    @(Import-Csv -Path $Path)
} else {
    $row = [ordered]@{ SamAccountName = $SamAccountName }
    foreach ($name in $PSBoundParameters.Keys) {
        if ($name -notin @("Client", "SamAccountName", "Apply", "AllowProtected") -and $name -notin [System.Management.Automation.PSCmdlet]::CommonParameters) {
            $row[$name] = $PSBoundParameters[$name]
        }
    }
    @([pscustomobject]$row)
}

$result = Invoke-UserAttributesUpdate -Requests $requests -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent

# Return per-person results so a calling system (HR form, ticketing) can read them
$result.Users

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "User attribute update ($Client): needs attention" `
               -Message "Failed: $($result.Failed) of $($result.Total). Report: $($result.ReportFile)"
    exit 1
}
