<#
Removes old local user profiles from shared/domain-joined PCs.

Run with -WhatIf first. By default this only targets profiles that resolve to
the RK-LAB domain and it skips loaded/special profiles.

Examples:
  .\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -WhatIf
  .\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -MinimumFreeSpaceGB 0 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param (
    [int]$DaysInactive = 180,
    [switch]$IncludeLocalProfiles,
    [string]$DomainNetbiosName = "RK-LAB",
    [string[]]$ExcludeAccountName = @(
        "Administrator",
        "DefaultAccount",
        "Guest",
        "WDAGUtilityAccount"
    ),
    [int]$MinimumFreeSpaceGB = 20
)

$ErrorActionPreference = "Stop"

if ($DaysInactive -lt 1) {
    throw "DaysInactive needs to be at least 1."
}

if ($MinimumFreeSpaceGB -lt 0) {
    throw "MinimumFreeSpaceGB cannot be negative."
}

function Get-AccountFromSid {
    param ([string]$Sid)

    try {
        $SidObject = [System.Security.Principal.SecurityIdentifier]::new($Sid)
        return $SidObject.Translate([System.Security.Principal.NTAccount]).Value
    }
    catch {
        return $Sid
    }
}

$CutoffDate = (Get-Date).AddDays(-$DaysInactive)

Write-Host "Checking local profiles unused before:"
Write-Host $CutoffDate
Write-Host ""

if ($MinimumFreeSpaceGB -gt 0) {
    $SystemDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"

    if ($SystemDrive) {
        $FreeSpaceGB = [Math]::Round($SystemDrive.FreeSpace / 1GB, 2)
        Write-Host "C: free space: $FreeSpaceGB GB"

        if ($FreeSpaceGB -ge $MinimumFreeSpaceGB) {
            Write-Host "Skipping cleanup. Free space is already at or above $MinimumFreeSpaceGB GB."
            return
        }
    }
    else {
        Write-Warning "Could not read free space on C:. Continuing anyway."
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
    $AccountName = Get-AccountFromSid -Sid $Profile.SID
    $ProfileFolderName = Split-Path -Path $Profile.LocalPath -Leaf
    $IsDomainUser = $AccountName -like "$DomainNetbiosName\*"

    if ($ExcludeAccountName -contains $ProfileFolderName -or $ExcludeAccountName -contains $AccountName) {
        Write-Host "Skipping excluded profile: $($Profile.LocalPath)"
        continue
    }

    if (-not $IncludeLocalProfiles -and -not $IsDomainUser) {
        Write-Host "Skipping non-domain profile: $($Profile.LocalPath) ($AccountName)"
        continue
    }

    Write-Host ""
    Write-Host "Profile: $($Profile.LocalPath)"
    Write-Host "Account: $AccountName"
    Write-Host "Last used: $($Profile.LastUseTime)"

    if ($PSCmdlet.ShouldProcess($Profile.LocalPath, "Remove stale local profile")) {
        Remove-CimInstance -InputObject $Profile
        $Status = "Removed"
    }
    else {
        $Status = "WhatIf - no changes"
    }

    [PSCustomObject]@{
        AccountName = $AccountName
        LocalPath   = $Profile.LocalPath
        LastUseTime = $Profile.LastUseTime
        Loaded      = $Profile.Loaded
        Status      = $Status
    }
}
