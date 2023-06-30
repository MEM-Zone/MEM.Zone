/*
.SYNOPSIS
    Gets the next maintenance window from a schedule token.
.DESCRIPTION
    Gets the next maintenance window from a schedule token.
.PARAMETER ScheduleToken
    Specifies the schedule token.
.PARAMETER RecurrenceType
    Specifies the maintenance window recurrence type.
.EXAMPLE
    SELECT dbo.ufn_CM_GetNextMaintenanceWindow('00811A9E081A2000', 3)
.NOTES
    Created by Ioan Popovici
    All credit goes to Adam Weigert and Ed Price for the original code. I only reformated it a bit.
    Requires SELECT access on dbo.vSMS_ServiceWindow and on itself for smsschm_users (SCCM Reporting).
    Replace the <SITE_CODE> with your CM Site Code.
    Run the code in SQL Server Management Studio.
.LINK
    https://social.technet.microsoft.com/wiki/contents/articles/7870.sccm-2007-create-report-of-upcoming-maintenance-windows-by-client.aspx (Adam Weigert)
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

USE [CM_<SITE_CODE>]
GO

SET NOCOUNT ON
GO

/* Drop function if it exists */
IF OBJECT_ID('[dbo].[ufn_CM_GetNextMaintenanceWindow]') IS NOT NULL
    BEGIN
        DROP FUNCTION [dbo].[ufn_CM_GetNextMaintenanceWindow]
    END
GO

CREATE FUNCTION [dbo].[ufn_CM_GetNextMaintenanceWindow](
    @ScheduleToken      AS CHAR(16)
    , @RecurrenceType   AS INT
)
RETURNS @NextServiceWindow TABLE (
    ScheduleToken       CHAR(16)
    , RecurrenceType    INT
    , NextServiceWindow DATETIME
    , Duration          INT
    , IsGMTTime         BIT
)
AS
    BEGIN

        --1 Occurs on 1/1/2012 12:00 AM 00011A8500080000
        --2 Occurs every 3 day(s) effective 1/1/2012 8:00 PM    02811A8040100018
        --3 Occurs every 3 week(s) on Saturday effective 1/1/2012 8:00 PM   02811A80401F6000
        --3 Occurs every 1 week(s) on Saturday effective 1/1/2012 8:00 PM   02811A80401F2000
        --5 Occurs day 2 of every 2 month(s) effective 1/1/2012 8:00 PM 02811A8040288800
        --5 Occurs day 31 of every 1 month(s) effective 1/1/2012 8:00 PM    02811A80402FC400
        --5 Occurs the last day of every 3 months effective 1/1/2012 8:00 PM    02811A8040280C00
        --5 Occurs the last day of every 1 months effective 1/1/2012 8:00 PM    02811A8040280400
        --4 Occurs the Third Monday of every 1 month(s) effective 1/1/2012 4:00 AM  00811A9E08221600
        --4 Occurs the Last Wednesday of every 1 month(s) effective 1/1/2012 8:00 PM    02811A8040241000
        --4 Occurs the Fourth Wednesday of every 1 month(s) effective 1/1/2012 8:00 PM  02811A8040241800
        --4 Occurs the Last Monday of every 1 month(s) effective 1/1/2012 8:00 PM   02811A8040221000
        --3 Occurs every 1 week(s) on Monday effective 1/1/2012 4:00 AM 00811A9E081A2000

        -- http://msdn.microsoft.com/en-us/library/cc143300.aspx Jump
        DECLARE @RecurrenceType_NONE INT
            , @RecurrenceType_DAILY INT
            , @RecurrenceType_WEEKLY INT
            , @RecurrenceType_MONTHLYBYWEEKDAY INT
            , @RecurrenceType_MONTHLYBYDATE INT

        SELECT @RecurrenceType_NONE = 1
            , @RecurrenceType_DAILY = 2
            , @RecurrenceType_WEEKLY = 3
            , @RecurrenceType_MONTHLYBYWEEKDAY = 4
            , @RecurrenceType_MONTHLYBYDATE = 5

        -- http://msdn.microsoft.com/en-us/library/cc143505.aspx Jump

        --DECLARE @RecurrenceType   INT;      SET @RecurrenceType   = @RecurrenceType_WEEKLY
        --DECLARE @ScheduleToken     CHAR(16); SET @ScheduleToken     = '00811A9E081A2000'
        DECLARE @ScheduleStartTime INT;      SET @ScheduleStartTime = CAST(CONVERT(BINARY(4), LEFT(@ScheduleToken, 8), 2) AS INT)
        DECLARE @ScheduleDuration  BIGINT;   SET @ScheduleDuration  = CAST(CONVERT(BINARY(4), RIGHT(@ScheduleToken, 8), 2) AS INT)

        -- Duration is in minutes
        DECLARE @Duration INT; SET @Duration = @ScheduleStartTime % POWER(2, 6)

        -- Calculate the start time
        DECLARE @StartTime DATETIME; SET @StartTime = CONVERT(DATETIME, '01/01/1970 00:00:00')
        SET @StartTime = DATEADD(YEAR, (@ScheduleStartTime / POWER(2,6)) % POWER(2, 6), @StartTime)
        SET @StartTime = DATEADD(MONTH, ((@ScheduleStartTime / POWER(2,12)) % POWER(2, 4)) - 1, @StartTime)
        SET @StartTime = DATEADD(DAY, ((@ScheduleStartTime / POWER(2,16)) % POWER(2, 5)) - 1, @StartTime)
        SET @StartTime = DATEADD(HOUR, (@ScheduleStartTime / POWER(2,21)) % POWER(2, 5), @StartTime)
        SET @StartTime = DATEADD(MINUTE, (@ScheduleStartTime / POWER(2,26)) % POWER(2, 5), @StartTime)

        -- Determinte UTC and Flags
        DECLARE @IsGMTTime     BIT; SET @IsGMTTime     = CAST(@ScheduleDuration % POWER(2, 1) AS BIT)
        DECLARE @Flags         INT; SET @Flags         = (@ScheduleDuration / POWER(2,19)) % POWER(2, 3)

        -- Calculate the total duration in minutes
        SET @Duration = @Duration + ((@ScheduleDuration / POWER(2,22)) % POWER(2, 5)) * 24 * 60 -- DAYS
        SET @Duration = @Duration + ((@ScheduleDuration / POWER(2,27)) % POWER(2, 5)) * 60      -- HOURS

        DECLARE @Now DATETIME

        IF @IsGMTTime = 1 BEGIN
            SET @Now = GETUTCDATE()
        END ELSE BEGIN
            SET @Now = GETDATE()
        END

        DECLARE @NextMaintenanceWindow DATETIME

        IF @RecurrenceType = @RecurrenceType_NONE BEGIN
            IF DATEADD(MINUTE, @Duration, @StartTime) > @Now BEGIN
                SET @NextMaintenanceWindow = @StartTime
            END
        END ELSE IF @RecurrenceType = @RecurrenceType_DAILY BEGIN
            IF DATEADD(MINUTE, @Duration, @StartTime) > @Now BEGIN
                SET @NextMaintenanceWindow = @StartTime
            END ELSE BEGIN
                -- Calculate the daily interval in minutes
                DECLARE @DailyInterval INT

                SET @DailyInterval = ((@ScheduleDuration / POWER(2,3)) % POWER(2, 5)) * 24 * 60
                SET @DailyInterval = @DailyInterval + ((@ScheduleDuration / POWER(2,8)) % POWER(2, 5)) * 60
                SET @DailyInterval = @DailyInterval + (@ScheduleDuration / POWER(2,13)) % POWER(2, 6)

                -- Calculate the total number of completed intervals
                DECLARE @DailyNumberOfCompletedIntervals INT; SET @DailyNumberOfCompletedIntervals = ROUND(CAST(DATEDIFF(MINUTE, @StartTime, @Now) AS DECIMAL) / @DailyInterval, 0, 0)

                -- Calculate the next interval
                DECLARE @DailyNextInterval DATETIME; SET @DailyNextInterval = DATEADD(MINUTE, @DailyNumberOfCompletedIntervals * @DailyInterval, @StartTime)

                -- Recalc the next interval if the next interval plus the expected duration is in the past
                IF DATEADD(MINUTE, @Duration, @DailyNextInterval) < @Now BEGIN
                    SET @DailyNextInterval = DATEADD(MINUTE, (@DailyNumberOfCompletedIntervals + 1) * @DailyInterval, @StartTime)
                END

                SET @NextMaintenanceWindow = @DailyNextInterval
            END
        END ELSE IF @RecurrenceType = @RecurrenceType_WEEKLY BEGIN
            DECLARE @WeeklyInterval INT; SET @WeeklyInterval = (@ScheduleDuration / POWER(2,13)) % POWER(2, 3)
            DECLARE @WeeklyDoW      INT; SET @WeeklyDoW      = (@ScheduleDuration / POWER(2,16)) % POWER(2, 3)

            -- Adjust the start time to match the next day of week that matches the interval
            DECLARE @WeeklyStartTime DATETIME; SET @WeeklyStartTime = DATEADD(DAY, (7 - DATEPART(WEEKDAY, @StartTime) + @WeeklyDoW % 7), @StartTime)

            IF DATEADD(MINUTE, @Duration, @WeeklyStartTime) > @Now BEGIN
                SET @NextMaintenanceWindow = @WeeklyStartTime
            END ELSE BEGIN
                -- Calculate the total number of completed intervals
                DECLARE @WeeklyNumberOfCompletedIntervals INT; SET @WeeklyNumberOfCompletedIntervals = ROUND(CAST(DATEDIFF(WEEK, @WeeklyStartTime, @Now) AS DECIMAL) / @WeeklyInterval, 0, 0)

                -- Calculate the next interval
                DECLARE @WeeklyNextInterval DATETIME; SET @WeeklyNextInterval = DATEADD(WEEK, @WeeklyNumberOfCompletedIntervals * @WeeklyInterval, @WeeklyStartTime)

                -- Recalc the next interval if the next interval plus the expected duration is in the past
                IF DATEADD(MINUTE, @Duration, @WeeklyNextInterval) < @Now BEGIN
                    SET @WeeklyNextInterval = DATEADD(WEEK, (@WeeklyNumberOfCompletedIntervals + 1) * @WeeklyInterval, @WeeklyStartTime)
                END

                SET @NextMaintenanceWindow = @WeeklyNextInterval
            END
        END ELSE IF @RecurrenceType = @RecurrenceType_MONTHLYBYWEEKDAY BEGIN
            DECLARE @MonthlyBWWeek     INT; SET @MonthlyBWWeek     = (@ScheduleDuration / POWER(2,9)) % POWER(2, 3)
            DECLARE @MontlhyBWInterval INT; SET @MontlhyBWInterval = (@ScheduleDuration / POWER(2,12)) % POWER(2, 4)
            DECLARE @MonthlyBWDoW      INT; SET @MonthlyBWDoW      = (@ScheduleDuration / POWER(2,16)) % POWER(2, 3)

            -- Calculate the total number of completed intervals
            DECLARE @MonthlyBWNumberOfCompletedIntervals INT; SET @MonthlyBWNumberOfCompletedIntervals = ROUND(CAST(DATEDIFF(MONTH, @StartTime, @Now) AS DECIMAL) / @MontlhyBWInterval, 0, 0)

            IF @MonthlyBWWeek = 0 BEGIN
                -- Calculate the next interval
                DECLARE @MonthlyBWLDOMNextInterval DATETIME; SET @MonthlyBWLDOMNextInterval = DATEADD(MONTH, @MonthlyBWNumberOfCompletedIntervals * @MontlhyBWInterval, @StartTime)

                -- Calculate last day of month
                SET @MonthlyBWLDOMNextInterval = DATEADD(DAY, DATEDIFF(DAY, @MonthlyBWLDOMNextInterval, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(MONTH, 0, @MonthlyBWLDOMNextInterval) + 1, 0))), @MonthlyBWLDOMNextInterval)

                -- Calculate the last day of the week for the month
                SET @MonthlyBWLDOMNextInterval = DATEADD(DAY, -(7 - DATEPART(WEEKDAY, @MonthlyBWLDOMNextInterval) + @MonthlyBWDoW % 7), @MonthlyBWLDOMNextInterval)

                IF DATEADD(MINUTE, @Duration, @MonthlyBWLDOMNextInterval) < @Now BEGIN
                    -- Recalc for the next month interval
                    SET @MonthlyBWLDOMNextInterval = DATEADD(MONTH, (@MonthlyBWNumberOfCompletedIntervals + 1) * @MontlhyBWInterval, @StartTime)

                    -- Calculate last day of month
                    SET @MonthlyBWLDOMNextInterval = DATEADD(DAY, DATEDIFF(DAY, @MonthlyBWLDOMNextInterval, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(MONTH, 0, @MonthlyBWLDOMNextInterval) + 1, 0))), @MonthlyBWLDOMNextInterval)

                    -- Calculate the last day of the week for the month
                    SET @MonthlyBWLDOMNextInterval = DATEADD(DAY, -(7 - DATEPART(WEEKDAY, @MonthlyBWLDOMNextInterval) + @MonthlyBWDoW % 7), @MonthlyBWLDOMNextInterval)
                END

                SET @NextMaintenanceWindow = @MonthlyBWLDOMNextInterval
            END ELSE BEGIN
                -- Calculate the next interval
                DECLARE @MonthlyBWNextInterval DATETIME; SET @MonthlyBWNextInterval = DATEADD(MONTH, @MonthlyBWNumberOfCompletedIntervals * @MontlhyBWInterval, @StartTime)

                -- Set the date to the first day of the month
                SET @MonthlyBWNextInterval = DATEADD(DAY, -(DAY(@MonthlyBWNextInterval) - 1), @MonthlyBWNextInterval)

                -- Set the date to the first day of week in the month
                SET @MonthlyBWNextInterval = DATEADD(DAY, (7 - DATEPART(WEEKDAY, @MonthlyBWNextInterval) + @MonthlyBWDoW) % 7, @MonthlyBWNextInterval)

                -- Calculate date based on the week number to add
                SET @MonthlyBWNextInterval = DATEADD(WEEK, @MonthlyBWWeek-1, @MonthlyBWNextInterval)

                IF DATEADD(MINUTE, @Duration, @MonthlyBWNextInterval) < @Now BEGIN
                    -- Recalc for the next month interval
                    SET @MonthlyBWNextInterval = DATEADD(MONTH, (@MonthlyBWNumberOfCompletedIntervals + 1) * @MontlhyBWInterval, @StartTime)

                    -- Set the date to the first day of the month
                    SET @MonthlyBWNextInterval = DATEADD(DAY, -(DAY(@MonthlyBWNextInterval) - 1), @MonthlyBWNextInterval)

                    -- Set the date to the first day of week in the month
                    SET @MonthlyBWNextInterval = DATEADD(DAY, (7 - DATEPART(WEEKDAY, @MonthlyBWNextInterval) + @MonthlyBWDoW % 7), @MonthlyBWNextInterval)

                    -- Calculate date based on the week number to add
                    SET @MonthlyBWNextInterval = DATEADD(WEEK, @MonthlyBWWeek-1, @MonthlyBWNextInterval)
                END

                SET @NextMaintenanceWindow = @MonthlyBWNextInterval
            END
        END ELSE IF @RecurrenceType = @RecurrenceType_MONTHLYBYDATE BEGIN
            DECLARE @MontlhyBDInterval INT; SET @MontlhyBDInterval = (@ScheduleDuration / POWER(2,10)) % POWER(2, 4)
            DECLARE @MonthlyBDDoM      INT; SET @MonthlyBDDoM      = (@ScheduleDuration / POWER(2,14)) % POWER(2, 5)

            IF @MonthlyBDDoM = 0 BEGIN
                /* This is the last day of month logic */

                -- Calculate the total number of completed intervals
                DECLARE @MonthlyBDLDOMNumberOfCompletedIntervals INT; SET @MonthlyBDLDOMNumberOfCompletedIntervals = ROUND(CAST(DATEDIFF(MONTH, @StartTime, @Now) AS DECIMAL) / @MontlhyBDInterval, 0, 0)

                -- Calculate the next interval
                DECLARE @MonthlyBDLDOMNextInterval DATETIME; SET @MonthlyBDLDOMNextInterval = DATEADD(MONTH, @MonthlyBDLDOMNumberOfCompletedIntervals * @MontlhyBDInterval, @StartTime)

                -- Calculate last day of month
                SET @MonthlyBDLDOMNextInterval = DATEADD(DAY, DATEDIFF(DAY, @MonthlyBDLDOMNextInterval, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(MONTH, 0, @MonthlyBDLDOMNextInterval) + 1, 0))), @MonthlyBDLDOMNextInterval)

                -- Recalc the next interval if the next interval plus the expected duration is in the past
                IF DATEADD(MINUTE, @Duration, @MonthlyBDLDOMNextInterval) < @Now BEGIN
                    SET @MonthlyBDLDOMNextInterval = DATEADD(DAY, DATEDIFF(DAY, @MonthlyBDLDOMNextInterval, DATEADD(DAY, -1, DATEADD(M, DATEDIFF(MONTH, 0, DATEADD(MONTH, (@MonthlyBDLDOMNumberOfCompletedIntervals + 1) * @MontlhyBDInterval, @StartTime)) + 1, 0))), @MonthlyBDLDOMNextInterval)
                END

                SET @NextMaintenanceWindow = @MonthlyBDLDOMNextInterval
            END ELSE BEGIN
                -- Check to make sure we won't loop forever if more than 31 days some how ends up in the token
                IF @MonthlyBDDoM > 31 SET @MonthlyBDDoM = 31

                -- Adjust the start time to match the next day of month that matches the interval
                DECLARE @MonthlyBDStartTime DATETIME; SET @MonthlyBDStartTime = DATEADD(DAY, (31 - DATEPART(DAY, @StartTime) + @MonthlyBDDoM % 31), @StartTime)

                -- This loop is used multiple times to search for the next valid date that falls on the desired day of month
                WHILE(DATEPART(DAY, @MonthlyBDStartTime) <> @MonthlyBDDoM) BEGIN
                    SET @MonthlyBDStartTime = DATEADD(DAY, (31 - DATEPART(DAY, @MonthlyBDStartTime) + @MonthlyBDDoM) % 31, @MonthlyBDStartTime)
                END

                IF DATEADD(MINUTE, @Duration, @MonthlyBDStartTime) > @Now BEGIN
                    SET @NextMaintenanceWindow = @MonthlyBDStartTime
                END ELSE BEGIN
                    -- Calculate the total number of completed intervals
                    DECLARE @MonthlyBDNumberOfCompletedIntervals INT; SET @MonthlyBDNumberOfCompletedIntervals = ROUND(CAST(DATEDIFF(MONTH, @MonthlyBDStartTime, @Now) AS DECIMAL) / @MontlhyBDInterval, 0, 0)

                    -- Calculate the next interval
                    DECLARE @MonthlyBDNextInterval DATETIME; SET @MonthlyBDNextInterval = DATEADD(MONTH, @MonthlyBDNumberOfCompletedIntervals * @MontlhyBDInterval, @MonthlyBDStartTime)

                    WHILE(DATEPART(DAY, @MonthlyBDNextInterval) <> @MonthlyBDDoM) BEGIN
                        SET @MonthlyBDNextInterval = DATEADD(DAY, (31 - DATEPART(DAY, @MonthlyBDNextInterval) + @MonthlyBDDoM % 31), @MonthlyBDNextInterval)
                    END

                    -- Recalc the next interval if the next interval plus the expected duration is in the past
                    IF DATEADD(MINUTE, @Duration, @MonthlyBDNextInterval) < @Now BEGIN
                        SET @MonthlyBDNextInterval = DATEADD(MONTH, (@MonthlyBDNumberOfCompletedIntervals + 1) * @MontlhyBDInterval, @MonthlyBDNextInterval)

                        WHILE(DATEPART(DAY, @MonthlyBDNextInterval) <> @MonthlyBDDoM) BEGIN
                            SET @MonthlyBDNextInterval = DATEADD(DAY, (31 - DATEPART(DAY, @MonthlyBDNextInterval) + @MonthlyBDDoM % 31), @MonthlyBDNextInterval)
                        END
                    END

                    SET @NextMaintenanceWindow = @MonthlyBDNextInterval
                END
            END
        END

        /* Create result table */
        INSERT INTO @NextServiceWindow VALUES (@ScheduleToken, @RecurrenceType, @NextMaintenanceWindow, @Duration, @IsGMTTime)

        /* Return result */
        RETURN
    END
GO

/* Grant select rights for this function to CM reporting users */
GRANT SELECT ON OBJECT::dbo.ufn_CM_GetNextMaintenanceWindow TO smsschm_users;
GO

/* Grant select right for the fnListAlerts function to CM reporting users */
GRANT SELECT ON OBJECT::dbo.fnListAlerts TO smsschm_users;
GO

/* Grant select right for the vSMS_ServiceWindow view to CM reporting users */
GRANT SELECT ON OBJECT::dbo.vSMS_ServiceWindow TO smsschm_users;
GO

/* Grant select right for the vSMS_SUPSyncStatus view to CM reporting users */
GRANT SELECT ON OBJECT::dbo.vSMS_SUPSyncStatus TO smsschm_users;
GO

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/