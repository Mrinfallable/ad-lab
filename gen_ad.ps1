param( 
    [Parameter(Mandatory=$true)] [string]$JSONFile,
    [switch]$Undo
)

function Set-LabPasswordPolicy {
    param([bool]$Weaken)
    $cfgPath = "$env:TEMP\secpol.cfg"
    $comp, $len = if ($Weaken) { "0", "1" } else { "1", "7" }
    
    secedit /export /cfg $cfgPath
    (Get-Content $cfgPath).Replace("PasswordComplexity = $(1-$comp)", "PasswordComplexity = $comp").Replace("MinimumPasswordLength = $(8-$len)", "MinimumPasswordLength = $len") | Out-File $cfgPath
    secedit /configure /db $env:windir\security\local.sdb /cfg $cfgPath /areas SECURITYPOLICY
    Remove-Item $cfgPath -Force
}

function New-LabADUser {
    param([Parameter(Mandatory=$true)] $userObject, [string]$Domain)

    $names = $userObject.name.Split(" ")
    $firstname = $names[0]
    $lastname = $names[-1]
    $username = ($firstname[0] + $lastname).ToLower()

    $securePass = ConvertTo-SecureString $userObject.password -AsPlainText -Force

    try {
        New-ADUser -Name $userObject.name -GivenName $firstname -Surname $lastname `
                   -SamAccountName $username -UserPrincipalName "$username@$Domain" `
                   -AccountPassword $securePass -PassThru | Enable-ADAccount
        
        foreach ($group_name in $userObject.groups) {
            Add-ADGroupMember -Identity $group_name -Members $username -ErrorAction SilentlyContinue
        }

        # Handle Local Admin Rights
        foreach ($hostname in $userObject.local_admin) {
            Write-Host "Adding $username to local admins on $hostname" -ForegroundColor Yellow
            Invoke-Command -ComputerName $hostname -ScriptBlock {
                param($u, $d)
                net localgroup administrators "$d\$u" /add
            } -ArgumentList $username, $Domain
        }
    } catch {
        Write-Error "Failed to create user $($userObject.name): $($_.Exception.Message)"
    }
}



if (-not (Test-Path $JSONFile)) { throw "JSON file not found." }
$data = Get-Content $JSONFile | ConvertFrom-Json
$Domain = $data.domain

if (-not $Undo) {
    Set-LabPasswordPolicy -Weaken $true

    foreach ($group in $data.groups) {
        Write-Host "Creating Group: $($group.name)"
        New-ADGroup -Name $group.name -GroupScope Global -ErrorAction SilentlyContinue
    }

    foreach ($user in $data.users) {
        Write-Host "Creating User: $($user.name)"
        New-LabADUser -userObject $user -Domain $Domain
    }
} else {
    Set-LabPasswordPolicy -Weaken $false

    foreach ($user in $data.users) {
        $username = ($user.name.Split(" ")[0][0] + $user.name.Split(" ")[-1]).ToLower()
        Remove-ADUser -Identity $username -Confirm:$false -ErrorAction SilentlyContinue
    }

    foreach ($group in $data.groups) {
        Remove-ADGroup -Identity $group.name -Confirm:$false -ErrorAction SilentlyContinue
    }
}
