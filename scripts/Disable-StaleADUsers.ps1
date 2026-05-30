<#
.SYNOPSIS
Disables stale Active Directory users and optionally moves them to Disabled Users.

.DESCRIPTION
Finds enabled AD users whose LastLogonDate is older than the selected threshold,
disables them, and can move them to the lab Disabled Users OU.

This script supports -WhatIf and should be reviewed with -WhatIf before making
changes. Never-logged-on accounts are skipped unless -IncludeNeverLoggedOn is
used.

.PARAMETER DaysInactive
Number of inactive days before a user is considered stale.

.PARAMETER SearchBase
Optional distinguished name to limit the search scope.

.PARAMETER DisabledUsersOU
Target OU for disabled users when -MoveToDisabledOU is used.

.PARAMETER MoveToDisabledOU
Move disabled accounts to the Disabled Users OU after disabling them.

.PARAMETER IncludeNeverLoggedOn
Also include enabled users that have no LastLogonDate. This is disabled by
default so newly staged accounts are not disabled by accident.

.EXAMPLE
.\Disable-StaleADUsers.ps1 -DaysInactive 180 -WhatIf

.EXAMPLE
.\Disable-StaleADUsers.ps1 -DaysInactive 180 -MoveToDisabledOU -Verbose

.EXAMPLE
.\Disable-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn -WhatIf
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param (
    [Parameter()]
    [ValidateRange(1, 3650)]
    [int]$DaysInactive = 180,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SearchBase = "OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DisabledUsersOU = "OU=Disabled Users,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",

    [Parameter()]
    [switch]$MoveToDisabledOU,

    [Parameter()]
    [switch]$IncludeNeverLoggedOn
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory -ErrorAction Stop

$CutoffDate = (Get-Date).AddDays(-$DaysInactive)

Write-Verbose "Searching enabled users under $SearchBase."
Write-Verbose "Stale cutoff date: $CutoffDate"

if ($MoveToDisabledOU) {
    $null = Get-ADOrganizationalUnit -Identity $DisabledUsersOU -ErrorAction Stop
}

$Users = Get-ADUser `
    -SearchBase $SearchBase `
    -Filter 'Enabled -eq $true' `
    -Properties Department, LastLogonDate |
    Where-Object {
        ($_.LastLogonDate -and $_.LastLogonDate -lt $CutoffDate) -or
        ($IncludeNeverLoggedOn -and -not $_.LastLogonDate)
    } |
    Sort-Object LastLogonDate, SamAccountName

if (-not $Users) {
    Write-Verbose "No stale enabled users matched the current criteria."
}

foreach ($User in $Users) {
    $Action = "Disable stale user"

    if ($MoveToDisabledOU) {
        $Action = "$Action and move to Disabled Users OU"
    }

    if ($PSCmdlet.ShouldProcess($User.SamAccountName, $Action)) {
        Disable-ADAccount -Identity $User.DistinguishedName

        if ($MoveToDisabledOU) {
            Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledUsersOU
        }

        $Status = "Disabled"
    }
    else {
        $Status = "WhatIf: no changes made"
    }

    [PSCustomObject]@{
        Name              = $User.Name
        SamAccountName    = $User.SamAccountName
        Department        = $User.Department
        LastLogonDate     = $User.LastLogonDate
        DistinguishedName = $User.DistinguishedName
        Status            = $Status
    }
}
