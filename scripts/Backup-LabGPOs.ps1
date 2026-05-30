<#
.SYNOPSIS
Backs up expected Group Policy Objects from the rk-lab.local lab.

.DESCRIPTION
Creates timestamped backups of the expected lab GPOs. This is useful before
making GPO changes and as portfolio evidence that policies can be exported and
reviewed.

This script writes backup files only. It does not modify GPO settings.

.PARAMETER BackupRoot
Folder where GPO backups will be created.

.PARAMETER GpoName
Optional list of GPO names to back up. Defaults to the expected lab GPOs.

.EXAMPLE
.\Backup-LabGPOs.ps1

.EXAMPLE
.\Backup-LabGPOs.ps1 -BackupRoot C:\GPO-Backups -Verbose
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$BackupRoot = ".\gpo-backups",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$GpoName = @(
        "GPO-Workstations-Login-Banner",
        "GPO-Workstations-Local-Admins",
        "GPO-Workstations-Windows-Update",
        "GPO-Users-Mapped-Drives",
        "GPO-Users-Standard-Restrictions",
        "Default Domain Policy"
    )
)

$ErrorActionPreference = "Stop"

Import-Module GroupPolicy -ErrorAction Stop

$ResolvedBackupRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupRoot)
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupPath = Join-Path -Path $ResolvedBackupRoot -ChildPath $Timestamp

New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null

foreach ($Name in $GpoName) {
    Write-Verbose "Backing up GPO: $Name"

    try {
        $Gpo = Get-GPO -Name $Name -ErrorAction Stop
        Backup-GPO -Guid $Gpo.Id -Path $BackupPath -Comment "Backup created by Backup-LabGPOs.ps1 on $Timestamp" | Out-Null

        [PSCustomObject]@{
            GpoName    = $Name
            BackupPath = $BackupPath
            Status     = "Backed up"
        }
    }
    catch {
        [PSCustomObject]@{
            GpoName    = $Name
            BackupPath = $BackupPath
            Status     = "Error: $($_.Exception.Message)"
        }
    }
}
