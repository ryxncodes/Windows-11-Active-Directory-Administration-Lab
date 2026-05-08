<#
.SYNOPSIS
Creates a new Active Directory lab user.

.DESCRIPTION
Creates a new user in the correct department OU, generates an available username,
sets a temporary password, requires password change at next logon, and adds the
user to the standard lab groups for that department.

This script is intended for the rk-lab.local Active Directory lab environment.
The default temporary password is for lab use only.

.PARAMETER FirstName
The user's first name.

.PARAMETER LastName
The user's last name.

.PARAMETER Department
The target department. Valid values are IT, HR, Finance, and Operations.

.PARAMETER TemporaryPassword
The temporary password assigned to the new account. The user is required to change
this password at next logon. Becuase this is for lab use, the default is a simple password. 
In a production environment, the temporary password should not be hardcoded into the script.
.EXAMPLE
.\New-LabUser.ps1 -FirstName Morgan -LastName Read -Department HR

.EXAMPLE
.\New-LabUser.ps1 -FirstName Taylor -LastName Smith -Department Finance -Verbose

.EXAMPLE
.\New-LabUser.ps1 -FirstName Alex -LastName Rivera -Department IT -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FirstName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$LastName,

    [Parameter(Mandatory)]
    [ValidateSet("IT", "HR", "Finance", "Operations")]
    [string]$Department,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TemporaryPassword = "Password123!" #For Lab Use only, do not do this!
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory -ErrorAction Stop

$DomainName = "rk-lab.local"

$DepartmentConfig = @{
    "IT" = @{
        OU    = "OU=IT,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_IT_Admins"
    }
    "HR" = @{
        OU    = "OU=HR,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_HR_FileShare_RW"
    }
    "Finance" = @{
        OU    = "OU=Finance,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_Finance_FileShare_RW"
    }
    "Operations" = @{
        OU    = "OU=Operations,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_Operations_FileShare_RW"
    }
}

function New-LabUsername {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName
    )

    $CleanFirstName = ($FirstName.Trim() -replace "\s+", "")
    $CleanLastName = ($LastName.Trim() -replace "\s+", "")
    $BaseUsername = ("$CleanFirstName.$CleanLastName").ToLower() -replace "[^a-z0-9.]", ""
    $BaseUsername = $BaseUsername.Trim(".")

    if ([string]::IsNullOrWhiteSpace($BaseUsername)) {
        throw "Unable to generate a valid username from FirstName and LastName."
    }

    $Counter = 1

    do {
        if ($Counter -eq 1) {
            $Suffix = ""
        }
        else {
            $Suffix = [string]$Counter
        }

        $MaxBaseLength = 20 - $Suffix.Length
        $UsernameBase = $BaseUsername.Substring(0, [Math]::Min($BaseUsername.Length, $MaxBaseLength))
        $Username = "$UsernameBase$Suffix"

        $Counter++
    } while (Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue)

    return $Username
}

$FirstName = $FirstName.Trim()
$LastName = $LastName.Trim()

$SelectedDepartment = $DepartmentConfig[$Department]
$TargetOU = $SelectedDepartment.OU
$DepartmentGroup = $SelectedDepartment.Group

$Username = New-LabUsername -FirstName $FirstName -LastName $LastName
$DisplayName = "$FirstName $LastName"
$BaseDisplayName = "$FirstName.$LastName".ToLower()
$UserPrincipalName = "$Username@$DomainName"

if ($Username -eq $BaseDisplayName) {
    $Name = $DisplayName
}
else {
    $Name = "$DisplayName ($Username)"
}

$StandardGroups = @(
    "GG_All_Employees",
    "GG_Standard_Users",
    $DepartmentGroup
)

Write-Verbose "Selected department: $Department"
Write-Verbose "Target OU: $TargetOU"
Write-Verbose "Generated username: $Username"
Write-Verbose "User principal name: $UserPrincipalName"
Write-Verbose "Groups to add: $($StandardGroups -join ', ')"

if (-not (Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction SilentlyContinue)) {
    throw "Target OU does not exist: $TargetOU"
}

foreach ($Group in $StandardGroups) {
    if (-not (Get-ADGroup -Identity $Group -ErrorAction SilentlyContinue)) {
        throw "Required group does not exist: $Group"
    }
}

$SecurePassword = ConvertTo-SecureString $TemporaryPassword -AsPlainText -Force

try {
    if ($PSCmdlet.ShouldProcess($Username, "Create AD user and apply group memberships")) {
        Write-Verbose "Creating AD user: $Name"

        New-ADUser `
            -Name $Name `
            -GivenName $FirstName `
            -Surname $LastName `
            -DisplayName $DisplayName `
            -SamAccountName $Username `
            -UserPrincipalName $UserPrincipalName `
            -Path $TargetOU `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -Department $Department

        foreach ($Group in $StandardGroups) {
            Write-Verbose "Adding $Username to $Group"
            Add-ADGroupMember -Identity $Group -Members $Username
        }

        $Status = "User created and group membership applied"
    }
    else {
        $Status = "WhatIf: no changes made"
    }

    [PSCustomObject]@{
        FirstName         = $FirstName
        LastName          = $LastName
        Department        = $Department
        Username          = $Username
        Name              = $Name
        UserPrincipalName = $UserPrincipalName
        TargetOU          = $TargetOU
        GroupsAdded       = ($StandardGroups -join ", ")
        Status            = $Status
    }
}
catch {
    [PSCustomObject]@{
        FirstName         = $FirstName
        LastName          = $LastName
        Department        = $Department
        Username          = $Username
        Name              = $Name
        UserPrincipalName = $UserPrincipalName
        TargetOU          = $TargetOU
        GroupsAdded       = ""
        Status            = "Failed"
        Error             = $_.Exception.Message
    }
}