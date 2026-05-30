# Script Safety Notes

These scripts are lab automation examples for `rk-lab.local`. They are intended
to show safe junior systems administration habits, not to be copied into
production without review.

## Validation Status

All PowerShell scripts in this repository have been syntax-checked with
PowerShell. Scripts that require a domain controller, RSAT modules, or Windows
profile data still need to be tested inside the Windows lab environment before
being treated as operational tools.

## Destructive Scripts

The following scripts can change or remove data:

| Script | Risk | Guardrails |
|---|---|---|
| [`Disable-StaleADUsers.ps1`](../scripts/Disable-StaleADUsers.ps1) | Disables AD accounts and can move objects | Supports `-WhatIf`; ignores never-logged-on users unless `-IncludeNeverLoggedOn` is used |
| [`Remove-StaleLocalProfiles.ps1`](../scripts/Remove-StaleLocalProfiles.ps1) | Removes local Windows user profiles | Supports `-WhatIf`; skips loaded/special profiles; defaults to `RK-LAB` domain profiles only |
| [`New-LabUser.ps1`](../scripts/New-LabUser.ps1) | Creates AD users and adds group membership | Supports `-WhatIf`; validates required fields, departments, OUs, and groups |

Recommended first run:

```powershell
.\Disable-StaleADUsers.ps1 -DaysInactive 180 -WhatIf
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -DomainNetbiosName RK-LAB -WhatIf
```

## Read-Only Scripts

The following scripts are intended to be non-destructive:

- [`Get-StaleADUsers.ps1`](../scripts/Get-StaleADUsers.ps1)
- [`Get-LabGroupMembershipReport.ps1`](../scripts/Get-LabGroupMembershipReport.ps1)
- [`Test-ADLabHealth.ps1`](../scripts/Test-ADLabHealth.ps1)

`Backup-LabGPOs.ps1` writes backup files but does not modify the GPOs.

## Production Notes

- Review search bases and OU paths before running against any real domain.
- Export reports before disabling accounts or deleting local profiles.
- Keep `-WhatIf` output as evidence for planned changes.
- Do not run profile cleanup against shared clinical, kiosk, or specialty devices
  without confirming application data storage behavior first.
