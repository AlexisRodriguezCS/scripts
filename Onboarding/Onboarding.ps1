#Requires -Version 7.0
<#
    One person:
      .\Onboarding\Onboarding.ps1 -Client "ClientA" -FirstName Alex -LastName Johnson -Title "Accountant" -Department Finance -Role Accountant
    Many people (CSV):
      .\Onboarding\Onboarding.ps1 -Client "ClientA" -Path .\Onboarding\Data\test2.csv

    Add -Apply to make the changes.
#>
[CmdletBinding(DefaultParameterSetName = "Single")]
param(
    [Parameter(Mandatory, ParameterSetName = "Bulk")]
    [string]$Path,

    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$FirstName,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$LastName,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$Title,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$Department,
    [Parameter(Mandatory, ParameterSetName = "Single")] [string]$Role,
    [Parameter(ParameterSetName = "Single")] [string]$Manager,
    [Parameter(ParameterSetName = "Single")] [string]$Location,
    [Parameter(ParameterSetName = "Single")] [string]$EmploymentType = "Regular Full-Time",
    [Parameter(ParameterSetName = "Single")] [string]$StartDate,
    [Parameter(ParameterSetName = "Single")] [string]$EmployeeID,

    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\Onboarding.psm1" -Force

# ------------------------
# CHECK REQUIRED MODULES
# ------------------------
$requiredModules = @("ActiveDirectory", "ExchangeOnlineManagement", "Microsoft.Graph")

foreach ($module in $requiredModules) {
    if (-Not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module"
    }
}

# Load config
$Config = Get-Config -Script "Onboarding" -Client $Client -RootPath "$PSScriptRoot\.."

# Create logs folder if it doesn't exist
if (-Not (Test-Path "$PSScriptRoot\Logs")) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" | Out-Null
}

# Set log file path
$LogFile = "$PSScriptRoot\$($Config.LogPath)"

# ------------------------
# AUTHENTICATE
# ------------------------
if ($Apply) {
    Connect-MgGraph -TenantId $Config.TenantId `
                    -ClientId $Config.ClientId `
                    -CertificateThumbprint $Config.CertThumbprint `
                    -NoWelcome

    Connect-ExchangeOnline -AppId $Config.ClientId `
                        -CertificateThumbprint $Config.CertThumbprint `
                        -Organization $Config.TenantDomain `
                        -ShowBanner:$false
}

# Run pipeline
$result = if ($PSCmdlet.ParameterSetName -eq "Bulk") {
    Invoke-UserOnboarding -Path $Path -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent
} else {
    $row = [pscustomobject]@{
        FirstName = $FirstName; LastName = $LastName; Title = $Title; Manager = $Manager; Location = $Location
        Department = $Department; Role = $Role; EmploymentType = $EmploymentType; StartDate = $StartDate; EmployeeID = $EmployeeID
    }
    Invoke-UserOnboarding -Rows @($row) -LogFile $LogFile -Config $Config -Apply $Apply.IsPresent
}

# Show temp passwords once, on screen only (not in logs or reports)
if ($result.Credentials) {
    Write-Host "`n=== Sign-in details (shown once: access pass for day one, temp password must be changed) ===" -ForegroundColor Yellow
    $result.Credentials | Format-Table -AutoSize | Out-Host
}

if ($result.Failed -gt 0 -or $result.Stopped -gt 0) {
    # Stopped = the circuit breaker cut the run short, so those people were never touched
    $stopped = if ($result.Stopped) { " Stopped before being processed: $($result.Stopped)." } else { "" }
    Send-Alert -Config $Config -LogFile $LogFile -Title "Onboarding ($Client): needs attention" `
               -Message "Failed: $($result.Failed) of $($result.Total).$stopped Check the latest report in Reports/."
    exit 1
}