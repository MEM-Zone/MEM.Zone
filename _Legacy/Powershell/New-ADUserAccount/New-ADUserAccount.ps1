<# Run Section only Once
$Server = 'DC1'

$Session = New-PSSession -ComputerName $Server -Credential (Get-Credential)
Invoke-command { Import-Module ActiveDirectory } -Session $Session
Export-PSSession -Session $Session -CommandName *-AD* -OutputModule RemAD -AllowClobber

Exit-PSSession
#>

Import-Module RemAD

$DisplayName = (Get-Culture).textinfo.totitlecase($(Read-Host 'Display Name (ex:Gica Popescu)'))
$SamAccountName = $DisplayName.ToLower() -Replace ' ','.'
$AccountPassword = Read-Host -AsSecureString "AccountPassword"
$SurName = $($DisplayName -Split ' ')[0]
$Name = $($DisplayName -Split ' ')[1]
$UserPrincipalName = $SamAccountName + "@ulbsibiu.local


$Description = (Get-Culture).textinfo.totitlecase($(Read-Host 'Description'))
$OUName = Read-Host 'Organisational Unit Name (ex:Trash*)'
$OUDN = Get-ADOrganizationalUnit -Filter 'Name -Like "*"' | Where-Object { $_.Name -Like $OUName } | Select-Object -ExpandProperty DistinguishedName

Try {
    New-ADUser -Name $DisplayName -Surname $SurName -GivenName $SurName -DisplayName $DisplayName -Description $Description -UserPrincipalName $UserPrincipalName -SamAccountName $SamAccountName -AccountPassword $AccountPassword -Path $OUDN -Enabled $True
    Write-Host "Create User $SamAccountName - Success!" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
}
Catch {
    Write-Host "Create User $SamAccountName - Failed!" -ForegroundColor 'Red' -BackgroundColor 'Black'
}
