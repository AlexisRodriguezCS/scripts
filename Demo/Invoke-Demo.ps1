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

    # Show every log line on screen. Off by default: the full output of each step is
    # saved to its own file either way, so the screen stays readable.
    [switch]$Detailed,

    [switch]$Apply
)

$ErrorActionPreference = "Continue"
$root     = Split-Path $PSScriptRoot -Parent
$runStart = Get-Date
$runStamp = $runStart.ToString('yyyyMMdd_HHmmss')
$outDir   = Join-Path $PSScriptRoot "Output\Demo_$runStamp"
$null     = New-Item -ItemType Directory -Path $outDir -Force

$startSam = "$($FirstName.ToLower())$($LastName.ToLower())"
$endSam   = "$($FirstName.ToLower())$($NewLastName.ToLower())"

# An on-prem client skips every Microsoft 365 step, which is most of them
$onboardingConfig = "$root\Config\Clients\$Client\Onboarding.json"
$script:isOnPrem  = (Test-Path $onboardingConfig) -and
                    ((Get-Content $onboardingConfig -Raw | ConvertFrom-Json).Environment -eq "OnPrem")

Import-Module ActiveDirectory

# Everything printed is also kept, so a screenshot and a file say the same thing
Start-Transcript -Path (Join-Path $outDir "demo.txt") | Out-Null

# Each state is also kept as an object, so summary.json describes the whole run
$script:timeline = [System.Collections.Generic.List[object]]::new()

function Show-State {
    param([string]$Label, [string[]]$Names)

    $user = $null
    foreach ($name in $Names) {
        $user = Get-ADUser -Filter "SamAccountName -eq '$name'" -Properties DisplayName, Title, Department, Enabled, MemberOf -ErrorAction SilentlyContinue
        if ($user) { break }
    }

    if (-not $user) {
        Write-Host "   $Label no account" -ForegroundColor DarkGray
        $script:timeline.Add([pscustomobject]@{ Stage = $Label; Exists = $false })
        return
    }

    $groups = @($user.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' })
    $ou     = ($user.DistinguishedName -split ',', 2)[1] -replace ',DC=.+$'

    $fields = [ordered]@{
        "Name    " = "$($user.DisplayName)   ($($user.SamAccountName))"
        "Job     " = "$($user.Title), $($user.Department)"
        "Enabled " = "$($user.Enabled)"
        "Where   " = $ou
        "Access  " = $(if ($groups) { $groups -join ', ' } else { 'none' })
    }

    Write-Host "   $Label" -ForegroundColor Yellow
    foreach ($field in $fields.Keys) {
        # Mark what this step actually changed: without it a rename looks like nothing
        # happened, because job, OU and access are meant to stay exactly as they were
        $changed = $script:lastFields -and $script:lastFields[$field] -ne $fields[$field]
        $marker  = if ($changed) { "   <- changed" } else { "" }

        Write-Host "      $field : $($fields[$field])$marker" -ForegroundColor $(if ($changed) { "Green" } else { "Gray" })
    }
    $script:lastFields = $fields

    $script:timeline.Add([pscustomobject]@{
        Stage          = $Label
        Exists         = $true
        DisplayName    = "$($user.DisplayName)"
        SamAccountName = "$($user.SamAccountName)"
        Title          = "$($user.Title)"
        Department     = "$($user.Department)"
        Enabled        = [bool]$user.Enabled
        OU             = $ou
        Groups         = $groups
    })
}

function Invoke-Chapter {
    param([int]$Number, [string]$Title, [string]$Story, [string]$StepName, [string]$SkippedInCloud, [scriptblock]$Run)

    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host " $Number. $Title" -ForegroundColor Cyan
    Write-Host " $Story" -ForegroundColor Gray
    Write-Host "$('=' * 70)" -ForegroundColor Cyan

    $start = Get-Date

    # Everything the step printed, kept whole in its own file.
    # *>&1 and not 2>&1: the scripts log with Write-Host, which is its own stream.
    $output = & $Run *>&1 | Out-String
    $output | Out-File (Join-Path $outDir "$Number-$StepName.log") -Encoding utf8

    if ($Detailed) {
        Write-Host $output.TrimEnd()
    }
    else {
        # The lines that say what actually changed: "AddToGroup -> GRP-AllStaff : Added"
        # Planned-but-not-yet-run lines (PENDING) and the correlation id are noise here.
        $did = $output -split "`r?`n" |
               Where-Object { $_ -match '^\[[0-9a-f]{8}\]\s+\w+\s+->' -and $_ -notmatch ': PENDING\s*$' } |
               ForEach-Object {
                   # Drop the correlation id and shorten full DNs to just the group or OU name
                   $line = $_ -replace '^\[[0-9a-f]{8}\]\s+', ''
                   $line = $line -replace 'CN=([^,]+),OU=[^:]+', '$1'
                   $line = $line -replace '(OU=[^,]+),OU=[^:]+', '$1'
                   "      $line"
               }

        if ($did) { $did | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray } }

        # Never hide a problem to make the demo look tidy.
        # -cmatch for FAILED: -match is case-insensitive and would flag a healthy "Failed: 0".
        $output -split "`r?`n" |
            Where-Object { $_ -match 'WARNING|Missing module' -or $_ -cmatch 'FAILED' -or $_ -match 'Failed:\s*[1-9]' } |
            ForEach-Object { Write-Host "      $($_.Trim())" -ForegroundColor Yellow }
    }

    # On an on-prem client the Microsoft 365 steps never run. Saying so beats letting
    # someone think the script only does the four things they can see.
    if ($SkippedInCloud -and $script:isOnPrem) {
        Write-Host "      (skipped, this client has no Microsoft 365: $SkippedInCloud)" -ForegroundColor DarkCyan
    }

    Write-Host "   ... $([math]::Round(((Get-Date) - $start).TotalSeconds, 1))s" -ForegroundColor DarkGray
}

Write-Host @"

  Employee lifecycle demo - $Client
  $(if ($Apply) { "LIVE: this will change Active Directory" } else { "PREVIEW: nothing will be changed (add -Apply)" })
  $(if ($script:isOnPrem) { "This client is Active Directory only, so every Microsoft 365 step is skipped." } else { "Hybrid client: Active Directory and Microsoft 365." })
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

Invoke-Chapter 1 "HIRED" "HR sends a new starter. Account, right department, right access, temporary password." "hired" `
    "Entra sync, Microsoft 365 license, mailbox, distribution lists, day-one access pass" {
    & "$root\Onboarding\Onboarding.ps1" -Client $Client -FirstName $FirstName -LastName $LastName `
        -Title "Sales Rep" -Department Sales -Role "Sales Rep" @applySplat
}
Show-State "After hiring:" @($startSam)

Invoke-Chapter 2 "PROMOTED" "Moving to IT. Old access comes off, new access goes on, and they move department." "promoted" `
    "swapping the department distribution lists and the role's Microsoft 365 license" {
    & "$root\Mover\Mover.ps1" -Client $Client -SamAccountName $startSam `
        -Title "Support Technician" -Department IT -Role Technician @applySplat
}
Show-State "After the role change:" @($startSam)

Invoke-Chapter 3 "NAME CHANGE" "They got married. New name, new username, and mail to the old address still arrives." "namechange" `
    "pushing the new name to Microsoft 365 straight away instead of waiting for the next sync" {
    & "$root\NameChange\Set-UserName.ps1" -Client $Client -SamAccountName $startSam `
        -NewLastName $NewLastName -NewUsername $endSam @applySplat
}
Show-State "After the name change:" @($endSam, $startSam)

Invoke-Chapter 4 "LEAVING" "Last day. Locked out, access stripped, moved to the leavers area." "leaving" `
    "signing them out everywhere, wiping company data from their phone, handing the mailbox and OneDrive to their manager, out of office, hiding them from the address book, freeing the license" {
    & "$root\Offboarding\Offboarding.ps1" -Client $Client -SamAccountName $endSam @applySplat
}
Show-State "After offboarding:" @($endSam)

# The undo only means something if it comes from what was recorded before the change
$snapshot = Get-ChildItem "$root\Reports\Snapshots" -Recurse -Filter "$endSam`_before.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1

if ($snapshot) {
    Invoke-Chapter 5 "UNDO" "Wrong person. Put them back exactly as the before-snapshot recorded them." "undo" `
        "the license and mailbox type, which the report lists for a person to put back by hand" {
        & "$root\Rollback\Restore-FromSnapshot.ps1" -SnapshotFile $snapshot.FullName @applySplat
    }
    Show-State "After the undo:" @($endSam)
}
else {
    Write-Host "`n   No before-snapshot yet: run with -Apply to produce one." -ForegroundColor DarkGray
}

# ------------------------
# COLLECT WHAT IT PRODUCED
# ------------------------
# Written since this run began, so an earlier run's reports are never swept in.
# The file name's timestamp is a second or two after $runStamp, so it can't be matched on.
Get-ChildItem "$root\Reports" -Filter "*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $runStart } |
    ForEach-Object { Copy-Item $_.FullName -Destination $outDir -Force }

$snapshotDir = Join-Path $outDir "Snapshots"
$null = New-Item -ItemType Directory -Path $snapshotDir -Force
Get-ChildItem "$root\Reports\Snapshots" -Recurse -Filter "$endSam*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $runStart } |
    ForEach-Object { Copy-Item $_.FullName -Destination $snapshotDir -Force }

# The same story as an object: what a page or another script would read
[pscustomobject]@{
    Client   = $Client
    RunAt    = (Get-Date).ToString("s")
    Employee = "$FirstName $LastName"
    Timeline = $script:timeline
} | ConvertTo-Json -Depth 5 | Out-File (Join-Path $outDir "summary.json") -Encoding utf8

Stop-Transcript | Out-Null

Write-Host "`n$('=' * 70)" -ForegroundColor Green
Write-Host " Done. Everything from this run is in:" -ForegroundColor Green
Write-Host "   $outDir" -ForegroundColor Green
Write-Host "      demo.txt      what you just saw, word for word"
Write-Host "      summary.json  the same story as data, for a page or another script"
Write-Host "      1-hired.log   the full output of each step"
Write-Host "      *Report*.txt  one report per step"
Write-Host "      Snapshots\    before and after, as JSON"
Write-Host "$('=' * 70)`n" -ForegroundColor Green
