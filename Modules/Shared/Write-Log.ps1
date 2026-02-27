function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO",

        [string]$LogFile = "$PSScriptRoot\Logs\Script.log"
    )

    try {
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$Time | $Level | $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
        Write-Verbose "${Level}: ${Message}"
    }
    catch {
        Write-Warning "Failed to write log: $_"
    }
}