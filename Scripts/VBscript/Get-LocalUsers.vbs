on error resume next
'Steps
'enumerate from win32_group where localaccount=1
'Read in the members of each local group returned
'Add the returned information to a custom WMI namespace
'sms-def.mof to pull that back.
Set fso = CreateObject("Scripting.FileSystemObject")
Set nwo = CreateObject("Wscript.Network")
Set sho = CreateObject("Wscript.Shell")
TempFolder = sho.ExpandEnvironmentStrings("%temp%") + "\"
strWindir = sho.ExpandEnvironmentStrings("%windir%")
strComputer = nwo.ComputerName
Dim wbemCimtypeSint16
Dim wbemCimtypeSint32
Dim wbemCimtypeReal32
Dim wbemCimtypeReal64
Dim wbemCimtypeString
Dim wbemCimtypeBoolean
Dim wbemCimtypeObject
Dim wbemCimtypeSint8
Dim wbemCimtypeUint8
Dim wbemCimtypeUint16
Dim wbemCimtypeUint32
Dim wbemCimtypeSint64
Dim wbemCimtypeUint64
Dim wbemCimtypeDateTime
Dim wbemCimtypeReference
Dim wbemCimtypeChar16



wbemCimtypeSint16 = 2
wbemCimtypeSint32 = 3
wbemCimtypeReal32 = 4
wbemCimtypeReal64 = 5
wbemCimtypeString = 8
wbemCimtypeBoolean = 11
wbemCimtypeObject = 13
wbemCimtypeSint8 = 16
wbemCimtypeUint8 = 17
wbemCimtypeUint16 = 18
wbemCimtypeUint32 = 19
wbemCimtypeSint64 = 20
wbemCimtypeUint64 = 21
wbemCimtypeDateTime = 101
wbemCimtypeReference = 102
wbemCimtypeChar16 = 103
'--------------
'New Logging Section
'--------------
strLogName = TempFolder & "SCCMLocalGroupMembers.log"
if (fso.fileexists(strLogName)) then fso.deletefile(strLogName) end if
set Logging = fso.OpenTextfile(strLogName,8,True)
Logging.WriteLine(Now & " - " & "Script Started")



' Remove classes
Set oLocation = CreateObject("WbemScripting.SWbemLocator")
'===================
'If this is a Domain Controller, bail!
'===================
Set oWMI = GetObject("winmgmts:" _
& "{impersonationLevel=impersonate}!\\.\root\cimv2")
Set colComputer = oWMI.ExecQuery _
("Select DomainRole from Win32_ComputerSystem")
For Each oComputer in colComputer
 if (oComputer.DomainRole = 4 or oComputer.DomainRole = 5) then
Logging.WriteLine(Now & " - " & "Domain Controller, Quitting")
   'wscript.quit
 Else
Logging.WriteLine(Now & " - " & "Not a Domain Controller, Continuing")
'==================
'If it is NOT a domain controller, then continue gathering info
'and stuff it into WMI for later easy retrieval
'==================



Set oServices = oLocation.ConnectServer(,"root\cimv2")
set oNewObject = oServices.Get("CM_LocalGroupMembers")
oNewObject.Delete_
Logging.WriteLine(Now & " - " & "Cleaned cm_localgroupmembers, if it existed.")
'==================
'Get the local Group Names
'==================
Dim iGroups(300)
i=0
Set objWMIService = GetObject("winmgmts:" _
        & "{impersonationLevel=impersonate}!\\.\root\cimv2")
Set colGroup = objWMIService.ExecQuery("select * from win32_group where localaccount=1")
for each obj in colGroup
  igroups(i)=obj.Name
  i=i+1
next
Logging.WriteLine(Now & " - " & "Found " & i & " Local Groups")
'===============
'Get all of the names within each group
dim strLocal(300)
k=0
Set oLocation = CreateObject("WbemScripting.SWbemLocator")
Set oServices = oLocation.ConnectServer(, "root\cimv2" )



'group name, domain name, user or group
for j = 0 to i-1



squery = "select partcomponent from win32_groupuser where groupcomponent = ""\\\\" &_
 strComputer & "\\root\\cimv2:Win32_Group.Domain=\""" & strComputer &_
 "\"",Name=\""" &igroups(j) & "\"""""



Set oInstances = oServices.ExecQuery(sQuery)
 FOR EACH oObject in oInstances
  strLocal(k)=igroups(j) & "!" & oObject.PartComponent



  k=k+1



 Next
next
Logging.WriteLine(Now & " - " & "Found a total of " & k-1 & " Names within those " & i & " groups")
'==================
'Drop that into a custom wmi Namespace
'==================




' Create data class structure
Set oDataObject = oServices.Get
oDataObject.Path_.Class = "CM_LocalGroupMembers"
oDataObject.Properties_.add "Account" , wbemCimtypeString
oDataObject.Properties_("Account").Qualifiers_.add "key" , True
oDataObject.Properties_.add "Domain" , wbemCimtypeString
oDataObject.Properties_("Domain").Qualifiers_.add "key" , True
oDataObject.Properties_.add "Category" , wbemCimtypeString
oDataObject.Properties_.add "Type" , wbemCimtypeString
oDataObject.Properties_.add "Name" , wbemCimtypeString
oDataObject.Properties_("Name").Qualifiers_.add "key" , True
oDataObject.Put_



Logging.WriteLine(Now & " - " & "Starting to populate cm_localgroupmembers")
for m = 0 to k-1
Set oNewObject = oServices.Get("CM_LocalGroupMembers" ).SpawnInstance_
str0 = Split(strLocal(m), "!", -1, 1)
str1 = Split(strLocal(m), ",", -1,1)
str2 = Split(str1(0), "\" , -1, 1)
str4 = Split(str2(4), Chr(34), -1, 1)




' The Account name or Group Name is inside the quotes after the comma
str3 = Split(str1(1), Chr(34), -1, 1)
' if the wmi source name is the same as the domain name inside the quotes, it' s a local account
' str2(2) is the wmi source name, str4(1) is the domain name inside the quotes.
If lcase(str2(2)) = lcase(str4(1)) Then
oNewObject.Type = "Local"
Else
oNewObject.Type = "Domain"
End If
oNewObject.Domain = str4(1)
oNewObject.Account = str3(1)
oNewObject.Name = str0(0)
Select Case lcase(str4(0))
  case "cimv2:win32_useraccount.domain="
   oNewObject.Category = "UserAccount"
  Case "cimv2:win32_group.domain="
   oNewObject.Category = "Group"
  Case "cimv2:win32_systemaccount.domain="
   oNewObject.Category = "SystemAccount"
  case else
   oNewObject.Category = "unknown"
end select
oNewObject.Put_
Next
Logging.WriteLine(Now & " - " & "Completed populating cm_localgroupmembers")



 end if
Next
Logging.WriteLine(Now & " - " & "Script Finished")
Logging.Close
wscript.quit