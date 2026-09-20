#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
    Turns a fresh Windows Server into the lab domain controller these scripts expect.
    Run it INSIDE the VM, twice: once to promote (it reboots), once after the reboot to
    build the OUs, groups and config.

        .\Initialize-LabDomain.ps1 -DomainName lab.local

    Lab only. It creates a domain with a password you type once and stores nothing.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+$')]
    [string]$DomainName = "lab.local",

    # NetBIOS name; defaults to the part before the dot, upper-cased
    [string]$NetBiosName,

    # Where the repo lives inside the VM, so the config lands in the right place
    [string]$RepoPath = (Split-Path $PSScriptRoot -Parent),

    [string]$Client = "Lab",

    # Directory Services Restore Mode password. Left out, you are asked for it.
    # Pass it when running this from the host over PowerShell Direct, where nothing can prompt.
    [securestring]$SafeModePassword
)

$ErrorActionPreference = "Stop"
if (-not $NetBiosName) { $NetBiosName = ($DomainName -split '\.')[0].ToUpper() }

$isDomainController = (Get-CimInstance Win32_ComputerSystem).DomainRole -in @(4, 5)

# ------------------------------------------------------------------
# STAGE 1 — promote this machine to a domain controller, then reboot
# ------------------------------------------------------------------
if (-not $isDomainController) {
    Write-Host "Stage 1: promoting this server to a domain controller for $DomainName" -ForegroundColor Cyan

    # The recovery password used to start AD in repair mode. Never written to disk.
    if (-not $SafeModePassword) {
        $SafeModePassword = Read-Host "Choose a recovery (DSRM) password" -AsSecureString
    }

    Install-WindowsFeature -Name AD-Domain-Services, RSAT-AD-PowerShell -IncludeManagementTools

    Import-Module ADDSDeployment
    Install-ADDSForest -DomainName $DomainName `
                       -DomainNetbiosName $NetBiosName `
                       -SafeModeAdministratorPassword $SafeModePassword `
                       -InstallDns `
                       -NoRebootOnCompletion:$false `
                       -Force

    # Install-ADDSForest reboots; nothing after this line runs
    return
}

# ------------------------------------------------------------------
# STAGE 2 — build what the scripts expect
# ------------------------------------------------------------------
Import-Module ActiveDirectory

$domain   = Get-ADDomain
$domainDn = $domain.DistinguishedName
Write-Host "Stage 2: setting up $($domain.DNSRoot) ($domainDn)" -ForegroundColor Cyan

function New-LabOU {
    param([string]$Name, [string]$Path)

    $dn = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "  exists  $dn"
        return $dn
    }

    # Accidental deletion protection is on by default and makes lab cleanup a fight
    $null = New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $false
    Write-Host "  created $dn" -ForegroundColor Green
    return $dn
}

# The structure the config samples in the README point at:
#   OU=Identity -> OU=Users -> OU=Employees / OU=Disabled
#               -> OU=Groups
$identityOu = New-LabOU -Name "Identity" -Path $domainDn
$usersOu    = New-LabOU -Name "Users"    -Path $identityOu
$employeeOu = New-LabOU -Name "Employees" -Path $usersOu
$disabledOu = New-LabOU -Name "Disabled"  -Path $usersOu
$groupsOu   = New-LabOU -Name "Groups"    -Path $identityOu

# One OU per department: onboarding puts each new hire in OU=<Department>,<DefaultOU>
$departments = @("Finance", "IT", "Sales", "HR", "Marketing")
foreach ($department in $departments) { $null = New-LabOU -Name $department -Path $employeeOu }

# Role groups the onboarding policy hands out, plus the all-staff group
$groups = @("GRP-AllStaff", "GRP_ROLE_IT_Admin", "GRP_ROLE_IT_User", "GRP_ROLE_IT_Helpdesk",
            "GRP_ROLE_Finance_User", "GRP_ROLE_Finance_PowerUser", "GRP_ROLE_HR_User",
            "GRP_ROLE_HR_PowerUser", "GRP_ROLE_Sales_User", "GRP_ROLE_Marketing_User", "GRP_ROLE_User")

foreach ($group in $groups) {
    if (Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue) {
        Write-Host "  exists  $group"
    } else {
        $null = New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path $groupsOu
        Write-Host "  created $group" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------
# Config for this client, so the scripts run with no hand editing
# ------------------------------------------------------------------
$configDir = Join-Path $RepoPath "Config\Clients\$Client"
$null = New-Item -ItemType Directory -Path $configDir -Force

$upnSuffix = "@$($domain.DNSRoot)"

$onboarding = [ordered]@{
    DefaultOU               = $employeeOu
    DepartmentOU            = $employeeOu
    GroupsOU                = $groupsOu
    UPNSuffix               = $upnSuffix
    UsernameFormat          = "FirstLast"
    ManagedGroupPrefix      = "GRP_ROLE_"
    DefaultGroups           = @("GRP-AllStaff")
    DefaultDistributionList = "AllStaff"
    DistributionLists       = @("AllStaff", "Managers") + $departments
    Departments             = $departments
    Company                 = "Lab Co"
    MaxConsecutiveFailures  = 5
    # Cloud settings are filled in when the Microsoft 365 dev tenant exists
    TenantDomain            = ""
    TenantId                = ""
    ClientId                = ""
    CertThumbprint          = ""
}

$offboarding = [ordered]@{
    DisabledOU             = $disabledOu
    DefaultContact         = "helpdesk$upnSuffix"
    AutoReplyMessage       = "{Name} is no longer with the company. Please contact {Contact}."
    MaxConsecutiveFailures = 5
    ProtectedAccounts      = @("Administrator", "krbtgt")
    TenantDomain           = ""
    TenantId               = ""
    ClientId               = ""
    CertThumbprint         = ""
    SharePointAdminUrl     = ""
}

$onboarding  | ConvertTo-Json -Depth 5 | Out-File (Join-Path $configDir "Onboarding.json")  -Encoding utf8
$offboarding | ConvertTo-Json -Depth 5 | Out-File (Join-Path $configDir "Offboarding.json") -Encoding utf8

Write-Host @"

Domain ready: $($domain.DNSRoot)

  Employees  $employeeOu
  Disabled   $disabledOu
  Groups     $groupsOu
  Config     $configDir

Try it (dry run, changes nothing):

  cd $RepoPath
  .\Onboarding\Onboarding.ps1 -Client $Client -FirstName Lisa -LastName Taylor ``
      -Title Accountant -Department Finance -Role Accountant

Then add -Apply to create her for real.

The cloud steps (license, distribution lists, mailbox) stay empty until the
Microsoft 365 tenant details are filled into the two config files.
"@ -ForegroundColor Green
