function Start-UserAttributesUpdate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [string]$SnapshotFolder
    )

    if ($PipelineObject.Status -ne "Valid") { return $PipelineObject }

    $actions = @{
        SetAttribute = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t, $item) Set-UserAttribute -Identity $p.Identity -Attribute $t -Value $item.Value -Old $item.Old -LogFile $LogFile } }
    }

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage Before -Folder $SnapshotFolder -LogFile $LogFile }

    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -LogFile $LogFile

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage After -Folder $SnapshotFolder -LogFile $LogFile }

    $PipelineObject.Status = if ($ok) { "Updated" } else { "Failed" }

    return $PipelineObject
}
