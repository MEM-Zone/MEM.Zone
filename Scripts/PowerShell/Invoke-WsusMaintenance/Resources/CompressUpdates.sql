/*
.SYNOPSIS
    Compresses WSUS Update Revisions.
.DESCRIPTION
    Compresses WSUS Update Revisions and returns the number of compressed updates.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately.
.LINK
    https://MEMZ.one/WsusMaintenance
.LINK
    https://MEMZ.one/WsusMaintenance-GIT
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Set Database */
USE [SUSDB];

/* Stops the message that shows the count of the number of rows affected from being returned as part of the result set. */
SET NOCOUNT ON

/* Variable declaration */
DECLARE @NumberOfUpdatesToCompress AS INT;
DECLARE @CurrentUpdateID AS INT;
DECLARE @Counter AS INT = 1;
DECLARE @StartTime AS DATETIME;
DECLARE @EndTime AS DATETIME;

/* Initialize memory tables */
DECLARE @LocalUpdateIDs TABLE(ID INT IDENTITY(1,1), LocalUpdateID INT);
DECLARE @Output TABLE(UpdateID INT, StartTime NVARCHAR(19), EndTime NVARCHAR(MAX), ExecutionTime NVARCHAR(MAX));

/* Populate ReasonsForNonCompliance table */
INSERT INTO @LocalUpdateIDs (LocalUpdateID)
EXEC spGetUpdatesToCompress

/* Get the number of updates to be compressed */
SET @NumberOfUpdatesToCompress = (SELECT COUNT(*) FROM @LocalUpdateIDs)

/* Compress Updates */
WHILE @Counter < @NumberOfUpdatesToCompress
BEGIN
    BEGIN TRAN
        SET @CurrentUpdateID = (SELECT LocalUpdateID FROM @LocalUpdateIDs WHERE ID = @Counter)
        SET @StartTime = GETDATE()
        EXEC spCompressUpdate @localUpdateID = @CurrentUpdateID
        SET @EndTime = GETDATE()
        INSERT INTO @Output (UpdateID, StartTime, EndTime, ExecutionTime)
        OUTPUT INSERTED.UpdateID, INSERTED.StartTime, INSERTED.EndTime, INSERTED.ExecutionTime
        VALUES (
            @CurrentUpdateID
            , CONVERT(NVARCHAR(19), @StartTime, 120)
            , CONVERT(NVARCHAR(19), @EndTime, 120)
            , CONVERT(NVARCHAR, DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, @StartTime, @EndTime), 0), 114 )
        )
        SET @Counter = @Counter + 1
    COMMIT
END

/* Return 0 if there are no updates to compress */
IF (SELECT COUNT(*) FROM @Output) = 0 SELECT 0

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/