<#
Disables stale enabled AD users in the lab.

Run with -WhatIf first. I kept never-logged-on users out by default because
new staged accounts can look stale if they have not been used yet.

Examples:
  .\Disable-StaleADUsers.ps1 -DaysInactive 180 -WhatIf
  .\Disable-StaleADUsers.ps1 -DaysInactive 180 -MoveToDisabledOU -WhatIf
  .\Disable-StaleADUsers.ps1 -IncludeNeverLoggedOn -WhatIf
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param (
    [int]$DaysInactive = 180,
    [string]$SearchBase = "OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
    [string]$DisabledUsersOU = "OU=Disabled Users,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
    [switch]$MoveToDisabledOU,
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

Write-Host "Looking for stale enabled users under:"
Write-Host $SearchBase
Write-Host ""
Write-Host "Inactive before: $StaleBefore"

if ($IncludeNeverLoggedOn) {
    Write-Host "Including never-logged-on users created before: $NeverLoggedOnBefore"
}
else {
    Write-Host "Never-logged-on users are being skipped."
}

if ($MoveToDisabledOU) {
    Get-ADOrganizationalUnit -Identity $DisabledUsersOU | Out-Null
    Write-Host "Disabled users will be moved to:"
    Write-Host $DisabledUsersOU
}

$Users = Get-ADUser `
    -SearchBase $SearchBase `
    -Filter 'Enabled -eq $true' `
    -Properties Department, LastLogonDate, whenCreated |
    Where-Object {
        $OldLogin = $_.LastLogonDate -and $_.LastLogonDate -lt $StaleBefore
        $OldNeverUsed = $IncludeNeverLoggedOn -and -not $_.LastLogonDate -and $_.whenCreated -lt $NeverLoggedOnBefore

        $OldLogin -or $OldNeverUsed
    } |
    Sort-Object LastLogonDate, SamAccountName

if (-not $Users) {
    Write-Host ""
    Write-Host "No matching stale users found."
    return
}

foreach ($User in $Users) {
    if ($User.LastLogonDate) {
        $Reason = "Inactive more than $DaysInactive days"
    }
    else {
        $Reason = "Never logged on; older than $NeverLoggedOnGraceDays days"
    }

    $Action = "Disable account"

    if ($MoveToDisabledOU) {
        $Action = "$Action and move to Disabled Users OU"
    }

    Write-Host ""
    Write-Host "User: $($User.SamAccountName)"
    Write-Host "Reason: $Reason"

    if ($PSCmdlet.ShouldProcess($User.SamAccountName, $Action)) {
        Disable-ADAccount -Identity $User.DistinguishedName

        if ($MoveToDisabledOU) {
            Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledUsersOU
        }

        $Status = "Disabled"
    }
    else {
        $Status = "WhatIf - no changes"
    }

    [PSCustomObject]@{
        ReviewReason      = $Reason
        Name              = $User.Name
        SamAccountName    = $User.SamAccountName
        Department        = $User.Department
        LastLogonDate     = $User.LastLogonDate
        DistinguishedName = $User.DistinguishedName
        Status            = $Status
    }
}
