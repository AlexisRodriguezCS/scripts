function Test-RequestApproval {
    [CmdletBinding()]
    param(
        # The list item's version history (SharePoint keeps one version per edit, with who made it)
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Versions,

        # Email of the person who created the request
        [string]$SubmittedBy,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    # Anyone who can edit the list could type "Approved", so the Status column alone proves nothing.
    # Find who actually made the most recent change to Approved, from SharePoint's own history.
    $approver = $null
    $previous = $null

    foreach ($version in $Versions | Sort-Object { [datetime]$_.LastModifiedDateTime }) {
        $status = $version.Fields.AdditionalProperties.Status
        if ($status -eq "Approved" -and $previous -ne "Approved") {
            $approver = "$($version.LastModifiedBy.User.AdditionalProperties.email)"
        }
        $previous = $status
    }

    # Returns the problem in plain words, or $null if the approval is valid
    if (-not $approver) {
        return "No approval found in the request's history"
    }
    if ($approver -notin @($Config.Approvers)) {
        return "Approved by $approver, who isn't on the approvers list"
    }
    if ($SubmittedBy -and $approver -eq $SubmittedBy) {
        return "Approved by the same person who submitted it; someone else has to approve"
    }

    return $null
}
