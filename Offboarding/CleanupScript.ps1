param (
    [Parameter()]
    [string]$ExcludeListPath = "$PSScriptRoot\exclude-users.txt",

    [Parameter()]
    [switch]$LiveRun
)

Write-Host "Starting post-onboarding cleanup" -ForegroundColor Cyan

if (-not $LiveRun) {
    Write-Host "DRY RUN MODE — pass -LiveRun to perform actual deletions" -ForegroundColor Cyan
}

# ----------------------------
# Load exclusion list
# ----------------------------
if (-not (Test-Path $ExcludeListPath)) {
    Write-Host "ERROR: Exclusion file not found at $ExcludeListPath — aborting" -ForegroundColor Red
    exit 1
}

$excludedUsers = Get-Content $ExcludeListPath |
    Where-Object { $_ -match '\S' } |
    ForEach-Object { $_.ToLower().Trim() }

if (-not $excludedUsers -or $excludedUsers.Count -eq 0) {
    Write-Host "ERROR: Exclusion list is empty — aborting" -ForegroundColor Red
    exit 1
}

Write-Host "Loaded $($excludedUsers.Count) exclusions"

# ----------------------------
# Confirmation
# ----------------------------
if ($LiveRun) {
    Write-Host ""
    Write-Host "WARNING: This will delete ALL users not on the exclusion list." -ForegroundColor Red
    $confirm = Read-Host "Type YES to continue"
    if ($confirm -ne "YES") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# ----------------------------
# Get users
# ----------------------------
Write-Host "Fetching users..."

$users = Get-MgUser -All `
    -Property "Id,UserPrincipalName,UserType,OnPremisesSyncEnabled,OnPremisesSamAccountName" `
    -Filter "userType eq 'Member'"

Write-Host "Found $($users.Count) users"

# ----------------------------
# AD target
# ----------------------------
function Get-PrimaryDC {
    return (Get-ADDomainController -Discover -Writable).HostName
}

$dc = Get-PrimaryDC
Write-Host "Using AD Domain Controller: $dc"

# ----------------------------
# Counters
# ----------------------------
$processed = 0
$skipped   = 0
$errors    = 0

# ----------------------------
# Main loop
# ----------------------------
foreach ($user in $users) {

    $upn = $user.UserPrincipalName
    if (-not $upn) { continue }

    $upnLower = $upn.ToLower()

    if ($excludedUsers -contains $upnLower) {
        Write-Host "SKIP (excluded): $upn" -ForegroundColor Yellow
        $skipped++
        continue
    }

    Write-Host "Processing: $upn"

    try {
        $fullUser = Get-MgUser -UserId $user.Id `
            -Property "OnPremisesSyncEnabled,OnPremisesSamAccountName" `
            -ErrorAction Stop

        # ----------------------------
        # HYBRID USER
        # ----------------------------
        if ($fullUser.OnPremisesSyncEnabled) {

            Write-Host "  HYBRID USER"

            $sam = $fullUser.OnPremisesSamAccountName

            if (-not $sam) {
                Write-Host "  ERROR: No SAM account name found in Entra object" -ForegroundColor Red
                $errors++
                continue
            }

            $adUser = Get-ADUser `
                -Filter "SamAccountName -eq '$sam'" `
                -Server $dc `
                -ErrorAction SilentlyContinue

            if ($adUser) {

                if (-not $LiveRun) {
                    Write-Host "  DRY RUN: would delete from AD -> $sam" -ForegroundColor Magenta
                }
                else {
                    Remove-ADUser -Identity $adUser.DistinguishedName -Confirm:$false
                    Write-Host "  Deleted from AD (authoritative)"

                    Start-Sleep -Seconds 20
                }
            }
            else {
                Write-Host "  WARNING: Not found in AD (SAM: $sam)" -ForegroundColor Yellow
            }

            $processed++
            continue
        }

        # ----------------------------
        # CLOUD USER
        # ----------------------------
        Write-Host "  CLOUD USER"

        if (-not $LiveRun) {
            Write-Host "  DRY RUN: would delete Entra user -> $upn" -ForegroundColor Magenta
            $processed++
            continue
        }

        Remove-MgUser -UserId $fullUser.Id -ErrorAction Stop
        Write-Host "  Deleted from Entra"

        $processed++
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
}

# ----------------------------
# Summary
# ----------------------------
Write-Host ""
Write-Host "Cleanup completed" -ForegroundColor Cyan
Write-Host "  Processed : $processed"
Write-Host "  Skipped   : $skipped"
Write-Host "  Errors    : $errors"