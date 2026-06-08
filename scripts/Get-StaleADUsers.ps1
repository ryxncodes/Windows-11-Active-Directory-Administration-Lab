<#
.SYNOPSIS
Reports stale Active Directory users in the rk-lab.local lab.

.DESCRIPTION
Finds enabled AD users whose LastLogonDate is older than the selected threshold.
Never-logged-on accounts can be included when requested, but newly created
accounts are protected by a configurable grace period. This script is read-only
and is intended to help identify accounts that may need review, disablement, or
cleanup.

.PARAMETER DaysInactive
Number of inactive days before a user is considered stale.

.PARAMETER SearchBase
Optional distinguished name to limit the search scope.

.PARAMETER ExportCsvPath
Optional path to export the report as CSV.

.PARAMETER IncludeNeverLoggedOn
Also include enabled users that have no LastLogonDate and were created before
the never-logged-on grace period.

.PARAMETER NeverLoggedOnGraceDays
Number of days to ignore never-logged-on accounts after creation. This prevents
newly staged accounts from being flagged immediately.

.EXAMPLE
.\Get-StaleADUsers.ps1

.EXAMPLE
.\Get-StaleADUsers.ps1 -DaysInactive 180 -ExportCsvPath .\stale-users.csv

.EXAMPLE
.\Get-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn

.EXAMPLE
.\Get-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn -NeverLoggedOnGraceDays 30
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
    [switch]$IncludeNeverLoggedOn,

    [Parameter()]
    [ValidateRange(0, 3650)]
    [int]$NeverLoggedOnGraceDays = 14
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory -ErrorAction Stop

$CutoffDate = (Get-Date).AddDays(-$DaysInactive)
$NeverLoggedOnCutoffDate = (Get-Date).AddDays(-$NeverLoggedOnGraceDays)

Write-Verbose "Searching enabled users under $SearchBase."
Write-Verbose "Stale cutoff date: $CutoffDate"
Write-Verbose "Never-logged-on grace cutoff date: $NeverLoggedOnCutoffDate"

$Users = Get-ADUser `
    -SearchBase $SearchBase `
    -Filter 'Enabled -eq $true' `
    -Properties Department, LastLogonDate, PasswordLastSet, whenCreated |
    Where-Object {
        ($_.LastLogonDate -and $_.LastLogonDate -lt $CutoffDate) -or
        ($IncludeNeverLoggedOn -and -not $_.LastLogonDate -and $_.whenCreated -lt $NeverLoggedOnCutoffDate)
    } |
    Sort-Object LastLogonDate, SamAccountName |
    Select-Object `
        @{Name = "ReviewReason"; Expression = {
            if ($_.LastLogonDate -and $_.LastLogonDate -lt $CutoffDate) {
                "Inactive for more than $DaysInactive days"
            }
            elseif (-not $_.LastLogonDate) {
                "Never logged on; created more than $NeverLoggedOnGraceDays days ago"
            }
        }},
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
