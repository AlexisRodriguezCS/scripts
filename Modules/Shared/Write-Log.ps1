function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Message,

        [ValidateSet("DEBUG","INFO","WARN","ERROR")]
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
        
        switch ($Level) {
            "DEBUG" { Write-Verbose "$Message" }
            "INFO"  { Write-Host  "$Message" }
            "WARN"  { Write-Warning "$Message" }
            "ERROR" { Write-Host "$Message" }
        }
    }
    catch {
        Write-Warning "Failed to write log: $_"
    }
}