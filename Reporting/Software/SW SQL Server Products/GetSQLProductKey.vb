'.SYNOPSIS
'    Gets SQL product key.
'.DESCRIPTION
'    Gets SQL product key from a binary string array.
'.PARAMETER astrBinaryKey
'    Specifies the obfuscated key.
'.PARAMETER intVersion
'    Specifies the SQL version.
'.EXAMPLE
'    Code.GetSQLProductKey(Fields!SomeField.Value, 12) (SSRS)
'.EXAMPLE
'    GetSQLProductKey({1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0}, 12) (VB.Net)
'.NOTES
'    Created by Ioan Popovici.
'    Credit to Jakob Bindslet and Chrissy LeMaire.
'    I only translated the script in Visual Basic, nothing else.
'.LINK
'    http://mspowershell.blogspot.com/2010/11/sql-server-product-key.html (Jakob Bindslet)
'    https://gallery.technet.microsoft.com/scriptcenter/Get-SQL-Server-Product-4b5bf4f8 (Chrissy LeMaire)
'.LINK
'    https://SCCM.Zone
'.LINK
'    https://SCCM.Zone/Issues
'
'/*##=============================================*/
'/*## SCRIPT BODY                                 */
'/*##=============================================*/
'/* #region FunctionBody */

Function GetSQLProductKey(ByVal astrBinaryKey As String(), ByVal intVersion As Integer) As String
    Dim achrKeyChars As Char() = {"B", "C", "D", "F", "G", "H", "J", "K", "M", "P", "Q", "R", "T", "V", "W", "X", "Y", "2", "3", "4", "6", "7", "8", "9"}
    Dim strSQLProductKey As String
    Dim iastrBinaryKey As Long
    Dim iachrKeyChars As Long
    Dim iastrBinaryKeyOuterLoop As Long
    Dim iastrBinaryKeyInnerLoop As Long
    Try
        If (intVersion >= 11) Then
            iastrBinaryKey = 0
        Else
            iastrBinaryKey = 52
        End If
        For iastrBinaryKeyOuterLoop = 24 To 0 Step -1
            iachrKeyChars = 0
            For iastrBinaryKeyInnerLoop = 14 To 0 Step -1
                iachrKeyChars = iachrKeyChars * 256 Xor astrBinaryKey(iastrBinaryKeyInnerLoop + iastrBinaryKey)
                astrBinaryKey(iastrBinaryKeyInnerLoop + iastrBinaryKey) = Math.Truncate(iachrKeyChars / 24)
                iachrKeyChars = iachrKeyChars Mod 24
            Next iastrBinaryKeyInnerLoop
            strSQLProductKey = achrKeyChars(iachrKeyChars) + strSQLProductKey
            If (iastrBinaryKeyOuterLoop Mod 5) = 0 And iastrBinaryKeyOuterLoop <> 0 Then
                strSQLProductKey = "-" + strSQLProductKey
            End If
        Next iastrBinaryKeyOuterLoop
    Catch
        strSQLProductKey = "Cannot decode product key."
    End Try
    GetSQLProductKey = strSQLProductKey
End Function

'/* #endregion */
'/*##=============================================*/
'/*## END SCRIPT BODY                             */
'/*##=============================================*/