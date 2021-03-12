$username = "username"
$User = Get-ADUser $username  -properties pwdlastset
[datetime]::fromFileTime($user.pwdlastset)
$User.pwdlastset = 0
Set-ADUser -Instance $User
$user.pwdlastset = -1
Set-ADUser -instance $User
$User = Get-ADUser $username  -properties pwdlastset
[datetime]::fromFileTime($user.pwdlastset)
