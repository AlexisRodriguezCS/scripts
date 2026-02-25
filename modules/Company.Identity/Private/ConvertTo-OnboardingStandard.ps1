function ConvertTo-OnboardingStandard
 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject
    )

    $rawData = $PipelineObject.Raw

    # Trim whitespace
    $rawData.FirstName = $rawData.FirstName.Trim()
    $rawData.LastName = $rawData.LastName.Trim()
    $rawData.Title = $rawData.Title.Trim()
    $rawData.Manager = $rawData.Manager.Trim()
    $rawData.Location = $rawData.Location.Trim()
    $rawData.Department = $rawData.Department.Trim()

    # Get the system’s language capitalization rules
    $textInfo = (Get-Culture).TextInfo

    # Lowercase and then title case the relevant fields
    if ($rawData.FirstName)  { $rawData.FirstName  = $textInfo.ToTitleCase($rawData.FirstName.ToLower()) }
    if ($rawData.LastName)   { $rawData.LastName   = $textInfo.ToTitleCase($rawData.LastName.ToLower()) }
    if ($rawData.Title)      { $rawData.Title      = $textInfo.ToTitleCase($rawData.Title.ToLower()) }
    if ($rawData.Department) { $rawData.Department = $textInfo.ToTitleCase($rawData.Department.ToLower()) }

    return $PipelineObject
}