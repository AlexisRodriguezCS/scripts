#Requires -Version 7.0
<#
    Runs one employee's whole story against the lab domain and collects everything it
    produced in a single folder: hired, promoted, married (name change), left, and put back.

    Preview:   .\Demo\Invoke-Demo.ps1 -Client Lab
    Run it:    .\Demo\Invoke-Demo.ps1 -Client Lab -Apply

    For demos and screenshots. Point it at a lab, never at a live client.
#>
[CmdletBinding()]
param(
    [string]$Client = "Lab",

    [string]$FirstName = "Jordan",
    [string]$LastName  = "Avery",

    # Name after the name change
    [string]$NewLastName = "Brooks",

    [switch]$Apply
)

$ErrorActionPreference = "Continue"
$root     = Split-Path $PSScriptRoot -Parent
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir   = Join-Path $PSScriptRoot "Output\Demo_$runStamp"
$null     = New-Item -ItemType Directory -Path $outDir -Force

$startSam = "$($FirstName.ToLower())$($LastName.ToLower())"
$endSam   = "$($FirstName.ToLower())$($NewLastName.ToLower())"

Import-Module ActiveDirectory

# Everything printed is also kept, so a screenshot and a file say the same thing
Start-Transcript -Path (Join-Path $outDir "demo.txt") | Out-Null

function Show-State {
    param([string]$Label, [string[]]$Names)

    $user = $null
    foreach ($name in $Names) {
        $user = Get-ADUser -Filter "SamAccountName -eq '$name'" -Properties DisplayName, Title, Department, Enabled, MemberOf -ErrorAction SilentlyContinue
        if ($user) { break }
    }

    if (-not $user) {
        Write-Host "   $Label : no account" -ForegroundColor DarkGray
        return
    }

    $groups = @($user.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' })
    $ou     = ($user.DistinguishedName -split ',', 2)[1] -replace ',DC=.+$'

    Write-Host "   $Label" -ForegroundColor Yellow
    Write-Host "      Name     : $($user.DisplayName)   ($($user.SamAccountName))"
    Write-Host "      Job      : $($user.Title), $($user.Department)"
    Write-Host "      Enabled  : $($user.Enabled)"
    Write-Host "      Where    : $ou"
    Write-Host "      Access   : $(if ($groups) { $groups -join ', ' } else { 'none' })"
}

function Invoke-Chapter {
    param([int]$Number, [string]$Title, [string]$Story, [scriptblock]$Run)

    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host " $Number. $Title" -ForegroundColor Cyan
    Write-Host " $Story" -ForegroundColor Gray
    Write-Host "$('=' * 70)" -ForegroundColor Cyan

    $start = Get-Date
    & $Run
    Write-Host "   ... $([math]::Round(((Get-Date) - $start).TotalSeconds, 1))s" -ForegroundColor DarkGray
}

Write-Host @"

  Employee lifecycle demo - $Client
  $(if ($Apply) { "LIVE: this will change Active Directory" } else { "PREVIEW: nothing will be changed (add -Apply)" })
  Output: $outDir
"@ -ForegroundColor $(if ($Apply) { "Green" } else { "Yellow" })

# A demo you can run twice is a demo you can run in front of someone
if ($Apply) {
    foreach ($name in @($startSam, $endSam)) {
        Get-ADUser -Filter "SamAccountName -eq '$name'" -ErrorAction SilentlyContinue | Remove-ADUser -Confirm:$false
    }
}

# Not named $apply: PowerShell variables are case-insensitive, so it would overwrite the -Apply switch
$applySplat = if ($Apply) { @{ Apply = $true } } else { @{} }

Invoke-Chapter 1 "HIRED" "HR sends a new starter. Account, right department, right access, temporary password." {
    & "$root\Onboarding\Onboarding.ps1" -Client $Client -FirstName $FirstName -LastName $LastName `
        -Title "Sales Rep" -Department Sales -Role "Sales Rep" @applySplat
    Show-State "After hiring:" @($startSam)
}

Invoke-Chapter 2 "PROMOTED" "Moving to IT. Old access comes off, new access goes on, and they move department." {
    & "$root\Mover\Mover.ps1" -Client $Client -SamAccountName $startSam `
        -Title "Support Technician" -Department IT -Role Technician @applySplat
    Show-State "After the role change:" @($startSam)
}

Invoke-Chapter 3 "NAME CHANGE" "They got married. New name, new username, and mail to the old address still arrives." {
    & "$root\NameChange\Set-UserName.ps1" -Client $Client -SamAccountName $startSam `
        -NewLastName $NewLastName -NewUsername $endSam @applySplat
    Show-State "After the name change:" @($endSam, $startSam)
}

Invoke-Chapter 4 "LEAVING" "Last day. Locked out, access stripped, moved to the leavers area." {
    & "$root\Offboarding\Offboarding.ps1" -Client $Client -SamAccountName $endSam @applySplat
    Show-State "After offboarding:" @($endSam)
}

# The undo only means something if it comes from what was recorded before the change
$snapshot = Get-ChildItem "$root\Reports\Snapshots" -Recurse -Filter "$endSam`_before.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1

if ($snapshot) {
    Invoke-Chapter 5 "UNDO" "Wrong person. Put them back exactly as the before-snapshot recorded them." {
        & "$root\Rollback\Restore-FromSnapshot.ps1" -SnapshotFile $snapshot.FullName @applySplat
        Show-State "After the undo:" @($endSam)
    }
}
else {
    Write-Host "`n   No before-snapshot yet: run with -Apply to produce one." -ForegroundColor DarkGray
}

# ------------------------
# COLLECT WHAT IT PRODUCED
# ------------------------
$collected = 0
foreach ($pattern in @("OnboardingReport_$runStamp*", "MoverReport_$runStamp*", "NameChangeReport_$runStamp*",
                       "OffboardingReport_$runStamp*", "RestoreReport_$runStamp*")) {
    Get-ChildItem "$root\Reports" -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName -Destination $outDir -Force; $collected++
    }
}

# Reports written seconds either side of the run stamp still belong to it
if ($collected -eq 0) {
    Get-ChildItem "$root\Reports" -Filter "*.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } |
        ForEach-Object { Copy-Item $_.FullName -Destination $outDir -Force; $collected++ }
}

$snapshotDir = Join-Path $outDir "Snapshots"
$null = New-Item -ItemType Directory -Path $snapshotDir -Force
Get-ChildItem "$root\Reports\Snapshots" -Recurse -Filter "$endSam*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } |
    ForEach-Object { Copy-Item $_.FullName -Destination $snapshotDir -Force }

Stop-Transcript | Out-Null

Write-Host "`n$('=' * 70)" -ForegroundColor Green
Write-Host " Done. Everything from this run is in:" -ForegroundColor Green
Write-Host "   $outDir" -ForegroundColor Green
Write-Host "      demo.txt     what you just saw, word for word"
Write-Host "      *Report*.txt one report per step"
Write-Host "      Snapshots\   before and after, as JSON"
Write-Host "$('=' * 70)`n" -ForegroundColor Green
