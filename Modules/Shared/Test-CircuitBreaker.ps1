function Test-CircuitBreaker {
    <#
        Stops a bulk run that is clearly hitting a broken system.

        If the last few users in a row all failed, Microsoft 365 or AD is down, the
        certificate expired, or a permission was removed. Grinding through the rest
        of the CSV only wastes time, fills the log with the same error and risks
        getting rate limited, so the run stops and the rest are reported as Stopped.

        Only "Failed" counts: a bad CSV row (Invalid) or a user that doesn't exist
        (NotFound) is a data problem, not an outage.
    #>
    [CmdletBinding()]
    param(
        # Users already run, in the order they were run
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Processed,

        [PSCustomObject]$Config,

        [string]$LogFile
    )

    # Failures in a row before stopping; 0 turns the breaker off
    $limit = if ($null -ne $Config.MaxConsecutiveFailures) { [int]$Config.MaxConsecutiveFailures } else { 5 }
    if ($limit -le 0) { return $false }

    $done = @($Processed)
    if ($done.Count -lt $limit) { return $false }

    $recent = $done[($done.Count - $limit)..($done.Count - 1)]
    if (@($recent | Where-Object Status -eq "Failed").Count -lt $limit) { return $false }

    $lastError = @($recent[-1].Errors)[-1]
    $because   = if ($lastError -is [string]) { $lastError } else { "$($lastError.Step): $($lastError.Exception)" }

    Write-Log -Message "[CircuitBreaker] $limit in a row failed, stopping the run: $because" -Level "ERROR" -LogFile $LogFile

    return $true
}
