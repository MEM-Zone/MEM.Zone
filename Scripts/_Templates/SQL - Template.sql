/*
.SYNOPSIS
    Summarizes the compliance for .
.DESCRIPTION
    Summarizes the compliance for .
.NOTES
    Requires SQL 2019.
    Part of a report should not be run separately.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Variable declaration */
DECLARE @CollectionID AS NVARCHAR(10)  = N'';

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#Results', N'U') IS NOT NULL
    DROP TABLE #Results;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/