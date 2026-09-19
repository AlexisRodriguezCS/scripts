function Start-PasswordExpiryReminder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [hashtable]$SentLog
    )

    if ($PipelineObject.Status -ne "Due") { return $PipelineObject }

    $actions = @{
        SendReminder = @{ MaxRetries = 3; DelaySeconds = 10; Run = { param($p, $t) Send-PasswordExpiryEmail -Raw $p.Raw -Config $Config -LogFile $LogFile } }
    }

    $ok = Invoke-Plan -PipelineObject $PipelineObject -Actions $actions -LogFile $LogFile

    if ($ok) {
        # Remember it so the next run doesn't send it again
        $SentLog[$PipelineObject.Raw.SentKey] = (Get-Date).ToString('yyyy-MM-dd')
        $PipelineObject.Status = "Sent"
    } else {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}
