function Set-RequestStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$ItemId,

        [Parameter(Mandatory)]
        [ValidateSet("Approved", "Processing", "Done", "Needs attention")]
        [string]$Status,

        [string]$Result
    )

    # What HR sees in the list
    Update-MgSiteListItemField -SiteId $Config.SiteId -ListId $Config.ListName -ListItemId $ItemId `
                               -BodyParameter @{ Status = $Status; Result = $Result } -ErrorAction Stop | Out-Null
}
