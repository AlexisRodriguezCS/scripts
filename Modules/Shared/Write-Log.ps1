function Write-Log {
    <#
        Writes one line to a human-readable log and the same event to a .jsonl file
        next to it, so logs can be read by a person or queried by a machine.

        Callers pass the plain path (Logs\Onboarding.log). The day is added here:
        Logs\Onboarding-2026-09-20.log, so "what happened on the 14th" is one file.
        Setup\Remove-OldReports.ps1 deletes them once they pass the retention period.
    #>
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
        $now = Get-Date

        # One id for this execution. The correlation id follows a person; this follows the run,
        # so "everything Tuesday's 5pm batch did" is one filter instead of a guess from timestamps.
        if (-not $script:LogRunId) {
            $script:LogRunId = [guid]::NewGuid().ToString('N').Substring(0, 8)
        }

        # Convert objects to JSON automatically
        if ($Message -isnot [string]) {
            $Message = $Message | ConvertTo-Json -Compress -Depth 5
        }

        # Mask any secret loaded by Get-Config (e.g. a webhook URL inside an error message)
        foreach ($secret in $script:SecretValues) {
            $Message = "$Message".Replace($secret, "***")
        }

        # One file per day: Logs\Onboarding.log becomes Logs\Onboarding-2026-09-20.log
        $directory = Split-Path $LogFile -Parent
        $baseName  = [IO.Path]::GetFileNameWithoutExtension($LogFile)
        $extension = [IO.Path]::GetExtension($LogFile)
        if (-not $extension) { $extension = ".log" }

        $dayStamp  = $now.ToString('yyyy-MM-dd')
        $dailyLog  = Join-Path $directory "$baseName-$dayStamp$extension"
        $dailyJson = Join-Path $directory "$baseName-$dayStamp.jsonl"

        if ($directory -and -not (Test-Path $directory)) {
            $null = New-Item -ItemType Directory -Path $directory -Force
        }

        "$($now.ToString('yyyy-MM-dd HH:mm:ss')) | $Level | $Message" | Out-File -FilePath $dailyLog -Append -Encoding utf8

        # The same event as data. Most messages follow "[correlation] [Step] rest",
        # so those parts become fields you can filter on instead of grepping.
        $correlationId = $null
        $step          = $null
        $detail        = "$Message"

        if ($detail -match '^\[([0-9a-fA-F-]{6,})\]\s*(.*)$') {
            $correlationId = $Matches[1]
            $detail        = $Matches[2]
        }
        if ($detail -match '^\[([^\]]+)\]\s*(.*)$') {
            $step   = $Matches[1]
            $detail = $Matches[2]
        }

        [pscustomobject]@{
            Time          = $now.ToString('o')
            Level         = $Level
            RunId         = $script:LogRunId   # this execution
            Client        = $script:LogClient  # set by Get-Config
            Script        = $baseName
            CorrelationId = $correlationId     # this person, within the run
            Step          = $step
            Message       = $detail
        } | ConvertTo-Json -Compress -Depth 3 | Out-File -FilePath $dailyJson -Append -Encoding utf8

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
