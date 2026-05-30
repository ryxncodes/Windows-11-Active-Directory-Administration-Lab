<#
.SYNOPSIS
Reports stale Active Directory users in the rk-lab.local lab.

.DESCRIPTION
Finds enabled AD users whose LastLogonDate is older than the selected threshold.
Never-logged-on accounts can be included when requested. This script is read-only
and is intended to help identify accounts that may need review, disablement, or
cleanup.

.PARAMETER DaysInactive
Number of inactive days before a user is considered stale.

.PARAMETER SearchBase
Optional distinguished name to limit the search scope.

.PARAMETER ExportCsvPath
Optional path to export the report as CSV.

.PARAMETER IncludeNeverLoggedOn
Also include enabled users that have no LastLogonDate.

.EXAMPLE
.\Get-StaleADUsers.ps1

.EXAMPLE
.\Get-StaleADUsers.ps1 -DaysInactive 180 -ExportCsvPath .\stale-users.csv

.EXAMPLE
.\Get-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateRange(1, 3650)]
    [int]$DaysInactive = 180,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SearchBase = "OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExportCsvPath,

    [Parameter()]
    [switch]$IncludeNeverLoggedOn
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory -ErrorAction Stop

$CutoffDate = (Get-Date).AddDays(-$DaysInactive)

Write-Verbose "Searching enabled users under $SearchBase."
Write-Verbose "Stale cutoff date: $CutoffDate"

$Users = Get-ADUser `
    -SearchBase $SearchBase `
    -Filter 'Enabled -eq $true' `
    -Properties Department, LastLogonDate, PasswordLastSet, whenCreated |
    Where-Object {
        ($_.LastLogonDate -and $_.LastLogonDate -lt $CutoffDate) -or
        ($IncludeNeverLoggedOn -and -not $_.LastLogonDate)
    } |
    Sort-Object LastLogonDate, SamAccountName |
    Select-Object `
        Name,
        SamAccountName,
        Enabled,
        Department,
        LastLogonDate,
        PasswordLastSet,
        whenCreated,
        DistinguishedName

if ($ExportCsvPath) {
    $ExportDirectory = Split-Path -Path $ExportCsvPath -Parent

    if ($ExportDirectory -and -not (Test-Path -Path $ExportDirectory -PathType Container)) {
        New-Item -Path $ExportDirectory -ItemType Directory -Force | Out-Null
    }

    $Users | Export-Csv -Path $ExportCsvPath -NoTypeInformation
    Write-Verbose "Exported stale user report to $ExportCsvPath."
}

$Users
