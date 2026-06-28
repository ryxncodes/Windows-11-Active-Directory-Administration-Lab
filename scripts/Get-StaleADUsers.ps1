<#
Finds enabled AD users that have not logged in recently.

Examples:
  .\Get-StaleADUsers.ps1
  .\Get-StaleADUsers.ps1 -DaysInactive 180 -ExportCsvPath .\outputs\stale-users.csv
  .\Get-StaleADUsers.ps1 -IncludeNeverLoggedOn
#>

[CmdletBinding()]
param (
    [int]$DaysInactive = 180,
    [string]$SearchBase = "OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
    [string]$ExportCsvPath,
    [switch]$IncludeNeverLoggedOn,
    [int]$NeverLoggedOnGraceDays = 14
)

$ErrorActionPreference = "Stop"

if ($DaysInactive -lt 1) {
    throw "DaysInactive needs to be at least 1."
}

if ($NeverLoggedOnGraceDays -lt 0) {
    throw "NeverLoggedOnGraceDays cannot be negative."
}

Import-Module ActiveDirectory

$StaleBefore = (Get-Date).AddDays(-$DaysInactive)
$NeverLoggedOnBefore = (Get-Date).AddDays(-$NeverLoggedOnGraceDays)

Write-Host "Checking enabled users under:"
Write-Host $SearchBase
Write-Host ""
Write-Host "Inactive before: $StaleBefore"

if ($IncludeNeverLoggedOn) {
    Write-Host "Also checking never-logged-on accounts created before: $NeverLoggedOnBefore"
}

$StaleUsers = Get-ADUser `
    -SearchBase $SearchBase `
    -Filter 'Enabled -eq $true' `
    -Properties Department, LastLogonDate, PasswordLastSet, whenCreated |
    Where-Object {
        $OldLogin = $_.LastLogonDate -and $_.LastLogonDate -lt $StaleBefore
        $OldNeverUsed = $IncludeNeverLoggedOn -and -not $_.LastLogonDate -and $_.whenCreated -lt $NeverLoggedOnBefore

        $OldLogin -or $OldNeverUsed
    } |
    Sort-Object LastLogonDate, SamAccountName |
    Select-Object `
        @{Name = "ReviewReason"; Expression = {
            if ($_.LastLogonDate) {
                "Inactive more than $DaysInactive days"
            }
            else {
                "Never logged on; older than $NeverLoggedOnGraceDays days"
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
    $Folder = Split-Path -Path $ExportCsvPath -Parent

    if ($Folder -and -not (Test-Path -Path $Folder -PathType Container)) {
        New-Item -Path $Folder -ItemType Directory -Force | Out-Null
    }

    $StaleUsers | Export-Csv -Path $ExportCsvPath -NoTypeInformation
    Write-Host ""
    Write-Host "Saved report to $ExportCsvPath"
}

$StaleUsers
