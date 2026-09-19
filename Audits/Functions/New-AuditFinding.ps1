function New-AuditFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Check,
        [Parameter(Mandatory)] [string]$Name,
        [string]$Detail,
        [bool]$Flagged = $false,
        [string]$Reason
    )

    # One row in an audit report; Flagged rows go to NEEDS ATTENTION
    [pscustomobject]@{
        Check   = $Check
        Name    = $Name
        Detail  = $Detail
        Flagged = $Flagged
        Reason  = $Reason
    }
}
