function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            return & $Action
        }
        catch {
            Write-LogAndVerbose -Message "[RETRY] Attempt $attempt failed: $($_.Exception.Message)" -Level "WARN"
            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds ($DelaySeconds * $attempt)
            }
            else {
                throw "Action failed after $MaxRetries attempts: $($_.Exception.Message)"
            }
        }
    }
}