$Domain = 'test.test.com'
$SearchBase = 'DC=test,DC=test,DC=com'
$ResultPath = 'C:\Temp\Scripts\'
$ResultFile = $ResultPath+'UserGroupMembership_TST.csv'
If ((Test-Path $ResultPath) -eq $False) {
New-Item -Path $ResultPath -Type Directory | Out-Null
} ElseIf (Test-Path $ResultPath) {
Remove-Item $ResultPath\* -Recurse -Force
}

[array]$UserInfo = Get-ADUser -Server $Domain -SearchBase $SearchBase -Properties Name, SamAccountName, Description, Department, Manager -Filter * |
Select-Object @{Name='Manager';Expression={(($_.Manager).Split('=')[1]).Split(',')[0]}},Name,SamAccountName,Description,Department,Groups

$UserInfo | ForEach-Object {
   $Groups = Get-ADPrincipalGroupMembership -Server $Domain -Identity $_.SamAccountName | ForEach-Object {$_.SamAccountName+";"}
   $Index = [array]::IndexOf($UserInfo, $_)
   $UserInfo[$Index].Groups = $Groups
}

$UserInfo | Select-Object Name,SamAccountName,Description,Department,Manager, @{Name='Groups';Expression={$_.Groups}} | Export-Csv -Encoding UTF8 -NoTypeInformation -Path $ResultFile -Force
