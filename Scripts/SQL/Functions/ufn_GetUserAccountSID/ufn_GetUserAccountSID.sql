/*
.SYNOPSIS
    Gets the SID for a specified User Account.
.DESCRIPTION
    Gets the binary and human readable SID for a specified User Account.
.PARAMETER UserAccount
    Specifies the User Account name.
.PARAMETER ValidateUserAccount
    Specifies if the User Account name should be validated.
    Available values: 0, 1, Default: 0.
.EXAMPLE
    SELECT dbo.ufn_GetUserAccountSID('Domain\UserName', DEFAULT);
.NOTES
    Created by Ioan Popovici
    Credit to Balmukund Lakhani
    2021-09-09
.LINK
   https://sqlserver-help.com/tag/convert-sid/ (Balmukund Lakhani)
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* #region SSMS */
-- USE [<DatabaseName>]

/* Drop function if it exists */
-- IF OBJECT_ID('[dbo].[ufn_GetUserAccountSID]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_GetUserAccountSID]
--    END
-- GO
/* #endregion */

/* #region create ufn_GetUserAccountSID */
CREATE FUNCTION [dbo].[ufn_GetUserAccountSID] (
    @UserAccount AS NVARCHAR(100)
    , @ValidataUserAccount AS INT = 0
)
RETURNS @UserAccountSID TABLE (
    BinarySID     VARBINARY(85)
    , ReadableSID NVARCHAR(85)
)
AS
    BEGIN

        DECLARE @BinarySID   AS VARBINARY(85);
        SET @BinarySID = SUSER_SSID(@UserAccount, @ValidataUserAccount)
        DECLARE @ReadableSID AS NVARCHAR(85);
        SET @ReadableSID = (
            SELECT (
                'S-'
                + CONVERT(NVARCHAR, CONVERT(INT, SUBSTRING(@BinarySID, 1, 1)))
                + '-'
                + CONVERT(NVARCHAR, CONVERT(INT, SUBSTRING(@BinarySID, 3, 6)))
                + '-'
                + CONVERT(NVARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(SUBSTRING(@BinarySID, 9, 4)))))
                + IIF(LEN(@BinarySID) > 13, '-' + CONVERT(NVARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(SUBSTRING(@BinarySID, 13, 4))))), '')
                + IIF(LEN(@BinarySID) > 17, '-' + CONVERT(NVARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(SUBSTRING(@BinarySID, 17, 4))))), '')
                + IIF(LEN(@BinarySID) > 21, '-' + CONVERT(NVARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(SUBSTRING(@BinarySID, 21, 4))))), '')
                + IIF(LEN(@BinarySID) > 25, '-' + CONVERT(NVARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(SUBSTRING(@BinarySID, 25, 4))))), '')
                + IIF(LEN(@BinarySID) > 29, '-' + CONVERT(NVARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(SUBSTRING(@BinarySID, 29, 4))))), '')
            )
        )

        /* Create result table */
        INSERT INTO @UserAccountSID VALUES (@BinarySID, @ReadableSID)

        /* Return result */
        RETURN
    END
/* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/