# Company.Identity

## Structure

Company.Identity/
├── Public/     # User-facing commands
├── Private/    # Internal helper functions
├── docs/       # Detailed feature documentation
├── Company.Identity.psd1
└── Company.Identity.psm1

## Example Usage

Import-Module .\Company.Identity

Invoke-Onboarding -Path .\data\users.csv -Verbose