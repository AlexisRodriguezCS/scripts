function Save-IncidentEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        # Folder for this incident (kept, not auto-deleted)
        [Parameter(Mandatory)]
        [string]$Folder,

        [int]$SignInDays = 7,

        [string]$LogFile
    )

    # Collected BEFORE anything is changed: cleaning up first would destroy what the attacker did
    $identity = $PipelineObject.Identity
    $null = New-Item -ItemType Directory -Path $Folder -Force

    # Inbox rules and forwarding (how attackers quietly copy or hide email)
    $mailbox = Get-Mailbox -Identity $identity.EntraUPN -ErrorAction SilentlyContinue
    $rules   = @(if ($mailbox) { Get-InboxRule -Mailbox $identity.EntraUPN -ErrorAction SilentlyContinue })
    $rules | Select-Object Name, Identity, Enabled, ForwardTo, RedirectTo, ForwardAsAttachmentTo, DeleteMessage, MoveToFolder, MarkAsRead, Description |
        ConvertTo-Json -Depth 5 | Out-File (Join-Path $Folder "inbox-rules.json") -Encoding utf8

    # Sign-ins (where and how the attacker got in)
    $since    = (Get-Date).AddDays(-$SignInDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $signIns  = @(Get-MgAuditLogSignIn -Filter "userId eq '$($identity.Id)' and createdDateTime ge $since" -All -ErrorAction SilentlyContinue)
    $signIns | Select-Object CreatedDateTime, IPAddress, AppDisplayName, ClientAppUsed,
                             @{ n = "Country"; e = { $_.Location.CountryOrRegion } }, @{ n = "City"; e = { $_.Location.City } },
                             @{ n = "Result"; e = { $_.Status.ErrorCode } } |
        Export-Csv (Join-Path $Folder "sign-ins.csv") -NoTypeInformation

    # MFA methods (attackers often register their own so they can get back in)
    $methods = @(Get-MgUserAuthenticationMethod -UserId $identity.Id -ErrorAction SilentlyContinue)
    $methods | Select-Object Id, @{ n = "Type"; e = { $_.AdditionalProperties.'@odata.type' } }, @{ n = "Created"; e = { $_.AdditionalProperties.createdDateTime } } |
        ConvertTo-Json -Depth 5 | Out-File (Join-Path $Folder "mfa-methods.json") -Encoding utf8

    # Apps this user consented to. Only their own grants (consentType "Principal"): a grant made
    # for "AllPrincipals" is an admin consent for the whole tenant, and pulling that would cut
    # everyone off from a legitimate app.
    $grants = @(Get-MgUserOauth2PermissionGrant -UserId $identity.Id -All -ErrorAction SilentlyContinue |
                Where-Object { "$($_.ConsentType)" -eq "Principal" })
    $grants | Select-Object Id, ClientId, ResourceId, Scope |
        ConvertTo-Json -Depth 5 | Out-File (Join-Path $Folder "oauth-grants.json") -Encoding utf8

    $PipelineObject.Evidence = [pscustomobject]@{
        Folder     = $Folder
        Mailbox    = $mailbox
        Forwarding = if ($mailbox) { @($mailbox.ForwardingSmtpAddress, $mailbox.ForwardingAddress) | Where-Object { $_ } } else { @() }
        Rules      = $rules
        Grants     = $grants
        SignIns    = $signIns
        Countries  = @($signIns | ForEach-Object { $_.Location.CountryOrRegion } | Where-Object { $_ } | Sort-Object -Unique)
        # Methods added in the sign-in window deserve a human look
        NewMethods = @($methods | Where-Object { $_.AdditionalProperties.createdDateTime -and [datetime]$_.AdditionalProperties.createdDateTime -gt (Get-Date).AddDays(-$SignInDays) })
    }

    Write-Log -Message "[$($identity.EntraUPN)] Evidence saved to $Folder ($($rules.Count) rules, $($signIns.Count) sign-ins, $($methods.Count) MFA methods, $($grants.Count) app consents)" `
              -Level "INFO" -LogFile $LogFile
}
