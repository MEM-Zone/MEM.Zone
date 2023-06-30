/*
.SYNOPSIS
    Checks if the IP is in the specified IP range.
.DESCRIPTION
    Checks if the IP is in the specified IP range and returns 1 or 0 (True/False).
.PARAMETER IP
    Specifies the IP.
.PARAMETER IPRange
    Specifies the IP range.
.EXAMPLE
    SELECT dbo.ufn_IsIPInRange('10.10.10.22', '10.10.10.0-10.10.10.254')
.NOTES
    Created by Ioan Popovici (2019-01-14)
    Replace the <CM_Your_Site_Code> with your CM or custom database name.
    Run the code in SQL Server Management Studio.
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

IF EXISTS (
    SELECT [OBJECT_ID]
    FROM   [SYS].[OBJECTS]
    WHERE  NAME = 'ufn_IsIPInRange'
)
    DROP FUNCTION [dbo].[ufn_IsIPInRange];
GO

CREATE FUNCTION [dbo].[ufn_IsIPInRange] (
    @IP        NVARCHAR(15)
    , @IPRange NVARCHAR(31)
)
RETURNS BIT
AS
    BEGIN

        /* Variable declaration */
        DECLARE @IPRangeStart           AS NVARCHAR(15);
        DECLARE @IPRangeEnd             AS NVARCHAR(15);
        DECLARE @IPToInteger            AS BIGINT;
        DECLARE @IPRangeStartToInteger  AS BIGINT;
        DECLARE @IPRangeEndToInteger    AS BIGINT;
        DECLARE @Result                 AS BIT;

        /* Set IP range start and range end */
        SET @IPRangeStart = (SELECT SUBSTRING(@IPRange, 1, PATINDEX('%-%', @IPRange) -1));
        SET @IPRangeEnd   = (SELECT SUBSTRING(@IPRange, PATINDEX('%-%', @IPRange) +1, LEN(@IPRange)));

        /* Convert IP to integer */
        SET @IPToInteger = (
            CONVERT(BIGINT, PARSENAME(@IP,1)) +
            CONVERT(BIGINT, PARSENAME(@IP,2)) * 256 +
            CONVERT(BIGINT, PARSENAME(@IP,3)) * 65536 +
            CONVERT(BIGINT, PARSENAME(@IP,4)) * 16777216
        );

        /* Convert IP range start to integer */
        SET @IPRangeStartToInteger = (
            CONVERT(BIGINT, PARSENAME(@IPRangeStart,1)) +
            CONVERT(BIGINT, PARSENAME(@IPRangeStart,2)) * 256 +
            CONVERT(BIGINT, PARSENAME(@IPRangeStart,3)) * 65536 +
            CONVERT(BIGINT, PARSENAME(@IPRangeStart,4)) * 16777216
        );

        /* Convert IP range end to integer */
        SET @IPRangeEndToInteger = (
            CONVERT(BIGINT, PARSENAME(@IPRangeEnd,1)) +
            CONVERT(BIGINT, PARSENAME(@IPRangeEnd,2)) * 256 +
            CONVERT(BIGINT, PARSENAME(@IPRangeEnd,3)) * 65536 +
            CONVERT(BIGINT, PARSENAME(@IPRangeEnd,4)) * 16777216
        );

        /* Calculate result */
        SET @Result = (
            CASE
                WHEN @IPToInteger BETWEEN @IPRangeStartToInteger AND @IPRangeEndToInteger
                THEN 1
                ELSE 0
            END
        )

        /* Return result */
        RETURN  @Result;
    END;
GO

/* Grants select rights for this function to SCCM reporting users */
GRANT SELECT ON OBJECT::ufn_IsIPInRange
    TO smsschm_users;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
