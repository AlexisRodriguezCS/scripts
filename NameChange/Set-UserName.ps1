#Requires -Version 7.0
<#
    Name change (marriage, divorce, legal change): new first/last name, display name,
    optionally a new username and email address, with the old address kept as an alias.

    One person:
      .\NameChange\Set-UserName.ps1 -Client "ClientA" -SamAccountName jsmith -NewLastName "Johnson" -NewUsername jjohnson
    Many people (CSV with the same column names):
      .\NameChange\Set-UserName.ps1 -Client "ClientA" -Path .\NameChange\Data\test.csv

    Add -Apply to make the changes.
#>
[CmdletBinding(DefaultParameterSetName = "Single")]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory, ParameterSetName = "Bulk")]
    [string]$Path,

    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$SamAccountName,
    [Parameter(ParameterSetName = "Single")] [string]$NewFirstName,
    [Parameter(ParameterSetName = "Single")] [string]$NewLastName,
    # Blank keeps the current username; set it to change how they sign in and their email address
    [Parameter(ParameterSetName = "Single")] [string]$NewUsername,
    # Off keeps mail flowing to the old address (the default)
    [Parameter(ParameterSetName = "Single")] [switch]$DropOldEmail,

    # IT only: allow admin/VIP accounts
    [switch]$AllowProtected,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\NameChange.psm1" -Force

if (-Not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    throw "Missing module: ActiveDirectory"
}

# Same client settings as onboarding (tenant domain, sync server)
$Config = Get-Config -Script "Onboarding" -Client $Client -RootPath "$PSScriptRoot\.."
if ($AllowProtected) { $Config | Add-Member -NotePropertyName AllowProtected -NotePropertyValue $true -Force }

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\NameChange.log"

# Bulk = CSV rows, single = one row built from the parameters
$requests = if ($PSCmdlet.ParameterSetName -eq "Bulk") {
    @(Import-Csv -Path $Path)
} else {
    @([pscustomobject]@{
        SamAccountName = $SamAccountName
        NewFirstName   = $NewFirstName
        NewLastName    = $NewLastName
        NewUsername    = $NewUsername
        KeepOldEmail   = if ($DropOldEmail) { "No" } else { "Yes" }
    })
}

$result = Invoke-UserNameChange -Requests $requests -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent

# Return per-person results so a calling system (HR form, ticketing) can read them
$result.Users

if ($result.Failed -gt 0) {
    Send-Alert -Config $Config -LogFile $LogFile -Title "Name change ($Client): needs attention" `
               -Message "Failed: $($result.Failed) of $($result.Total). Report: $($result.ReportFile)"
    exit 1
}
