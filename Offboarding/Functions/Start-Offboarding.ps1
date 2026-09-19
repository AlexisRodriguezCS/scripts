function Start-Offboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        # When set, the user's state is saved here before and after the changes
        [string]$SnapshotFolder
    )

    $correlationId = $PipelineObject.CorrelationId.Substring(0,8)

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-Log -Message "[$correlationId] [Offboarding] SKIP → $($PipelineObject.Raw.SamAccountName) : Status $($PipelineObject.Status)" `
            -Level "WARN" -LogFile $LogFile
        return $PipelineObject
    }

    # Action -> function to call + retry settings
    $actions = @{
        DisableAccount              = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Disable-OffboardingAccount -Identity $p.Identity -LogFile $LogFile } }
        RevokeSessions              = @{ MaxRetries = 4; DelaySeconds = 5;  Run = { param($p, $t) Revoke-OffboardingSession -Identity $p.Identity -LogFile $LogFile } }
        RetireDevices               = @{ MaxRetries = 3; DelaySeconds = 10; Run = { param($p, $t) Invoke-OffboardingDeviceRetire -Identity $p.Identity -LogFile $LogFile } }
        RemoveFromGroup             = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Remove-OffboardingGroupMember -Identity $p.Identity -Target $t -LogFile $LogFile } }
        MoveToDisabledOU            = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Move-OffboardingUser -Identity $p.Identity -Target $t -LogFile $LogFile } }
        RemoveFromDistributionLists = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Remove-OffboardingDLMember -Identity $p.Identity -LogFile $LogFile } }
        ConvertMailbox              = @{ MaxRetries = 3; DelaySeconds = 10; Run = { param($p, $t) Convert-OffboardingMailbox -Identity $p.Identity -LogFile $LogFile } }
        SetAutoReply                = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Set-OffboardingAutoReply -Identity $p.Identity -Target $t -Config $Config -LogFile $LogFile } }
        GrantMailboxAccess          = @{ MaxRetries = 3; DelaySeconds = 5;  Run = { param($p, $t) Grant-OffboardingMailboxAccess -Identity $p.Identity -Target $t -LogFile $LogFile } }
        ShareOneDrive               = @{ MaxRetries = 3; DelaySeconds = 10; Run = { param($p, $t) Grant-OffboardingOneDriveAccess -Identity $p.Identity -Target $t -LogFile $LogFile } }
        RemoveLicenses              = @{ MaxRetries = 4; DelaySeconds = 5;  Run = { param($p, $t) Remove-OffboardingLicense -Identity $p.Identity -LogFile $LogFile } }
    }

    # Results for reporting
    $resultText = @{
        Removed             = "Removed from {0}"
        NotMember           = "Not in {0}"
        AlreadyShared       = "Already shared"
        NoMailbox           = "No mailbox"
        NoLicenses          = "No licenses"
        NoOneDrive          = "No OneDrive"
        NoDistributionLists = "No distribution lists"
        NoDevices           = "No Intune devices"
    }

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage Before -Folder $SnapshotFolder -LogFile $LogFile }

    # Don't strip access from an account that is still active
    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -ResultText $resultText `
                      -StopOnFailure "DisableAccount" -LogFile $LogFile

    if ($SnapshotFolder) { $null = Save-UserSnapshot -PipelineObject $PipelineObject -Stage After -Folder $SnapshotFolder -LogFile $LogFile }

    $PipelineObject.Status = if ($ok) { "Offboarded" } else { "Failed" }

    return $PipelineObject
}
