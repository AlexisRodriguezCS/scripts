#Requires -Version 7.0
<#
    Works through approved HR requests in the SharePoint list and writes the result back.
    HR never runs this; it runs on a schedule (e.g. every 15 minutes).

    Preview (reads the list, changes nothing, doesn't update the list):
      .\Requests\Invoke-RequestQueue.ps1 -Client "ClientA"
    Process:
      .\Requests\Invoke-RequestQueue.ps1 -Client "ClientA" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [switch]$Apply
)

# Every people script, so any request type can be handled
Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force
Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force
Import-Module "$PSScriptRoot\..\Mover\Mover.psm1" -Force
Import-Module "$PSScriptRoot\..\UserAttributes\UserAttributes.psm1" -Force
Import-Module "$PSScriptRoot\Requests.psm1" -Force

$root    = "$PSScriptRoot\.."
$Configs = @{
    Requests    = Get-Config -Script "Requests"    -Client $Client -RootPath $root
    Onboarding  = Get-Config -Script "Onboarding"  -Client $Client -RootPath $root
    Offboarding = Get-Config -Script "Offboarding" -Client $Client -RootPath $root
}
$rq = $Configs.Requests

$null = New-Item -ItemType Directory -Path "$PSScriptRoot\Logs" -Force
$LogFile = "$PSScriptRoot\Logs\Requests.log"

# ------------------------
# AUTHENTICATE (Graph is needed to read the list, even in preview)
# ------------------------
Connect-MgGraph -TenantId $rq.TenantId -ClientId $rq.ClientId -CertificateThumbprint $rq.CertThumbprint -NoWelcome

if ($Apply) {
    Connect-ExchangeOnline -AppId $rq.ClientId -CertificateThumbprint $rq.CertThumbprint -Organization $rq.TenantDomain -ShowBanner:$false
    Connect-PnPOnline -Url $Configs.Offboarding.SharePointAdminUrl -ClientId $rq.ClientId -Thumbprint $rq.CertThumbprint -Tenant $rq.TenantDomain
}

# ------------------------
# PROCESS APPROVED REQUESTS
# ------------------------
# ponytail: reads the whole list and filters here; add an indexed Status column + server-side filter past ~5000 items
$items = @(Get-MgSiteListItem -SiteId $rq.SiteId -ListId $rq.ListName -ExpandProperty "fields" -All -ErrorAction Stop |
           Where-Object { $_.Fields.AdditionalProperties.Status -eq "Approved" })

Write-Log -Message "[Requests] $($items.Count) approved request(s) waiting" -Level "INFO" -LogFile $LogFile

$needsAttention = 0

foreach ($item in $items) {
    $fields = $item.Fields.AdditionalProperties

    # Scheduled requests (e.g. a leaver's last day at 5 PM) wait until their time; blank = as soon as possible
    if ($fields.EffectiveDate -and [datetime]$fields.EffectiveDate -gt (Get-Date)) {
        $when = ([datetime]$fields.EffectiveDate).ToString('ddd MMM d, h:mm tt')
        if ($Apply -and "$($fields.Result)" -notlike "Scheduled*") {
            Set-RequestStatus -Config $rq -ItemId $item.Id -Status "Approved" -Result "Scheduled: will run $when"
        }
        Write-Log -Message "[Requests] #$($item.Id) $($fields.RequestType) : scheduled for $when" -Level "DEBUG" -LogFile $LogFile
        continue
    }

    # Claim it first so an overlapping run can't process the same request twice
    if ($Apply) { Set-RequestStatus -Config $rq -ItemId $item.Id -Status "Processing" -Result "Started $(Get-Date -Format 'g')" }

    try {
        $outcome = Invoke-Request -Fields $fields -Configs $Configs -LogFile $LogFile -Apply $Apply.IsPresent
    }
    catch {
        $outcome = @{ Ok = $false; Message = "Needs attention: the script hit an error ($($_.Exception.Message)). IT has been alerted." }
    }

    $status = if ($outcome.Ok) { "Done" } else { "Needs attention"; $needsAttention++ }
    Write-Log -Message "[Requests] #$($item.Id) $($fields.RequestType) : $status - $($outcome.Message)" -Level $(if ($outcome.Ok) { "INFO" } else { "WARN" }) -LogFile $LogFile

    if ($Apply) { Set-RequestStatus -Config $rq -ItemId $item.Id -Status $status -Result $outcome.Message }
}

if ($needsAttention -gt 0) {
    Send-Alert -Config $rq -LogFile $LogFile -Title "HR requests ($Client): $needsAttention need attention" `
               -Message "Check the 'Needs attention' items in the $($rq.ListName) list."
    exit 1
}
