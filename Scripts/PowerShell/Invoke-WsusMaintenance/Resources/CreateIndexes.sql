 /*
.SYNOPSIS
    Creates WSUS Indexes.
.DESCRIPTION
    Creates WSUS Indexes to improve performance if they don't exist.
.NOTES
    Requires SQL 2016.
    Created by Microsoft
.LINK
    https://MEMZ.one/WsusMaintenance
.LINK
    https://MEMZ.one/WsusMaintenance-GIT
.LINK
    https://MEM.Zone/ISSUES
.LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/spdeleteupdate-slow-performance
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

USE [SUSDB];

IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_tbRevisionSupersedesUpdate')
    PRINT 'Index [IX_tbRevisionSupersedesUpdate] already exists.'
ELSE
    CREATE NONCLUSTERED INDEX [IX_tbRevisionSupersedesUpdate] ON [dbo].[tbRevisionSupersedesUpdate]([SupersededUpdateID]);
IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_tbLocalizedPropertyForRevision')
    PRINT 'Index [IX_tbLocalizedPropertyForRevision] already exists.'
ELSE
    CREATE NONCLUSTERED INDEX [IX_tbLocalizedPropertyForRevision] ON [dbo].tbLocalizedPropertyForRevision([LocalizedPropertyID]);

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
