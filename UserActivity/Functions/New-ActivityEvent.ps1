function New-ActivityEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [datetime]$Time,
        [Parameter(Mandatory)] [string]$Source,     # Sign-in | Entra audit | AD | Lockout
        [Parameter(Mandatory)] [string]$Event,
        [string]$Detail,
        [ValidateSet("Success", "Failure", "Info")]
        [string]$Result = "Info",
        [int]$ErrorCode = 0
    )

    # One row in the timeline
    [pscustomobject]@{
        Time      = $Time
        Source    = $Source
        Event     = $Event
        Result    = $Result
        Detail    = $Detail
        ErrorCode = $ErrorCode
    }
}
