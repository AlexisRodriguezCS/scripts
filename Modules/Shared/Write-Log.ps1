function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Message,

        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO",

        [string]$LogFile = "$PSScriptRoot\Logs\Script.log"
    )

    try {
        $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Convert objects to JSON automatically
        if ($Message -isnot [string]) {
            $Message = $Message | ConvertTo-Json -Compress -Depth 5
        }

        "$Time | $Level | $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
        
        Write-Verbose "${Level}: ${Message}"
    }
    catch {
        Write-Warning "Failed to write log: $_"
    }
}