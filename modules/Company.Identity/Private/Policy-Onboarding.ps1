function Policy-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject
    )

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-LogAndVerbose -Message "[SKIP] Skipping onboarding for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN"
        return $PipelineObject
    }

    # Get raw data
    $raw = $PipelineObject.Raw

    # Initialize distribution list
    $distributionList = @()

    # Add to distribution list based on department
    if($raw.Department) {
        $distributionList += $($raw.Department)
    }

    # Add to distribution list based on title keywords
    if($raw.Title -match "(?i)Manager|Director|Lead") {
        $distributionList += "Managers"
    }

    # Add to all Regular Full-Time employees to the staff distribution list
    if ($raw.EmploymentType -eq "Regular Full-Time") {
        $distributionList += "Staff"
    }

    # Combine all assigned distribution lists into a single semicolon-separated string
    $PipelineObject.Raw.DistributionList = ($distributionList -join ";")

    #  Initialize groups list
    $groups = @()

    # Assign AD groups based on role
    switch ($raw.Role.ToLower()) {
    "admin"                  { $groups += "GRP_ROLE_IT_Admin" }
    "systems administrator"  { $groups += "GRP_ROLE_IT_User" }
    "developer"              { $groups += "GRP_ROLE_IT_User" }
    "technician"             { $groups += "GRP_ROLE_IT_Helpdesk" }
    "accountant"             { $groups += "GRP_ROLE_Finance_User" }
    "finance poweruser"      { $groups += "GRP_ROLE_Finance_PowerUser" }
    "hr specialist"          { $groups += "GRP_ROLE_HR_User" }
    "hr poweruser"           { $groups += "GRP_ROLE_HR_PowerUser" }
    "sales rep"              { $groups += "GRP_ROLE_Sales_User" }
    "marketing specialist"   { $groups += "GRP_ROLE_Marketing_User" } 
    default                  { $groups += "GRP_ROLE_User" }           # fallback
}

    # Combine all assigned groups into a single semicolon-separated string
    $PipelineObject.Raw.ADGroups = ($groups -join ";")

    # Assign default license
    $PipelineObject.Raw.License = "Standard-Office365"

    return $PipelineObject
}