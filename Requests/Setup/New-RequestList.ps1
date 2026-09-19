#Requires -Version 7.0
<#
    One-time setup: creates the "IT Requests" list HR fills in.

    .\Requests\Setup\New-RequestList.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/HR" -Departments Finance,IT,Sales,HR,Marketing
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [string]$ListName = "IT Requests",

    [Parameter(Mandatory)]
    [string[]]$Departments,

    [string[]]$Roles = @("Admin", "Systems Administrator", "Developer", "Technician", "Accountant", "Finance PowerUser",
                         "HR Specialist", "HR PowerUser", "Sales Rep", "Marketing Specialist", "User")
)

Connect-PnPOnline -Url $SiteUrl -Interactive

if (Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue) {
    Write-Host "List '$ListName' already exists, nothing to do." -ForegroundColor Yellow
    return
}

$null = New-PnPList -Title $ListName -Template GenericList -OnQuickLaunch

# Display name is what HR sees; internal name is what the scripts read
$fields = @(
    @{ DisplayName = "Request type";          InternalName = "RequestType";     Type = "Choice"; Choices = @("New hire", "Role change", "Leaver", "Update info"); Required = $true }
    @{ DisplayName = "First name";            InternalName = "FirstName";       Type = "Text" }
    @{ DisplayName = "Last name";             InternalName = "LastName";        Type = "Text" }
    @{ DisplayName = "Username";              InternalName = "Username";        Type = "Text" }
    @{ DisplayName = "Employee ID";           InternalName = "EmployeeID";      Type = "Text" }
    @{ DisplayName = "Job title";             InternalName = "JobTitle";        Type = "Text" }
    @{ DisplayName = "Department";            InternalName = "Department";      Type = "Choice"; Choices = $Departments }
    @{ DisplayName = "Role";                  InternalName = "Role";            Type = "Choice"; Choices = $Roles }
    @{ DisplayName = "Manager name";          InternalName = "ManagerName";     Type = "Text" }
    @{ DisplayName = "Manager username";      InternalName = "ManagerUsername"; Type = "Text" }
    @{ DisplayName = "Manager email";         InternalName = "ManagerEmail";    Type = "Text" }
    @{ DisplayName = "Employment type";       InternalName = "EmploymentType";  Type = "Choice"; Choices = @("Regular Full-Time", "Part-Time", "Contractor", "Intern") }
    @{ DisplayName = "Start date";            InternalName = "StartDate";       Type = "DateTime" }
    @{ DisplayName = "Office";                InternalName = "Office";          Type = "Text" }
    @{ DisplayName = "Office phone";          InternalName = "OfficePhone";     Type = "Text" }
    @{ DisplayName = "Mobile phone";          InternalName = "MobilePhone";     Type = "Text" }
    @{ DisplayName = "Status";                InternalName = "Status";          Type = "Choice"; Choices = @("New", "Approved", "Processing", "Done", "Needs attention", "Rejected") }
    @{ DisplayName = "Result";                InternalName = "Result";          Type = "Note" }
)

foreach ($field in $fields) {
    $params = @{ List = $ListName; DisplayName = $field.DisplayName; InternalName = $field.InternalName; Type = $field.Type; AddToDefaultView = $true }
    if ($field.Choices)  { $params.Choices = $field.Choices }
    if ($field.Required) { $params.Required = $true }
    $null = Add-PnPField @params
}

# "When" needs date AND time (a leaver's last day at 5 PM), so it's added from XML
$null = Add-PnPFieldFromXml -List $ListName -FieldXml '<Field Type="DateTime" Format="DateTime" DisplayName="When (leave blank for ASAP)" Name="EffectiveDate" StaticName="EffectiveDate" />'

# New requests start as "New" until someone approves them
Set-PnPField -List $ListName -Identity "Status" -Values @{ DefaultValue = "New" }

Write-Host "Created '$ListName' at $SiteUrl" -ForegroundColor Green
Write-Host "Next: give HR 'Contribute' access, and IT approvers 'Edit' so they can set Status to Approved."
