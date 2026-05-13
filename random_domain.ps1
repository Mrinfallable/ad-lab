param( 
    [Parameter(Mandatory=$true)] [string]$OutputJSONFile,
    [int]$UserCount = 5,
    [int]$GroupCount = 1,
    [int]$LocalAdminCount = 0
)

$group_names = [System.Collections.Generic.List[string]]::new((Get-Content "data/group_names.txt"))
$first_names = [System.Collections.Generic.List[string]]::new((Get-Content "data/first_names.txt"))
$last_names  = [System.Collections.Generic.List[string]]::new((Get-Content "data/last_names.txt"))
$passwords   = [System.Collections.Generic.List[string]]::new((Get-Content "data/passwords.txt"))

$groups = @()
$users  = @()


$local_admin_indexes = if ($LocalAdminCount -gt 0) {
    Get-Random -InputObject (1..$UserCount) -Count $LocalAdminCount
} else { @() }


for ($i = 1; $i -le $GroupCount; $i++) {
    $group_name = Get-Random -InputObject $group_names
    $groups += @{ "name" = $group_name }
    [void]$group_names.Remove($group_name)
}


for ($i = 1; $i -le $UserCount; $i++) {
    $first_name = Get-Random -InputObject $first_names
    $last_name  = Get-Random -InputObject $last_names
    $password   = Get-Random -InputObject $passwords

    $new_user = @{
        "name"     = "$first_name $last_name"
        "password" = $password
        "groups"   = (Get-Random -InputObject $groups).name
    }

    if ($local_admin_indexes -contains $i) {
        Write-Host "User $i assigned as local admin" -ForegroundColor Cyan
        $new_user["local_admin"] = @("localhost") 
    }

    $users += $new_user

    [void]$first_names.Remove($first_name)
    [void]$last_names.Remove($last_name)
    [void]$passwords.Remove($password)
}

$output = @{ 
    "domain" = "xyz.com"
    "groups" = $groups
    "users"  = $users
}

$output | ConvertTo-Json -Depth 5 | Out-File $OutputJSONFile
Write-Host "Lab data generated: $OutputJSONFile" -ForegroundColor Green
