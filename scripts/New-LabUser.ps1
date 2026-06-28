<#
Creates a lab AD user in the right OU and groups.

Examples:
  .\New-LabUser.ps1 -FirstName Alex -LastName Rivera -Department IT -TemporaryPassword "ChangeMe123!" -WhatIf
  .\New-LabUser.ps1 -CsvPath .\lab-users.csv -WhatIf
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Single")]
param (
    [Parameter(Mandatory, ParameterSetName = "Single")]
    [string]$FirstName,

    [Parameter(Mandatory, ParameterSetName = "Single")]
    [string]$LastName,

    [Parameter(Mandatory, ParameterSetName = "Single")]
    [ValidateSet("IT", "HR", "Finance", "Operations")]
    [string]$Department,

    [Parameter(Mandatory, ParameterSetName = "Single")]
    [string]$TemporaryPassword,

    [Parameter(Mandatory, ParameterSetName = "Csv")]
    [string]$CsvPath,

    [switch]$AllowDuplicateNameSuffix
)

$ErrorActionPreference = "Stop"

$DomainName = "rk-lab.local"
$DefaultGroups = @("GG_All_Employees", "GG_Standard_Users")

$DepartmentInfo = @{
    IT = @{
        OU    = "OU=IT,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_IT_Admins"
    }
    HR = @{
        OU    = "OU=HR,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_HR_FileShare_RW"
    }
    Finance = @{
        OU    = "OU=Finance,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_Finance_FileShare_RW"
    }
    Operations = @{
        OU    = "OU=Operations,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_Operations_FileShare_RW"
    }
}

Import-Module ActiveDirectory

function Get-Username {
    param (
        [string]$First,
        [string]$Last
    )

    $BaseName = ("$First.$Last").ToLower()
    $BaseName = $BaseName -replace "\s+", ""
    $BaseName = $BaseName -replace "[^a-z0-9.]", ""
    $BaseName = $BaseName.Trim(".")

    if ([string]::IsNullOrWhiteSpace($BaseName)) {
        throw "Could not make a username from '$First $Last'."
    }

    $BaseName = $BaseName.Substring(0, [Math]::Min(20, $BaseName.Length))
    $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$BaseName'" -ErrorAction SilentlyContinue

    if ($ExistingUser -and -not $AllowDuplicateNameSuffix) {
        return @{
            Name   = $BaseName
            Exists = $true
        }
    }

    $Counter = 1

    do {
        if ($Counter -eq 1) {
            $Username = $BaseName
        }
        else {
            $Suffix = [string]$Counter
            $TrimmedBase = $BaseName.Substring(0, [Math]::Min(20 - $Suffix.Length, $BaseName.Length))
            $Username = "$TrimmedBase$Suffix"
        }

        $Counter++
        $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue
    } while ($ExistingUser)

    return @{
        Name   = $Username
        Exists = $false
    }
}

function New-OneLabUser {
    param (
        [string]$UserFirstName,
        [string]$UserLastName,
        [string]$UserDepartment,
        [string]$UserPassword
    )

    $UserFirstName = $UserFirstName.Trim()
    $UserLastName = $UserLastName.Trim()
    $UserDepartment = $UserDepartment.Trim()
    $UserPassword = $UserPassword.Trim()

    if ([string]::IsNullOrWhiteSpace($UserFirstName) -or [string]::IsNullOrWhiteSpace($UserLastName)) {
        throw "FirstName and LastName cannot be blank."
    }

    if (-not $DepartmentInfo.ContainsKey($UserDepartment)) {
        throw "Department must be IT, HR, Finance, or Operations."
    }

    if ($UserPassword.Length -lt 10) {
        throw "Temporary password needs to be at least 10 characters."
    }

    $TargetOU = $DepartmentInfo[$UserDepartment].OU
    $Groups = $DefaultGroups + $DepartmentInfo[$UserDepartment].Group
    $UsernameResult = Get-Username -First $UserFirstName -Last $UserLastName
    $Username = $UsernameResult.Name
    $DisplayName = "$UserFirstName $UserLastName"
    $Upn = "$Username@$DomainName"
    $AdObjectName = $DisplayName

    if ($Username -ne ("$UserFirstName.$UserLastName").ToLower()) {
        $AdObjectName = "$DisplayName ($Username)"
    }

    if ($UsernameResult.Exists) {
        Write-Host "Skipping $DisplayName. Username already exists: $Username"

        return [PSCustomObject]@{
            Name       = $DisplayName
            Username   = $Username
            Department = $UserDepartment
            Status     = "Skipped - username exists"
        }
    }

    if (-not (Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction SilentlyContinue)) {
        throw "Missing target OU: $TargetOU"
    }

    foreach ($Group in $Groups) {
        if (-not (Get-ADGroup -Identity $Group -ErrorAction SilentlyContinue)) {
            throw "Missing required group: $Group"
        }
    }

    Write-Host ""
    Write-Host "User: $DisplayName"
    Write-Host "Username: $Username"
    Write-Host "Department: $UserDepartment"
    Write-Host "OU: $TargetOU"
    Write-Host "Groups: $($Groups -join ', ')"

    if ($PSCmdlet.ShouldProcess($Username, "Create lab AD user")) {
        $SecurePassword = ConvertTo-SecureString $UserPassword -AsPlainText -Force

        New-ADUser `
            -Name $AdObjectName `
            -GivenName $UserFirstName `
            -Surname $UserLastName `
            -DisplayName $DisplayName `
            -SamAccountName $Username `
            -UserPrincipalName $Upn `
            -Path $TargetOU `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -Department $UserDepartment

        foreach ($Group in $Groups) {
            Add-ADGroupMember -Identity $Group -Members $Username
        }

        $Status = "Created"
    }
    else {
        $Status = "WhatIf - no changes"
    }

    return [PSCustomObject]@{
        Name       = $DisplayName
        Username   = $Username
        Department = $UserDepartment
        UPN        = $Upn
        OU         = $TargetOU
        Groups     = ($Groups -join ", ")
        Status     = $Status
    }
}

if ($PSCmdlet.ParameterSetName -eq "Csv") {
    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        throw "CSV file not found: $CsvPath"
    }

    $Users = Import-Csv -LiteralPath $CsvPath
    $RequiredColumns = @("FirstName", "LastName", "Department", "TemporaryPassword")

    if (-not $Users) {
        throw "CSV file has no users: $CsvPath"
    }

    foreach ($Column in $RequiredColumns) {
        if ($Users[0].PSObject.Properties.Name -notcontains $Column) {
            throw "CSV is missing column: $Column"
        }
    }

    foreach ($User in $Users) {
        New-OneLabUser `
            -UserFirstName $User.FirstName `
            -UserLastName $User.LastName `
            -UserDepartment $User.Department `
            -UserPassword $User.TemporaryPassword
    }
}
else {
    New-OneLabUser `
        -UserFirstName $FirstName `
        -UserLastName $LastName `
        -UserDepartment $Department `
        -UserPassword $TemporaryPassword
}
