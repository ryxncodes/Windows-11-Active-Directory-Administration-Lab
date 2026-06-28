<#
Quick health check for the RK-LAB domain.

This does not change anything. It checks the DC, DNS, expected shares, OUs,
groups, and GPOs.

Example:
  .\Test-ADLabHealth.ps1
#>

[CmdletBinding()]
param (
    [string]$DomainName = "rk-lab.local",
    [string]$DomainController = "DC01",
    [string]$DomainControllerIp = "10.10.10.10",

    [string[]]$ExpectedOu = @(
        "OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Computers,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Workstations,OU=Computers,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Servers,OU=Computers,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=IT,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=HR,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Finance,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Operations,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Service Accounts,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Disabled Users,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local",
        "OU=Groups,OU=_RK-LAB,DC=rk-lab,DC=local"
    ),

    [string[]]$ExpectedGroup = @(
        "GG_IT_Admins",
        "GG_HR_FileShare_RW",
        "GG_Finance_FileShare_RW",
        "GG_Operations_FileShare_RW",
        "GG_All_Employees",
        "GG_Standard_Users"
    ),

    [string[]]$ExpectedShare = @(
        "Departments",
        "Public",
        "SYSVOL",
        "NETLOGON"
    ),

    [string[]]$ExpectedGpo = @(
        "GPO-Workstations-Login-Banner",
        "GPO-Workstations-Local-Admins",
        "GPO-Workstations-Windows-Update",
        "GPO-Users-Mapped-Drives",
        "GPO-Users-Standard-Restrictions",
        "Default Domain Policy"
    )
)

$ErrorActionPreference = "Stop"
$Results = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param (
        [string]$Status,
        [string]$Check,
        [string]$Message
    )

    $Results.Add([PSCustomObject]@{
        Status  = $Status
        Check   = $Check
        Message = $Message
    })
}

function Test-CommandExists {
    param ([string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-ModuleExists {
    param ([string]$Name)
    return [bool](Get-Module -ListAvailable -Name $Name)
}

Write-Host "Checking $DomainName"
Write-Host "Expected DC: $DomainController ($DomainControllerIp)"
Write-Host ""

try {
    if (Test-Connection -ComputerName $DomainControllerIp -Count 2 -Quiet) {
        Add-Check "PASS" "DC IP ping" "$DomainControllerIp responded."
    }
    else {
        Add-Check "FAIL" "DC IP ping" "$DomainControllerIp did not respond."
    }
}
catch {
    Add-Check "FAIL" "DC IP ping" $_.Exception.Message
}

try {
    if (Test-Connection -ComputerName $DomainController -Count 2 -Quiet) {
        Add-Check "PASS" "DC name ping" "$DomainController responded."
    }
    else {
        Add-Check "WARN" "DC name ping" "$DomainController did not respond. DNS or firewall may be the issue."
    }
}
catch {
    Add-Check "WARN" "DC name ping" $_.Exception.Message
}

if (Test-CommandExists "Resolve-DnsName") {
    try {
        $DnsResults = Resolve-DnsName -Name $DomainController
        $IpAddresses = @($DnsResults | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress)

        if ($IpAddresses -contains $DomainControllerIp) {
            Add-Check "PASS" "DNS lookup" "$DomainController resolves to $DomainControllerIp."
        }
        elseif ($IpAddresses.Count -gt 0) {
            Add-Check "WARN" "DNS lookup" "$DomainController resolved to $($IpAddresses -join ', ') instead of $DomainControllerIp."
        }
        else {
            Add-Check "FAIL" "DNS lookup" "$DomainController did not return an A record."
        }
    }
    catch {
        Add-Check "FAIL" "DNS lookup" $_.Exception.Message
    }
}
else {
    Add-Check "WARN" "DNS lookup" "Resolve-DnsName is not available."
}

foreach ($Share in $ExpectedShare) {
    $SharePath = "\\$DomainController\$Share"

    try {
        if (Test-Path -Path $SharePath) {
            Add-Check "PASS" "Share $Share" "$SharePath is reachable."
        }
        else {
            Add-Check "FAIL" "Share $Share" "$SharePath is not reachable."
        }
    }
    catch {
        Add-Check "FAIL" "Share $Share" $_.Exception.Message
    }
}

if (Test-ModuleExists "ActiveDirectory") {
    try {
        Import-Module ActiveDirectory

        foreach ($OU in $ExpectedOu) {
            try {
                Get-ADOrganizationalUnit -Identity $OU | Out-Null
                Add-Check "PASS" "OU exists" $OU
            }
            catch {
                Add-Check "FAIL" "OU missing" $OU
            }
        }

        foreach ($Group in $ExpectedGroup) {
            try {
                Get-ADGroup -Identity $Group | Out-Null
                Add-Check "PASS" "Group exists" $Group
            }
            catch {
                Add-Check "FAIL" "Group missing" $Group
            }
        }
    }
    catch {
        Add-Check "WARN" "ActiveDirectory module" $_.Exception.Message
    }
}
else {
    Add-Check "WARN" "ActiveDirectory module" "Module is not installed here, so OU/group checks were skipped."
}

if (Test-ModuleExists "GroupPolicy") {
    try {
        Import-Module GroupPolicy

        foreach ($Gpo in $ExpectedGpo) {
            try {
                Get-GPO -Name $Gpo | Out-Null
                Add-Check "PASS" "GPO exists" $Gpo
            }
            catch {
                Add-Check "FAIL" "GPO missing" $Gpo
            }
        }
    }
    catch {
        Add-Check "WARN" "GroupPolicy module" $_.Exception.Message
    }
}
else {
    Add-Check "WARN" "GroupPolicy module" "Module is not installed here, so GPO checks were skipped."
}

$Results | Format-Table -AutoSize

$PassCount = @($Results | Where-Object { $_.Status -eq "PASS" }).Count
$WarnCount = @($Results | Where-Object { $_.Status -eq "WARN" }).Count
$FailCount = @($Results | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Host ""
Write-Host "Summary: PASS=$PassCount WARN=$WarnCount FAIL=$FailCount"

if ($FailCount -gt 0) {
    exit 1
}

if ($WarnCount -gt 0) {
    exit 2
}

exit 0
