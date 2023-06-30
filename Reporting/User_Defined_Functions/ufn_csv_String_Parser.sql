/*
.SYNOPSIS
    Parses a CSV string.
.DESCRIPTION
    Parses a CSV string and returns individual substrings.
.PARAMETER pInputString
    Specifies the input string.
.PARAMETER pDelimiter
    Specifies the delimiter.
.EXAMPLE
    SELECT dbo.ufn_csv_String_Parser('Some String, Some String, ...')
.NOTES
    Created by Ioan Popovici (2015-08-18)
    All credit goes to Michelle Ufford for the original code. I only reformated it a bit.
    Replace the <CM_Your_Site_Code> with your CM or custom database name.
    Run the code in SQL Server Management Studio
.LINK
    http://sqlfool.com (Credit - Michelle Ufford)
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

USE [<CM_Your_Site_Code/Custom_Function_Database>]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

IF EXISTS
(
    SELECT [OBJECT_ID]
    FROM   [SYS].[OBJECTS]
    WHERE  NAME = 'ufn_csv_String_Parser'
)
    DROP FUNCTION [dbo].[ufn_csv_String_Parser];
GO

CREATE FUNCTION [dbo].[ufn_csv_String_Parser]
(
    @pInputString VARCHAR(8000)
,   @pDelimiter   CHAR(1)
)
RETURNS @tRET TABLE (StringValue VARCHAR(128))
AS
    BEGIN

        /* Variable declaration */
        DECLARE @pTrimmedInputString VARCHAR(8000);

        /* Trim string input */
        SET @pTrimmedInputString = LTRIM(RTRIM(@pInputString));

        /* Create a recursive CTE to break down the string */
        WITH ParseCTE (StartPos, EndPos)
        AS
        (
            SELECT 1 AS StartPos
                , CHARINDEX(@pDelimiter, @pTrimmedInputString + @pDelimiter) AS EndPos
            UNION ALL
            SELECT EndPos + 1 AS StartPos
                , CHARINDEX(@pDelimiter, @pTrimmedInputString + @pDelimiter , EndPos + 1) AS EndPos
            FROM ParseCTE
            WHERE CHARINDEX(@pDelimiter, @pTrimmedInputString + @pDelimiter, EndPos + 1) <> 0
        )

        /* Insert results into a table */
        INSERT INTO @tRET
        SELECT SUBSTRING(@pTrimmedInputString, StartPos, EndPos - StartPos)
        FROM ParseCTE
        WHERE LEN(LTRIM(RTRIM(SUBSTRING(@pTrimmedInputString, StartPos, EndPos - StartPos)))) > 0
        OPTION (MaxRecursion 8000);

        RETURN;
    END;
GO

/* Grants select rights for this function to SCCM reporting users */
GRANT SELECT ON OBJECT::dbo.ufn_csv_String_Parser
    TO smsschm_users;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
