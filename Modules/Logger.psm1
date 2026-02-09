function Write-Log {
    param(
        # The message we want to log (required)
        [Parameter(Mandatory)]
        [string]$Message,

        # Log types, default is INFO
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO",

        # Log file path
        [Parameter(Mandatory)]
        [string]$LogFile 
    )

    # Get the current date and time
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Build the log line and write it to the log file
    "$Time | $Level | $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Export-ModuleMember -Function Write-Log