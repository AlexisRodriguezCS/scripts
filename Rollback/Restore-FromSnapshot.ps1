#Requires -Version 7.0
<#
    Put a user back the way a "before" snapshot recorded them (wrong offboarding, role change to undo...).
    IT runs this by hand.

    Preview: .\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json
    Restore: .\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile ...\jdoe_before.json -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SnapshotFile,

    [switch]$Apply
)

Import-Module "$PSScriptRoot\Rollback.psm1" -Force

if (-Not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    throw "Missing module: ActiveDirectory"
}

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\Rollback.log"

$result = Invoke-RestoreFromSnapshot -SnapshotFile $SnapshotFile -LogFile $LogFile -Apply $Apply.IsPresent
$result

if ($result.Status -eq "Failed") { exit 1 }
