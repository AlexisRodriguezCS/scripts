function New-OnboardingAccessPass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $upn = $PipelineObject.Identity.EntraUPN

    # A user can only have one Temporary Access Pass, and its code is only shown when it's created
    $existing = Get-MgUserAuthenticationTemporaryAccessPassMethod -UserId $upn -ErrorAction Stop
    if ($existing) {
        return "Already has an access pass (the code was only shown when it was created; delete it to issue a new one)"
    }

    # Valid from the morning of the start date (or now), for one work day by default
    $lifetime = if ($Config.AccessPassLifetimeMinutes) { $Config.AccessPassLifetimeMinutes } else { 480 }
    $body = @{ lifetimeInMinutes = $lifetime; isUsableOnce = $false }

    $startDate = $PipelineObject.Raw.StartDate
    if ($startDate -and ([datetime]$startDate).Date -gt (Get-Date).Date) {
        $body.startDateTime = ([datetime]$startDate).Date.AddHours(8).ToUniversalTime().ToString("o")
    }

    $pass = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $upn -BodyParameter $body -ErrorAction Stop

    # Kept in memory only (never logged or reported), handed over the same way as the temp password
    $PipelineObject | Add-Member -NotePropertyName TemporaryAccessPass -NotePropertyValue $pass.TemporaryAccessPass -Force

    $from = if ($body.startDateTime) { ([datetime]$startDate).ToString('MMM d') + " 8:00" } else { "now" }
    return "Created (valid from $from for $lifetime minutes)"
}
