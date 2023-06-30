/*
.SYNOPSIS
    Gets the CIDR from a IP Subnet Mask.
.DESCRIPTION
    Gets the CIDR ('/') from a IP Subnet Mask.
.PARAMETER IPSubnetMask
    Specifies the IP subnet mask.
.EXAMPLE
    SELECT dbo.ufn_CIDRFromIPMask('255.255.255.0')
.NOTES
    Created by Ioan Popovici (2018-12-11)
    Credit to Chris O'Connor
    Replace the <CM_Your_Site_Code> with your CM or custom database name.
    Run the code in SQL Server Management Studio.
.LINK
    https://clouddeveloper.space/2015/07/14/sql-inet_aton-ip-address-cidr/ (Chris o'Connor)
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
    WHERE  NAME = 'ufn_CIDRFromIPMask'
)
    DROP FUNCTION [dbo].[ufn_CIDRFromIPMask];
GO

CREATE FUNCTION [dbo].[ufn_CIDRFromIPMask] (
    @IPSubnetMask VARCHAR(15)
)
RETURNS VARCHAR(4)
AS
    BEGIN

        /* Variable declaration */
        DECLARE @IPSubnetMaskToInteger AS BIGINT;
        DECLARE @IPDefaultSubnetMaskToInteger AS BIGINT;
        DECLARE @MaskCalc AS BIGINT;
        DECLARE @LogarithmCacl AS INT;
        DECLARE @Result AS VARCHAR(4);

        /* Convert IP subnet mask to integer */
        SET @IPSubnetMaskToInteger        = (
            CONVERT(BIGINT, PARSENAME(@IPSubnetMask,1)) +
            CONVERT(BIGINT, PARSENAME(@IPSubnetMask,2)) * 256 +
            CONVERT(BIGINT, PARSENAME(@IPSubnetMask,3)) * 65536 +
            CONVERT(BIGINT, PARSENAME(@IPSubnetMask,4)) * 16777216
        );

        /* Convert default IP subnet mask (255.255.255.255) to integer */
        SET @IPDefaultSubnetMaskToInteger = (
            CONVERT(BIGINT, 255) +
            CONVERT(BIGINT, 255) * 256 +
            CONVERT(BIGINT, 255) * 65536 +
            CONVERT(BIGINT, 255) * 16777216
        );

        /* Calculate mask */
        SET @MaskCalc                     = (@IPDefaultSubnetMaskToInteger - @IPSubnetMaskToInteger + 1);
        SET @LogarithmCacl                = (32 - LOG (@MaskCalc, 2));

        /* Calculate result */
        SET @Result = '/' + CAST(@LogarithmCacl AS VARCHAR(5));

        /* Return result */
        RETURN  @Result;
    END;
GO

/* Grants select rights for this function to SCCM reporting users */
GRANT SELECT ON OBJECT::dbo.ufn_CIDRFromIPMask
    TO smsschm_users;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
