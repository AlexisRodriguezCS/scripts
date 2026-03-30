function Set-OnboardingPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "Set-OnboardingPolicy"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

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

        # Add to all Regular Full-Time employees to the all staff distribution list 
        if ($raw.EmploymentType -eq "Regular Full-Time") {
            $distributionList += $Config.DefaultDistributionList
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

        # Assign default groups from config
        if ($Config.DefaultGroups) { $groups += $Config.DefaultGroups }

        # Combine all assigned groups into a single semicolon-separated string
        $PipelineObject.Raw.ADGroups = ($groups -join ";")

        # Assign license based on config file
        if ($Config.DefaultLicense) { $PipelineObject.Raw.License = $Config.DefaultLicense }

        # Log what was set
        Write-Log -Message "[SET]  $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName)" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "`tDistribution Lists : $($PipelineObject.Raw.DistributionList)" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "`tAD Groups          : $($PipelineObject.Raw.ADGroups)" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "`tLicense            : $($PipelineObject.Raw.License)" -Level "INFO" -LogFile $LogFile
    }
}