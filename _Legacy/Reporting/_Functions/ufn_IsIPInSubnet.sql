/*
.SYNOPSIS
    Checks if the IP is in the specified subnet.
.DESCRIPTION
    Checks if the IP is in the specified subnet using the subnet mask.
    Returns 1 (True) or 0 (False).
.PARAMETER IP
    Specifies the IP to test.
.PARAMETER Subnet
    Specifies the subnet IP.
.PARAMETER SubnetMask
    Specifies the subnet mask IP in CIDR format.
    If you don't use CIDR the ufn_CIDRFromIPMask custom function is required.
.EXAMPLE
    SELECT dbo.ufn_IsIPInSubnet('10.10.10.22', '10.10.10.0', '/24')
.EXAMPLE
    SELECT dbo.ufn_IsIPInSubnet('10.10.10.22', '10.10.10.0', '24')
.EXAMPLE
    SELECT dbo.ufn_IsIPInSubnet('10.10.10.22', '10.10.10.0', '255.255.255.0') -- Requires the ufn_CIDRFromIPMask custom function.
.NOTES
    Created by Ioan Popovici (2018-12-12)
    Credit to Anthony Mattas. This is just a slightly modified version.
    Replace the <CM_Your_Site_Code> with your CM or custom database name.
    Run the code in SQL Server Management Studio.
.LINK
    http://www.anthonymattas.com
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
    WHERE  NAME = 'ufn_IsIPInSubnet'
)
    DROP FUNCTION [dbo].[ufn_IsIPInSubnet];
GO

CREATE FUNCTION [dbo].[ufn_IsIPInSubnet] (
    @IP           AS VARCHAR(15)
    , @Subnet     AS VARCHAR(15)
    , @SubnetMask AS VARCHAR(15)
)
RETURNS BIT
AS
BEGIN

    /* Variable declaration */
    DECLARE @IPBinary     AS BINARY(4);
    DECLARE @SubnetBinary AS BINARY(4);
    DECLARE @SubnetCIDR   AS TINYINT;
    DECLARE @Result       AS BIT;

    /* Convert IP to Binary */
    SET @IPBinary    = (
        CAST(CAST(PARSENAME(@IP, 4) AS INTEGER) AS BINARY(1)) +
        CAST(CAST(PARSENAME(@IP, 3) AS INTEGER) AS BINARY(1)) +
        CAST(CAST(PARSENAME(@IP, 2) AS INTEGER) AS BINARY(1)) +
        CAST(CAST(PARSENAME(@IP, 1) AS INTEGER) AS BINARY(1))
    )

    /* Convert IPSubnet to Binary */
    SET @SubnetBinary = (
        CAST(CAST(PARSENAME(@Subnet, 4) AS INTEGER) AS BINARY(1)) +
        CAST(CAST(PARSENAME(@Subnet, 3) AS INTEGER) AS BINARY(1)) +
        CAST(CAST(PARSENAME(@Subnet, 2) AS INTEGER) AS BINARY(1)) +
        CAST(CAST(PARSENAME(@Subnet, 1) AS INTEGER) AS BINARY(1))
    )

    /* Convert IPSubnet to CIDR and remove '/' if needed */
    IF LEN(@SubnetMask) > 4
        /* Support function */
        SET @SubnetCIDR = REPLACE(CM_Tools.dbo.ufn_CIDRFromIPMask(@SubnetMask), '/','')
    ELSE
        SET @SubnetCIDR = REPLACE(@SubnetMask, '/', '')

    /* Calculate result */
    SET @Result       = (
        CASE
            WHEN (
                SELECT (CAST(@IPBinary AS INTEGER) ^ CAST(@SubnetBinary AS INTEGER))
                & ~ -- Bitwise (AND NOT)
                (POWER(2, 32 - @SubnetCIDR) - 1)
            ) = 0
            THEN 1
            ELSE 0
        END
    )

    /* Return result */
    RETURN @Result;
END;
GO

/* Grants select rights for this function to SCCM reporting users */
GRANT SELECT ON OBJECT::dbo.ufn_IsIPInSubnet
    TO smsschm_users;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/