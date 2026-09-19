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

        # Mask any secret loaded by Get-Config (e.g. a webhook URL inside an error message)
        foreach ($secret in $script:SecretValues) {
            $Message = "$Message".Replace($secret, "***")
        }

        # Rotate at 10 MB and keep the last 5, so a scheduled task can't fill the disk
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 10MB) {
            Move-Item -Path $LogFile -Destination "$LogFile.$(Get-Date -Format 'yyyyMMddHHmmss')" -Force
            Get-ChildItem -Path "$LogFile.*" | Sort-Object Name -Descending | Select-Object -Skip 5 | Remove-Item -Force
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