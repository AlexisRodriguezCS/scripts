#Requires -Version 7.0
<#
    Builds a client's Active Directory layout from a JSON file: OUs, groups, and where new
    users and computers land by default.

    A fresh domain gives you almost nothing. "Users" and "Computers" are containers, not OUs,
    so Group Policy can't be linked to them, and every machine that joins the domain drops
    into that ungoverned container until someone redirects it.

    Preview (changes nothing):
      .\ADStructure\New-ADStructure.ps1 -Client "ClientA"
    Build it:
      .\ADStructure\New-ADStructure.ps1 -Client "ClientA" -Apply

    Safe to re-run: anything that already exists is left alone.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    # Defaults to Config\Clients\<Client>\structure.json, then the sample in Data\
    [string]$Path,

    # Leave new users and computers in the default containers
    [switch]$SkipRedirect,

    [switch]$Apply
)

. "$PSScriptRoot\..\Modules\Shared\Write-Log.ps1"

if (-Not (Get-Module -ListAvailable -Name "ActiveDirectory")) { throw "Missing module: ActiveDirectory" }
Import-Module ActiveDirectory

$null    = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\ADStructure.log"

# ------------------------
# LOAD THE STRUCTURE
# ------------------------
if (-not $Path) {
    $clientFile = "$PSScriptRoot\..\Config\Clients\$Client\structure.json"
    $Path = if (Test-Path $clientFile) { $clientFile } else { "$PSScriptRoot\Data\structure.json" }
}
if (-not (Test-Path $Path)) { throw "Structure file not found: $Path" }

$structure = Get-Content $Path -Raw | ConvertFrom-Json
$domainDn  = (Get-ADDomain).DistinguishedName
$protect   = [bool]$structure.ProtectFromDeletion

Write-Log -Message "[ADStructure] $Client : using $Path against $domainDn" -Level "INFO" -LogFile $LogFile
if (-not $Apply) { Write-Host "DRY RUN - nothing will be changed. Add -Apply to build it.`n" -ForegroundColor Yellow }

$created = 0
$skipped = 0

# ------------------------
# OUs (depth first, so a parent always exists before its children)
# ------------------------
function New-StructureOU {
    param([PSCustomObject]$Node, [string]$ParentDn)

    $dn = "OU=$($Node.Name),$ParentDn"

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "  exists  $dn"
        $script:skipped++
    }
    elseif ($Apply) {
        # Accidental deletion protection is what stops someone dragging a department into oblivion
        $null = New-ADOrganizationalUnit -Name $Node.Name -Path $ParentDn -ProtectedFromAccidentalDeletion $protect
        Write-Host "  created $dn" -ForegroundColor Green
        Write-Log -Message "[ADStructure] CREATED OU $dn" -Level "INFO" -LogFile $LogFile
        $script:created++
    }
    else {
        Write-Host "  would create $dn" -ForegroundColor Cyan
        $script:created++
    }

    # In a dry run the parent doesn't exist yet, so children are only previewed
    foreach ($child in $Node.Children) { New-StructureOU -Node $child -ParentDn $dn }
}

Write-Host "Organisational units" -ForegroundColor Cyan
foreach ($ou in $structure.OUs) { New-StructureOU -Node $ou -ParentDn $domainDn }

# ------------------------
# GROUPS
# ------------------------
if ($structure.Groups) {
    Write-Host "`nGroups" -ForegroundColor Cyan

    foreach ($group in $structure.Groups) {
        $groupPath = "$($group.Path),$domainDn"
        $scope     = if ($group.Scope)    { $group.Scope }    else { "Global" }
        $category  = if ($group.Category) { $group.Category } else { "Security" }

        if (Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue) {
            Write-Host "  exists  $($group.Name)"
            $skipped++
        }
        elseif ($Apply) {
            $null = New-ADGroup -Name $group.Name -GroupScope $scope -GroupCategory $category -Path $groupPath
            Write-Host "  created $($group.Name)" -ForegroundColor Green
            Write-Log -Message "[ADStructure] CREATED group $($group.Name) in $groupPath" -Level "INFO" -LogFile $LogFile
            $created++
        }
        else {
            Write-Host "  would create $($group.Name) in $groupPath" -ForegroundColor Cyan
            $created++
        }
    }
}

# ------------------------
# WHERE NEW OBJECTS LAND
# ------------------------
# Without this, a PC that joins the domain lands in CN=Computers, which is a container:
# no Group Policy can reach it, so it misses every baseline the company has.
if ($structure.Redirect -and -not $SkipRedirect) {
    Write-Host "`nDefault landing spots" -ForegroundColor Cyan

    $targets = @(
        @{ Kind = "Users";     Dn = $structure.Redirect.Users;     Tool = "redirusr" }
        @{ Kind = "Computers"; Dn = $structure.Redirect.Computers; Tool = "redircmp" }
    )

    foreach ($target in $targets | Where-Object { $_.Dn }) {
        $fullDn = "$($target.Dn),$domainDn"

        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$fullDn'" -ErrorAction SilentlyContinue)) {
            if ($Apply) {
                Write-Host "  SKIPPED $($target.Kind): $fullDn doesn't exist" -ForegroundColor Yellow
                continue
            }
            Write-Host "  would point new $($target.Kind.ToLower()) at $fullDn" -ForegroundColor Cyan
            continue
        }

        if ($Apply) {
            # redirusr/redircmp ship with AD DS; there is no PowerShell equivalent
            $output = & $target.Tool $fullDn 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  new $($target.Kind.ToLower()) now land in $fullDn" -ForegroundColor Green
                Write-Log -Message "[ADStructure] $($target.Tool) -> $fullDn" -Level "INFO" -LogFile $LogFile
            } else {
                Write-Host "  FAILED $($target.Tool): $output" -ForegroundColor Red
                Write-Log -Message "[ADStructure] $($target.Tool) FAILED: $output" -Level "ERROR" -LogFile $LogFile
            }
        }
        else {
            Write-Host "  would point new $($target.Kind.ToLower()) at $fullDn" -ForegroundColor Cyan
        }
    }
}

$verb = if ($Apply) { "Created" } else { "Would create" }
Write-Host "`n$verb $created, already there $skipped" -ForegroundColor Green
Write-Log -Message "[ADStructure] $Client : $verb $created, skipped $skipped" -Level "INFO" -LogFile $LogFile
