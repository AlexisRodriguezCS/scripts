function Save-UserSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [ValidateSet("Before", "After")]
        [string]$Stage,

        # Folder for this run, e.g. Reports\Snapshots\Offboarding_20260919_101500
        [Parameter(Mandatory)]
        [string]$Folder,

        [string]$LogFile
    )

    $identity = $PipelineObject.Identity
    $sam      = $identity.SamAccountName

    # Everything is read-only and best effort: a snapshot must never block the change itself
    $snapshot = [ordered]@{
        Stage         = $Stage
        TakenAt       = (Get-Date).ToString("o")
        CorrelationId = $PipelineObject.CorrelationId
        SamAccountName = $sam
    }

    try {
        $adUser = Get-ADUser -Filter "SamAccountName -eq '$sam'" `
                             -Properties Enabled, DisplayName, Title, Department, Manager, Description, MemberOf, DistinguishedName `
                             -ErrorAction Stop
        if ($adUser) {
            $snapshot.AD = [ordered]@{
                Enabled           = $adUser.Enabled
                DistinguishedName = $adUser.DistinguishedName
                DisplayName       = $adUser.DisplayName
                Title             = $adUser.Title
                Department        = $adUser.Department
                Manager           = $adUser.Manager
                Description       = $adUser.Description
                MemberOf          = @($adUser.MemberOf)
            }
        }
    }
    catch { $snapshot.ADError = $_.Exception.Message }

    if ($identity.EntraUPN) {
        try {
            $mgUser = Get-MgUser -UserId $identity.EntraUPN -Property "accountEnabled,assignedLicenses" -ErrorAction Stop
            $snapshot.Entra = [ordered]@{
                AccountEnabled = $mgUser.AccountEnabled
                LicenseSkuIds  = @($mgUser.AssignedLicenses.SkuId)
            }
        }
        catch { $snapshot.EntraError = $_.Exception.Message }

        try {
            $mailbox = Get-Mailbox -Identity $identity.EntraUPN -ErrorAction Stop
            $snapshot.Mailbox = [ordered]@{ Type = "$($mailbox.RecipientTypeDetails)" }
        }
        catch { $snapshot.MailboxError = $_.Exception.Message }
    }

    $null = New-Item -ItemType Directory -Path $Folder -Force
    $file = Join-Path $Folder "$($sam)_$($Stage.ToLower()).json"
    $snapshot | ConvertTo-Json -Depth 5 | Out-File -FilePath $file -Encoding utf8

    if ($LogFile) {
        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] Snapshot ($Stage) -> $file" -Level "DEBUG" -LogFile $LogFile
    }

    return $file
}
