function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5,
        [string]$LogFile
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            return & $Action
        }
        catch {
            Write-Log -Message "[RETRY] Attempt $attempt failed: $($_.Exception.Message)" -Level "WARN" -LogFile $LogFile
            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds ($DelaySeconds * $attempt)
            }
            else {
                throw "Action failed after $MaxRetries attempts: $($_.Exception.Message)"
            }
        }
    }
}