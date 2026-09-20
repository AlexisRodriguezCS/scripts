function Start-NameChange {
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

    $keepOld = $PipelineObject.Raw.KeepOldEmail

    $actions = @{
        RenameAccount   = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Rename-UserAccount -Identity $p.Identity -LogFile $LogFile } }
        ChangeLogonName = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Set-UserLogonName -Identity $p.Identity -LogFile $LogFile } }
        UpdateEmail     = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Update-UserEmailAddress -Identity $p.Identity -Target $t -KeepOld $keepOld -LogFile $LogFile } }
        # A failed sync isn't fatal: the scheduled cycle picks the change up within 30 minutes
        SyncToEntra     = @{ MaxRetries = 2; DelaySeconds = 10; Run = { param($p, $t) Invoke-EntraSync -Config $Config -LogFile $LogFile; "Sync started" } }
    }

    $resultText = @{
        AlreadyRenamed = "Username was already changed"
        AlreadyPrimary = "{0} is already the main address"
    }

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage Before -Folder $SnapshotFolder -LogFile $LogFile }

    # The name has to change before anything else: every later step uses the renamed object
    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -ResultText $resultText `
                      -StopOnFailure "RenameAccount" -LogFile $LogFile

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage After -Folder $SnapshotFolder -LogFile $LogFile }

    $PipelineObject.Status = if ($ok) { "Renamed" } else { "Failed" }

    return $PipelineObject
}
