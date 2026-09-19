function Start-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $correlationId = $PipelineObject.CorrelationId.Substring(0,8)
    $displayName   = $PipelineObject.Identity.DisplayName

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -in @("Invalid","Failed")) {
        Write-Log -Message "[$correlationId] [Onboarding] SKIP → $displayName : Previous errors" `
            -Level "WARN" -LogFile $LogFile
        return $PipelineObject
    }

    # Action -> function to call + retry settings
    $actions = @{
        WaitForEntra          = @{ MaxRetries = 10; DelaySeconds = 30; Run = { param($p, $t) Wait-ForEntraUser -Identity $p.Identity -LogFile $LogFile } }
        CreateAccessPass      = @{ MaxRetries = 3;  DelaySeconds = 10; Run = { param($p, $t) New-OnboardingAccessPass -PipelineObject $p -Config $Config -LogFile $LogFile } }
        AddToGroup            = @{ MaxRetries = 3;  DelaySeconds = 5;  Run = { param($p, $t) Add-OnboardingGroupMember -Identity $p.Identity -Target $t -LogFile $LogFile } }
        AssignLicense         = @{ MaxRetries = 4;  DelaySeconds = 5;  Run = { param($p, $t) Set-OnboardingLicense -Identity $p.Identity -Config $Config -LogFile $LogFile } }
        # Mailbox takes a few minutes to appear after licensing
        AddToDistributionList = @{ MaxRetries = 8;  DelaySeconds = 20; Run = { param($p, $t) Add-OnboardingDLMember -Identity $p.Identity -Target $t -LogFile $LogFile } }
    }

    # Results for reporting
    $resultText = @{
        Added           = "Added to {0}"
        AlreadyExists   = "Already in {0}"
        AlreadyAssigned = "Already assigned {0}"
        Found           = "User found"
    }

    # Nothing else can work until the user exists in Entra
    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -ResultText $resultText `
                      -StopOnFailure "WaitForEntra" -LogFile $LogFile

    # Keep Created / AlreadyExists on success so the report shows what happened to the account
    if (-not $ok) {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}
