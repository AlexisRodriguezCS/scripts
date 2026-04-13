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

        # Get the system’s language capitalization rules
        $textInfo = (Get-Culture).TextInfo

        foreach ($prop in "FirstName","LastName","Title","Manager","Location") {
            # Trim whitespace and then title case
            if (-not [string]::IsNullOrWhiteSpace($rawData.$prop)) {
                $value = $rawData.$prop.Trim()
                $value = $textInfo.ToTitleCase($value.ToLower())
                $rawData.$prop = $value
            }
            elseif ($null -eq $rawData.$prop) {
                $rawData.$prop = $null
            }
        }
        
        # Normalize Department with exceptions
        if (-not [string]::IsNullOrWhiteSpace($rawData.Department)) {

            $dept = $rawData.Department.Trim()
            $dept = $textInfo.ToTitleCase($dept.ToLower())

            $exceptions = @{
                "Hr" = "HR"
                "It" = "IT"
                "Qa" = "QA"
            }
            # Check if the normalized department is in the exceptions list
            if ($exceptions.ContainsKey($dept)) {
                $rawData.Department = $exceptions[$dept]
            } else {
                $rawData.Department = $dept
            }
        }

        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Normalize -> $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName): FirstName=$($PipelineObject.Raw.FirstName), LastName=$($PipelineObject.Raw.LastName), Title=$($PipelineObject.Raw.Title), Manager=$($PipelineObject.Raw.Manager), Location=$($PipelineObject.Raw.Location), Department=$($PipelineObject.Raw.Department)" `
          -Level "INFO" -LogFile $LogFile
    }
}