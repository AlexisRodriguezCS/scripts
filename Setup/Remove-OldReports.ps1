#Requires -Version 7.0
<#
    Deletes reports, snapshots and access review sheets older than the retention period.
    Snapshots and reports contain personal data (names, groups, managers), so they shouldn't be kept forever.

    Preview: .\Setup\Remove-OldReports.ps1
    Delete:  .\Setup\Remove-OldReports.ps1 -Apply
#>
[CmdletBinding()]
param(
    [string]$Path = "$PSScriptRoot\..\Reports",

    # Match your company's data retention policy
    [ValidateRange(7, 3650)]
    [int]$Days = 90,

    [switch]$Apply
)

if (-not (Test-Path $Path)) { return }

$cutoff = (Get-Date).AddDays(-$Days)
$old    = @(Get-ChildItem -Path $Path -Recurse -File | Where-Object LastWriteTime -lt $cutoff)

foreach ($file in $old) {
    if ($Apply) { Remove-Item -Path $file.FullName -Force }
    else        { Write-Host "Would delete: $($file.FullName)" }
}

# Remove run folders that are now empty (Snapshots\Offboarding_..., AccessReview_...)
if ($Apply) {
    Get-ChildItem -Path $Path -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -Path $_.FullName -Force) } | Remove-Item -Force
}

Write-Host "$(if ($Apply) { 'Deleted' } else { 'Would delete' }) $($old.Count) file(s) older than $Days days from $Path"
