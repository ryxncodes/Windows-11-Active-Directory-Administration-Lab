<#
Exports or prints members of the main RK lab groups.

Examples:
  .\Get-LabGroupMembershipReport.ps1
  .\Get-LabGroupMembershipReport.ps1 -ExportCsvPath .\outputs\group-membership-report.csv
#>

[CmdletBinding()]
param (
    [string[]]$GroupName = @(
        "GG_IT_Admins",
        "GG_HR_FileShare_RW",
        "GG_Finance_FileShare_RW",
        "GG_Operations_FileShare_RW",
        "GG_All_Employees",
        "GG_Standard_Users"
    ),

    [string]$ExportCsvPath
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory

$Report = foreach ($Group in $GroupName) {
    Write-Host "Checking $Group"

    try {
        $Members = Get-ADGroupMember -Identity $Group -Recursive

        if (-not $Members) {
            [PSCustomObject]@{
                GroupName         = $Group
                MemberName        = ""
                SamAccountName    = ""
                ObjectClass       = ""
                DistinguishedName = ""
                Status            = "No members"
            }
            continue
        }

        foreach ($Member in $Members) {
            [PSCustomObject]@{
                GroupName         = $Group
                MemberName        = $Member.Name
                SamAccountName    = $Member.SamAccountName
                ObjectClass       = $Member.ObjectClass
                DistinguishedName = $Member.DistinguishedName
                Status            = "Found"
            }
        }
    }
    catch {
        [PSCustomObject]@{
            GroupName         = $Group
            MemberName        = ""
            SamAccountName    = ""
            ObjectClass       = ""
            DistinguishedName = ""
            Status            = "Error: $($_.Exception.Message)"
        }
    }
}

if ($ExportCsvPath) {
    $Folder = Split-Path -Path $ExportCsvPath -Parent

    if ($Folder -and -not (Test-Path -Path $Folder -PathType Container)) {
        New-Item -Path $Folder -ItemType Directory -Force | Out-Null
    }

    $Report | Export-Csv -Path $ExportCsvPath -NoTypeInformation
    Write-Host ""
    Write-Host "Saved report to $ExportCsvPath"
}

$Report
