# Logging function
function Write-Log {
    [CmdletBinding()]
    param(
        # The message we want to log (required)
        [Parameter(Mandatory)]
        [string]$Message,

        # Log types, default is INFO
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO",

        # Log file path
        [string]$LogFile = "$PSScriptRoot\Company.Identity.log"
    )

    # Try/Catch so it doesn’t stop the script
    try {
        # Get the current date and time
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Build the log line and write it to the log file
        "$Time | $Level | $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
    catch {
        Write-Warning "Failed to write log: $_"
    }
}

# Log + verbose helper
function Write-LogAndVerbose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO",

        [string]$LogFile = "$PSScriptRoot\Company.Identity.log"
    )

    Write-Log -Message $Message -Level $Level -LogFile $LogFile
    Write-Verbose "${Level}: ${Message}"
}

Export-ModuleMember -Function Write-Log, Write-LogAndVerbose
