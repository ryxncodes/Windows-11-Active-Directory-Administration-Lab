<#
.SYNOPSIS
Reports membership for expected rk-lab.local security groups.

.DESCRIPTION
Builds a readable group membership report for the lab's expected security
groups. This is useful for validating department access and GPO security
filtering.

.PARAMETER GroupName
Optional list of group names to report. Defaults to the expected lab groups.

.PARAMETER ExportCsvPath
Optional path to export the report as CSV.

.EXAMPLE
.\Get-LabGroupMembershipReport.ps1

.EXAMPLE
.\Get-LabGroupMembershipReport.ps1 -ExportCsvPath .\group-members.csv
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$GroupName = @(
        "GG_IT_Admins",
        "GG_HR_FileShare_RW",
        "GG_Finance_FileShare_RW",
        "GG_Operations_FileShare_RW",
        "GG_All_Employees",
        "GG_Standard_Users"
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExportCsvPath
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory -ErrorAction Stop

$Report = foreach ($Group in $GroupName) {
    Write-Verbose "Reading members for $Group."

    try {
        $Members = Get-ADGroupMember -Identity $Group -Recursive -ErrorAction Stop

        if (-not $Members) {
            [PSCustomObject]@{
                GroupName         = $Group
                MemberName        = ""
                SamAccountName    = ""
                ObjectClass       = ""
                DistinguishedName = ""
                Status            = "No members"
            }
        }
        else {
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
    $ExportDirectory = Split-Path -Path $ExportCsvPath -Parent

    if ($ExportDirectory -and -not (Test-Path -Path $ExportDirectory -PathType Container)) {
        New-Item -Path $ExportDirectory -ItemType Directory -Force | Out-Null
    }

    $Report | Export-Csv -Path $ExportCsvPath -NoTypeInformation
    Write-Verbose "Exported group membership report to $ExportCsvPath."
}

$Report
