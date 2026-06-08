# Script Safety Notes

These scripts are lab automation examples for `rk-lab.local`. They are intended
to show safe junior systems administration habits, not to be copied into
production without review.

## Validation Status

All PowerShell scripts in this repository have been syntax-checked with
PowerShell. Domain-dependent validation has also been performed inside the lab
environment:

- `Test-ADLabHealth.ps1 -Verbose` completed with `PASS=31 WARN=0 FAIL=0`.
- `New-LabUser.ps1` was tested with `-WhatIf` to confirm target OU and group
  membership behavior before changes.
- `Get-LabGroupMembershipReport.ps1` exported group membership evidence.
- `Get-StaleADUsers.ps1` exported inactive/never-logged-on user review data
  with review reasons.
- `Backup-LabGPOs.ps1` generated timestamped backups of expected lab GPOs.

Scripts that remove local Windows profiles still depend on endpoint profile
state and should be tested on the intended workstation with `-WhatIf` before
removing anything.

## Destructive Scripts

The following scripts can change or remove data:

| Script | Risk | Guardrails |
|---|---|---|
| [`Disable-StaleADUsers.ps1`](../scripts/Disable-StaleADUsers.ps1) | Disables AD accounts and can move objects | Supports `-WhatIf`; ignores never-logged-on users unless `-IncludeNeverLoggedOn` is used |
| [`Remove-StaleLocalProfiles.ps1`](../scripts/Remove-StaleLocalProfiles.ps1) | Removes local Windows user profiles | Supports `-WhatIf`; skips loaded/special profiles; defaults to `RK-LAB` domain profiles only |
| [`New-LabUser.ps1`](../scripts/New-LabUser.ps1) | Creates AD users and adds group membership | Supports `-WhatIf`; validates required fields, departments, OUs, and groups |

Recommended first run:

```powershell
.\New-LabUser.ps1 -FirstName Morgan -LastName Read -Department HR -TemporaryPassword "ChangeMe123!" -WhatIf -Verbose
.\Disable-StaleADUsers.ps1 -DaysInactive 180 -WhatIf
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -DomainNetbiosName RK-LAB -WhatIf
```

## Read-Only Scripts

The following scripts are intended to be non-destructive:

- [`Get-StaleADUsers.ps1`](../scripts/Get-StaleADUsers.ps1)
- [`Get-LabGroupMembershipReport.ps1`](../scripts/Get-LabGroupMembershipReport.ps1)
- [`Test-ADLabHealth.ps1`](../scripts/Test-ADLabHealth.ps1)

`Backup-LabGPOs.ps1` writes backup files but does not modify the GPOs.

Recommended evidence runs:

```powershell
.\Test-ADLabHealth.ps1 -Verbose
.\Get-LabGroupMembershipReport.ps1 -ExportCsvPath .\outputs\group-membership-report.csv
.\Get-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn -NeverLoggedOnGraceDays 14 -ExportCsvPath .\outputs\stale-users.csv
.\Backup-LabGPOs.ps1 -BackupRoot .\outputs\gpo-backups -Verbose
```

`Backup-LabGPOs.ps1` uses Microsoft `Backup-GPO` and accepts `-BackupRoot` to
control where timestamped backups are written.

`Get-StaleADUsers.ps1` and `Disable-StaleADUsers.ps1` support
`-NeverLoggedOnGraceDays` when `-IncludeNeverLoggedOn` is used, so newly created
accounts are not immediately flagged simply because they have not logged in yet.

## Production Notes

- Review search bases and OU paths before running against any real domain.
- Export reports before disabling accounts or deleting local profiles.
- Keep `-WhatIf` output as evidence for planned changes.
- Do not run profile cleanup against shared clinical, kiosk, or specialty devices
  without confirming application data storage behavior first.
