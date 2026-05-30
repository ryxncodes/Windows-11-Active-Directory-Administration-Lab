<#
.SYNOPSIS
Runs non-destructive health checks for the rk-lab.local Active Directory lab.

.DESCRIPTION
Checks DNS, domain controller reachability, SYSVOL and NETLOGON shares, expected
OUs, expected security groups, expected SMB shares, and basic GPO visibility.

The script uses built-in Windows and Microsoft administration cmdlets when they
are available. It does not require third-party modules. Checks that require
missing Microsoft modules return WARN instead of stopping the full report.

.PARAMETER DomainName
The Active Directory DNS domain name to test.

.PARAMETER DomainController
The expected domain controller hostname.

.PARAMETER DomainControllerIp
The expected domain controller IP address.

.PARAMETER ExpectedOu
Distinguished names of expected lab OUs.

.PARAMETER ExpectedGroup
Expected lab security groups.

.PARAMETER ExpectedShare
Expected SMB shares on the domain controller.

.PARAMETER ExpectedGpo
Expected lab Group Policy Objects.

.EXAMPLE
.\Test-ADLabHealth.ps1

.EXAMPLE
.\Test-ADLabHealth.ps1 -Verbose
#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DomainName = "rk-lab.local",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DomainController = "DC01",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DomainControllerIp = "10.10.10.10",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
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

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$ExpectedGroup = @(
        "GG_IT_Admins",
        "GG_HR_FileShare_RW",
        "GG_Finance_FileShare_RW",
        "GG_Operations_FileShare_RW",
        "GG_All_Employees",
        "GG_Standard_Users"
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$ExpectedShare = @(
        "Departments",
        "Public",
        "SYSVOL",
        "NETLOGON"
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
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

$script:Results = New-Object System.Collections.Generic.List[object]

function Add-LabCheckResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Check,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:Results.Add([PSCustomObject]@{
        Status  = $Status
        Check   = $Check
        Message = $Message
    })
}

function Test-CommandAvailable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-ModuleAvailable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool](Get-Module -ListAvailable -Name $Name)
}

Write-Verbose "Starting AD lab health checks for $DomainName using expected DC $DomainController ($DomainControllerIp)."

try {
    if (Test-Connection -ComputerName $DomainControllerIp -Count 2 -Quiet) {
        Add-LabCheckResult -Status PASS -Check "DC IP reachability" -Message "$DomainControllerIp responded to ICMP."
    }
    else {
        Add-LabCheckResult -Status FAIL -Check "DC IP reachability" -Message "$DomainControllerIp did not respond to ICMP."
    }
}
catch {
    Add-LabCheckResult -Status FAIL -Check "DC IP reachability" -Message $_.Exception.Message
}

try {
    if (Test-Connection -ComputerName $DomainController -Count 2 -Quiet) {
        Add-LabCheckResult -Status PASS -Check "DC hostname reachability" -Message "$DomainController responded to ICMP."
    }
    else {
        Add-LabCheckResult -Status WARN -Check "DC hostname reachability" -Message "$DomainController did not respond to ICMP. Check DNS and firewall settings."
    }
}
catch {
    Add-LabCheckResult -Status WARN -Check "DC hostname reachability" -Message $_.Exception.Message
}

if (Test-CommandAvailable -Name Resolve-DnsName) {
    try {
        $DnsResult = Resolve-DnsName -Name $DomainController -ErrorAction Stop
        $ResolvedAddresses = @($DnsResult | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress)

        if ($ResolvedAddresses -contains $DomainControllerIp) {
            Add-LabCheckResult -Status PASS -Check "DNS lookup" -Message "$DomainController resolves to $DomainControllerIp."
        }
        elseif ($ResolvedAddresses.Count -gt 0) {
            Add-LabCheckResult -Status WARN -Check "DNS lookup" -Message "$DomainController resolved to $($ResolvedAddresses -join ', '), expected $DomainControllerIp."
        }
        else {
            Add-LabCheckResult -Status FAIL -Check "DNS lookup" -Message "$DomainController resolved without an A record."
        }
    }
    catch {
        Add-LabCheckResult -Status FAIL -Check "DNS lookup" -Message $_.Exception.Message
    }
}
else {
    Add-LabCheckResult -Status WARN -Check "DNS lookup" -Message "Resolve-DnsName is not available on this system."
}

foreach ($Share in $ExpectedShare) {
    $SharePath = "\\$DomainController\$Share"

    try {
        if (Test-Path -Path $SharePath) {
            Add-LabCheckResult -Status PASS -Check "SMB share: $Share" -Message "$SharePath is reachable."
        }
        else {
            Add-LabCheckResult -Status FAIL -Check "SMB share: $Share" -Message "$SharePath is not reachable."
        }
    }
    catch {
        Add-LabCheckResult -Status FAIL -Check "SMB share: $Share" -Message $_.Exception.Message
    }
}

if (Test-ModuleAvailable -Name ActiveDirectory) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        foreach ($OU in $ExpectedOu) {
            try {
                $null = Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop
                Add-LabCheckResult -Status PASS -Check "OU exists" -Message $OU
            }
            catch {
                Add-LabCheckResult -Status FAIL -Check "OU missing" -Message $OU
            }
        }

        foreach ($Group in $ExpectedGroup) {
            try {
                $null = Get-ADGroup -Identity $Group -ErrorAction Stop
                Add-LabCheckResult -Status PASS -Check "Security group exists" -Message $Group
            }
            catch {
                Add-LabCheckResult -Status FAIL -Check "Security group missing" -Message $Group
            }
        }
    }
    catch {
        Add-LabCheckResult -Status WARN -Check "ActiveDirectory module" -Message $_.Exception.Message
    }
}
else {
    Add-LabCheckResult -Status WARN -Check "ActiveDirectory module" -Message "ActiveDirectory module is not available. Skipping OU and group checks."
}

if (Test-ModuleAvailable -Name GroupPolicy) {
    try {
        Import-Module GroupPolicy -ErrorAction Stop

        foreach ($Gpo in $ExpectedGpo) {
            try {
                $null = Get-GPO -Name $Gpo -ErrorAction Stop
                Add-LabCheckResult -Status PASS -Check "GPO visible" -Message $Gpo
            }
            catch {
                Add-LabCheckResult -Status FAIL -Check "GPO missing" -Message $Gpo
            }
        }
    }
    catch {
        Add-LabCheckResult -Status WARN -Check "GroupPolicy module" -Message $_.Exception.Message
    }
}
else {
    Add-LabCheckResult -Status WARN -Check "GroupPolicy module" -Message "GroupPolicy module is not available. Skipping GPO visibility checks."
}

$script:Results | Format-Table -AutoSize

$PassCount = @($script:Results | Where-Object { $_.Status -eq "PASS" }).Count
$WarnCount = @($script:Results | Where-Object { $_.Status -eq "WARN" }).Count
$FailCount = @($script:Results | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Host ""
Write-Host "Summary: PASS=$PassCount WARN=$WarnCount FAIL=$FailCount"

if ($FailCount -gt 0) {
    exit 1
}

if ($WarnCount -gt 0) {
    exit 2
}

exit 0
