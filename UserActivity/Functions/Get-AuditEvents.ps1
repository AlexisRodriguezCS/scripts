function Get-AuditEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$UserId,
        [Parameter(Mandatory)] [datetime]$Since
    )

    $since = $Since.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

    # Things done TO the user (admin reset, group added...) and BY the user (SSPR, MFA registration...)
    $audits = @(Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge $since and targetResources/any(t:t/id eq '$UserId')" -All -ErrorAction Stop) +
              @(Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge $since and initiatedBy/user/id eq '$UserId'" -All -ErrorAction Stop)

    foreach ($audit in $audits | Sort-Object Id -Unique) {
        $by = if ($audit.InitiatedBy.User.UserPrincipalName) { $audit.InitiatedBy.User.UserPrincipalName }
              elseif ($audit.InitiatedBy.App.DisplayName)    { "app: $($audit.InitiatedBy.App.DisplayName)" }
              else { "system" }

        $failed = "$($audit.Result)" -ne "success"

        New-ActivityEvent -Time $audit.ActivityDateTime -Source "Entra audit" `
            -Event "$($audit.ActivityDisplayName)$(if ($failed) { " (FAILED: $($audit.ResultReason))" })" `
            -Detail "By: $by | Service: $($audit.LoggedByService) | Category: $($audit.Category)" `
            -Result $(if ($failed) { "Failure" } else { "Info" })
    }
}
