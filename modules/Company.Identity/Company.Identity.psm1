
# Gets all Public modules
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)

# Gets all Private modules
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)

# Combine both arrays safely
$AllFiles = $Public + $Private

# Load each script into the module
foreach ($file in $AllFiles) {
    . $file.FullName
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName