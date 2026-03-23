[CmdletBinding()]
param(
    [string]$AdminUPN = "alexis@testadscripts.onmicrosoft.com"
)

. "$PSScriptRoot\..\..\Modules\Shared\Write-Log.ps1"
. "$PSScriptRoot\..\..\Modules\Shared\Get-Config.ps1"

$Config  = Get-Config -Script "Onboarding"
$LogFile = "$PSScriptRoot\..\Logs\Setup.log"

# ------------------------
# CREATE LOG FOLDER
# ------------------------
if (-Not (Test-Path "$PSScriptRoot\..\Logs")) {
    New-Item -ItemType Directory -Path "$PSScriptRoot\..\Logs" | Out-Null
    Write-Log -Message "[CREATED] Logs folder created" -Level "INFO" -LogFile $LogFile
} else {
    Write-Log -Message "[SKIP] Logs folder already exists" -Level "INFO" -LogFile $LogFile
}

# ------------------------
# CREATE AD OUs
# ------------------------
$ous = @("Finance", "IT", "Sales", "HR", "Marketing")

foreach ($ou in $ous) {
    $exists = Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Log -Message "[SKIP] OU already exists: $ou" -Level "INFO" -LogFile $LogFile
    } else {
        New-ADOrganizationalUnit -Name $ou -Path $Config.DepartmentOU
        Write-Log -Message "[CREATED] OU created: $ou" -Level "INFO" -LogFile $LogFile
    }
}

# ------------------------
# CREATE AD GROUPS
# ------------------------
$groups = @("GRP-AllStaff", "GRP_ROLE_IT_Admin", "GRP_ROLE_IT_User", "GRP_ROLE_IT_Helpdesk",
            "GRP_ROLE_Finance_User", "GRP_ROLE_Finance_PowerUser", "GRP_ROLE_HR_User",
            "GRP_ROLE_HR_PowerUser", "GRP_ROLE_Sales_User", "GRP_ROLE_Marketing_User", "GRP_ROLE_User")

foreach ($group in $groups) {
    $exists = Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Log -Message "[SKIP] Group already exists: $group" -Level "INFO" -LogFile $LogFile
    } else {
        New-ADGroup -Name $group -GroupScope Global -GroupCategory Security -Path $Config.GroupsOU
        Write-Log -Message "[CREATED] Group created: $group" -Level "INFO" -LogFile $LogFile
    }
}

# ------------------------
# CREATE DISTRIBUTION LISTS
# ------------------------
Connect-ExchangeOnline -UserPrincipalName $AdminUPN

foreach ($dl in $Config.DistributionLists) {
    $exists = Get-DistributionGroup -Identity $dl -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Log -Message "[SKIP] DL already exists: $dl" -Level "INFO" -LogFile $LogFile
    } else {
        New-DistributionGroup -Name $dl -Type Distribution
        Write-Log -Message "[CREATED] DL created: $dl" -Level "INFO" -LogFile $LogFile
    }
}

Write-Log -Message "=== Setup Complete ===" -Level "INFO" -LogFile $LogFile