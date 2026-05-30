<#
.SYNOPSIS
Removes stale local Windows user profiles to reclaim disk space.

.DESCRIPTION
Finds local user profiles that have not been used within the selected threshold
and removes them through the Win32_UserProfile class. This is an endpoint
maintenance script, not a pure AD script, but it is useful in AD environments
where shared PCs collect old domain user profiles.

The script excludes special profiles and loaded profiles, supports -WhatIf, and
does not require third-party modules. By default, it only targets profiles whose
resolved account name begins with the configured domain prefix.

.PARAMETER DaysInactive
Number of inactive days before a local profile is considered stale.

.PARAMETER IncludeLocalProfiles
Include local non-domain profiles in the cleanup candidate list.

.PARAMETER DomainNetbiosName
Expected domain NetBIOS name for domain profiles. Defaults to RK-LAB.

.PARAMETER ExcludeAccountName
Account names to skip even if they otherwise match the cleanup criteria.

.PARAMETER MinimumFreeSpaceGB
Only remove profiles when the system drive has less than this amount of free
space. Set to 0 to disable the free-space gate.

.EXAMPLE
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -WhatIf

.EXAMPLE
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -Verbose

.EXAMPLE
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -DomainNetbiosName RK-LAB -WhatIf
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param (
    [Parameter()]
    [ValidateRange(1, 3650)]
    [int]$DaysInactive = 180,

    [Parameter()]
    [switch]$IncludeLocalProfiles,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DomainNetbiosName = "RK-LAB",

    [Parameter()]
    [string[]]$ExcludeAccountName = @(
        "Administrator",
        "DefaultAccount",
        "Guest",
        "WDAGUtilityAccount"
    ),

    [Parameter()]
    [ValidateRange(0, 10240)]
    [int]$MinimumFreeSpaceGB = 20
)

$ErrorActionPreference = "Stop"

function Convert-SidToAccountName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Sid
    )

    try {
        $SecurityIdentifier = [System.Security.Principal.SecurityIdentifier]::new($Sid)
        return $SecurityIdentifier.Translate([System.Security.Principal.NTAccount]).Value
    }
    catch {
        return $Sid
    }
}

$CutoffDate = (Get-Date).AddDays(-$DaysInactive)

Write-Verbose "Searching for local profiles unused since before $CutoffDate."

if ($MinimumFreeSpaceGB -gt 0) {
    $SystemDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"

    if ($SystemDrive) {
        $FreeSpaceGB = [Math]::Round($SystemDrive.FreeSpace / 1GB, 2)
        Write-Verbose "System drive free space: $FreeSpaceGB GB."

        if ($FreeSpaceGB -ge $MinimumFreeSpaceGB) {
            Write-Verbose "Skipping cleanup because free space is at or above $MinimumFreeSpaceGB GB."
            return
        }
    }
    else {
        Write-Warning "Could not read C: drive free space. Continuing with profile age checks."
    }
}

$Profiles = Get-CimInstance -ClassName Win32_UserProfile |
    Where-Object {
        -not $_.Special -and
        -not $_.Loaded -and
        $_.LocalPath -like "C:\Users\*" -and
        $_.LastUseTime -and
        $_.LastUseTime -lt $CutoffDate
    }

foreach ($Profile in $Profiles) {
    $AccountName = Convert-SidToAccountName -Sid $Profile.SID
    $ProfileUserName = Split-Path -Path $Profile.LocalPath -Leaf
    $IsExpectedDomainProfile = $AccountName -like "$DomainNetbiosName\*"

    if ($ExcludeAccountName -contains $ProfileUserName -or $ExcludeAccountName -contains $AccountName) {
        Write-Verbose "Skipping excluded profile: $($Profile.LocalPath)"
        continue
    }

    if (-not $IncludeLocalProfiles -and -not $IsExpectedDomainProfile) {
        Write-Verbose "Skipping profile outside $DomainNetbiosName domain scope: $($Profile.LocalPath) ($AccountName)"
        continue
    }

    $Message = "Remove profile $($Profile.LocalPath) for $AccountName last used $($Profile.LastUseTime)"

    if ($PSCmdlet.ShouldProcess($Profile.LocalPath, $Message)) {
        Remove-CimInstance -InputObject $Profile
        $Status = "Removed"
    }
    else {
        $Status = "WhatIf: no changes made"
    }

    [PSCustomObject]@{
        AccountName = $AccountName
        LocalPath   = $Profile.LocalPath
        LastUseTime = $Profile.LastUseTime
        Loaded      = $Profile.Loaded
        Status      = $Status
    }
}
