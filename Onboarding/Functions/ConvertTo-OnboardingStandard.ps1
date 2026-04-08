function ConvertTo-OnboardingStandard
 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "ConvertTo-OnboardingStandard"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)
        $rawData = $PipelineObject.Raw

        # Trim whitespace
        foreach ($prop in "FirstName","LastName","Title","Manager","Location","Department") {
            if (-not [string]::IsNullOrWhiteSpace($rawData.$prop)) {
                $rawData.$prop = $rawData.$prop.Trim()
            }
        }

        # Get the system’s language capitalization rules
        $textInfo = (Get-Culture).TextInfo

        # Lowercase and then title case the relevant fields
        foreach ($prop in "FirstName","LastName","Title") {
            if ($rawData.$prop) { $rawData.$prop = $textInfo.ToTitleCase($rawData.$prop.ToLower()) }
        }
        
        # Normalize Department with exceptions
        if ($rawData.Department) {
            $deptNormalized = $textInfo.ToTitleCase($rawData.Department.ToLower())
            $exceptions = @{
                "Hr" = "HR"
                "It" = "IT"
                "Qa" = "QA"
            }
            # Check if the normalized department is in the exceptions list
            if ($exceptions.ContainsKey($deptNormalized)) {
                $rawData.Department = $exceptions[$deptNormalized]
            } else {
                $rawData.Department = $deptNormalized
            }
        }

        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Normalize -> $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName): FirstName=$($PipelineObject.Raw.FirstName), LastName=$($PipelineObject.Raw.LastName), Title=$($PipelineObject.Raw.Title), Manager=$($PipelineObject.Raw.Manager), Location=$($PipelineObject.Raw.Location), Department=$($PipelineObject.Raw.Department)" `
          -Level "INFO" -LogFile $LogFile
    }
}