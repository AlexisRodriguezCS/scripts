function Add-PipelineError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject]$PipelineObject,
        [Parameter(Mandatory)] [string]$Step,
        [Parameter(Mandatory)] [string]$Message,
        [System.Exception]$Exception,
        [string]$LogFile
    )

    $type = "Logic"
    $retry = $false
    $exceptionMessage = $null
    $exceptionType = $null

    if ($Exception) {
        $exceptionMessage = $Exception.Message
        $exceptionType    = $Exception.GetType().FullName

        switch -Regex ($exceptionMessage.ToLower()) {
            "timeout|timed out|connection|network|unreachable" {
                $type = "Network"; $retry = $true
            }
            "throttl|rate limit|too many requests" {
                $type = "Throttle"; $retry = $true
            }
            "already exists|duplicate|conflict" {
                $type = "Conflict"; $retry = $false
            }
            "not found|cannot find|does not exist" {
                $type = "Dependency"; $retry = $true
            }
            "unauthorized|forbidden|access denied" {
                $type = "Auth"; $retry = $false
            }
            default {
                $type = "Logic"; $retry = $false
            }
        }
    }

    $errorObject = [pscustomobject]@{
        CorrelationId = $PipelineObject.CorrelationId
        Step          = $Step
        Type          = $type
        Message       = $Message
        ExceptionType = $exceptionType
        Exception     = $exceptionMessage
        Timestamp     = Get-Date
        IsRetryable   = $retry
    }

    # Store error
    $PipelineObject.Errors.Add($errorObject)

    # Set pipeline status
    $PipelineObject.Status = "Failed"

    # Optional: log immediately if LogFile provided
    if ($LogFile) {
        Write-Log -Level "ERROR" -LogFile $LogFile -Message $errorObject
    }
}