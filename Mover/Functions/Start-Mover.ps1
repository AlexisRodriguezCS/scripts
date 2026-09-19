function Start-Mover {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [string]$SnapshotFolder
    )

    if ($PipelineObject.Status -ne "Valid") { return $PipelineObject }

    # Action -> function to call + retry settings
    $actions = @{
        SetAttribute          = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t, $item) Set-UserAttribute -Identity $p.Identity -Attribute $t -Value $item.Value -LogFile $LogFile } }
        AddToGroup            = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Add-OnboardingGroupMember -Identity $p.Identity -Target $t -LogFile $LogFile } }
        RemoveFromGroup       = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Remove-OffboardingGroupMember -Identity $p.Identity -Target $t -LogFile $LogFile } }
        MoveToDepartmentOU    = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Move-OffboardingUser -Identity $p.Identity -Target $t -LogFile $LogFile } }
        SyncDistributionLists = @{ MaxRetries = 3; DelaySeconds = 10; Run = { param($p, $t) Sync-MoverDLMembership -Identity $p.Identity -Target $t -Config $Config -LogFile $LogFile } }
    }

    $resultText = @{
        Added         = "Added to {0}"
        AlreadyExists = "Already in {0}"
        Removed       = "Removed from {0}"
        NotMember     = "Not in {0}"
        NoMailbox     = "No mailbox"
    }

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage Before -Folder $SnapshotFolder -LogFile $LogFile }

    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -ResultText $resultText -LogFile $LogFile

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage After -Folder $SnapshotFolder -LogFile $LogFile }

    $PipelineObject.Status = if ($ok) { "Moved" } else { "Failed" }

    return $PipelineObject
}
