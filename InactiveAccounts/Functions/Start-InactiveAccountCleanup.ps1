function Start-InactiveAccountCleanup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [string]$SnapshotFolder
    )

    if ($PipelineObject.Status -ne "Inactive") { return $PipelineObject }

    $actions = @{
        DisableAccount = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Disable-InactiveAccount -Raw $p.Raw -LogFile $LogFile } }
        RemoveGuest    = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Remove-InactiveGuest -Raw $p.Raw -LogFile $LogFile } }
    }

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage Before -Folder $SnapshotFolder -LogFile $LogFile }

    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -LogFile $LogFile

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage After -Folder $SnapshotFolder -LogFile $LogFile }

    $PipelineObject.Status = if (-not $ok) { "Failed" } elseif ($PipelineObject.Raw.UserType -eq "Guest") { "Removed" } else { "Disabled" }

    return $PipelineObject
}
