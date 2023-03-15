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

/* Set CM DB Name */
DECLARE @CM_DB AS NVARCHAR(6) = 'CM_XXX';

/* Get all relevant views */
SELECT DISTINCT
    Views = table_name
    , ColumnName = COLUMN_NAME
    , DataType = DATA_TYPE
FROM Information_Schema.columns AS Columns
WHERE TABLE_NAME LIKE N'v_%'
    AND TABLE_NAME NOT LIKE 'v_CM_RES_COLL_________'
    AND TABLE_SCHEMA = N'dbo'
    AND TABLE_CATALOG = @CM_DB
ORDER BY TABLE_NAME

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/