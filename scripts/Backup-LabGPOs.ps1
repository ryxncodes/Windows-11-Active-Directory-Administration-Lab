<#
Backs up the lab GPOs into a timestamped folder.

Examples:
  .\Backup-LabGPOs.ps1
  .\Backup-LabGPOs.ps1 -BackupRoot C:\GPO-Backups
#>

[CmdletBinding()]
param (
    [string]$BackupRoot = ".\gpo-backups",

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

Import-Module GroupPolicy

$BackupRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupRoot)
$DateStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupPath = Join-Path -Path $BackupRoot -ChildPath $DateStamp

New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null

Write-Host "Backing up GPOs to:"
Write-Host $BackupPath
Write-Host ""

foreach ($Name in $GpoName) {
    try {
        Write-Host "Backing up $Name"

        $Gpo = Get-GPO -Name $Name
        Backup-GPO -Guid $Gpo.Id -Path $BackupPath -Comment "Lab backup from Backup-LabGPOs.ps1 - $DateStamp" | Out-Null

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
