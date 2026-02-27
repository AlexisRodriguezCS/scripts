function ConvertTo-OnboardingStandard
 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject
    )

    $rawData = $PipelineObject.Raw

    # Trim whitespace
    if ($rawData.FirstName)  { $rawData.FirstName  = $rawData.FirstName.Trim() }
    if ($rawData.LastName)   { $rawData.LastName   = $rawData.LastName.Trim() }
    if ($rawData.Title)      { $rawData.Title      = $rawData.Title.Trim() }
    if ($rawData.Manager)    { $rawData.Manager    = $rawData.Manager.Trim() }
    if ($rawData.Location)   { $rawData.Location   = $rawData.Location.Trim() }
    if ($rawData.Department) { $rawData.Department = $rawData.Department.Trim() }

    # Get the system’s language capitalization rules
    $textInfo = (Get-Culture).TextInfo

    # Lowercase and then title case the relevant fields
    if ($rawData.FirstName)  { $rawData.FirstName  = $textInfo.ToTitleCase($rawData.FirstName.ToLower()) }
    if ($rawData.LastName)   { $rawData.LastName   = $textInfo.ToTitleCase($rawData.LastName.ToLower()) }
    if ($rawData.Title)      { $rawData.Title      = $textInfo.ToTitleCase($rawData.Title.ToLower()) }
    
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

    return $PipelineObject
}