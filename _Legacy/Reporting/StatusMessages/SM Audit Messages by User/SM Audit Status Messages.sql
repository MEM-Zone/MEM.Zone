/*
*********************************************************************************************************
* Requires          | SQL, Cofiguration Manager DB, Custom Table containig message strings from CM DLL  *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2018-05-30 | v1.0     | First version                                             *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    This SQL Query is used to get SCCM Audit Status Messages.
.DESCRIPTION
    This SQL Query is used to get SCCM Audit Status Messages by User or Status Mesage substring.
.NOTES
    Part of a report should not be run separately.
    This query requires to export status messages strings from sms provider DLL.
    Status Messages are deleted after 6 months so you might have an empty result if the object was not modified recently.
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* For testing only */
-- DECLARE @UserSIDs VARCHAR(16) = 'Disabled';

/* Remove previous temporary table if exists */
IF OBJECT_ID(N'TempDB.DBO.#UserStatusMessages') IS NOT NULL
    BEGIN
        DROP TABLE #UserStatusMessages;
    END;

/* Get audit status messages */
SELECT

    -- You need to import the status message strings from the DLLs for this select to work
    (SELECT
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            SMSProviderMessages.MessageString,
            '%1', (SELECT COALESCE(MessageDetail.InsStrValue1,''))),  -- Replace fails on NULL value that's why COALESCE is used
            '%2', (SELECT COALESCE(MessageDetail.InsStrValue2,''))),
            '%3', (SELECT COALESCE(MessageDetail.InsStrValue3,''))),
            '%4', (SELECT COALESCE(MessageDetail.InsStrValue4,''))),
            '%5', (SELECT COALESCE(MessageDetail.InsStrValue5,''))),
            '%6', (SELECT COALESCE(MessageDetail.InsStrValue6,''))),
            '%7', (SELECT COALESCE(MessageDetail.InsStrValue7,''))),
            '%8', (SELECT COALESCE(MessageDetail.InsStrValue8,''))),
            '%9', (SELECT COALESCE(MessageDetail.InsStrValue9,''))),
            '%10', (SELECT COALESCE(MessageDetail.InsStrValue10,''))),
            ' .',''),		-- Remove ' .' at the end of the string.
            CHAR(10),''),	-- Remove LF
            CHAR(13),''     -- Remove CR
        )
    ) AS StatusMessage,
    MessageDetail.RecordID,
    MessageDetail.TimeStamp,
    MessageDetail.MessageID,
    MessageAttributes.AttributeValue AS UserName,
    MessageDetail.System AS DeviceName,
    MessageDetail.SiteCode,
    MessageDetail.Component
INTO #UserStatusMessages
FROM fn_rbac_Report_StatusMessageDetail(@UserSIDs) AS MessageDetail
    JOIN fn_rbac_StatMsgAttributes(@UserSIDs) AS MessageAttributes ON MessageDetail.RecordID = MessageAttributes.RecordID
    JOIN fn_rbac_StatMsgModuleNames(@UserSIDs) AS ModuleNames ON MessageDetail.MsgDllName = ModuleNames.MsgDllName

    -- You need to import the status message strings from the DLLs for this join to work
    JOIN CM_Tools.dbo.SMSProvMsgs AS SMSProviderMessages ON MessageDetail.MessageID = SMSProviderMessages.MessageID
WHERE
    MessageDetail.MessageTypeString = 'Audit' --Only Audit messages
    AND AttributeID = 403 --Users only
    AND AttributeValue LIKE @UserName

/* Filter by Substring */
SELECT DISTINCT
    StatusMessage,
    RecordID,
    TimeStamp,
    MessageID,
    UserName,
    DeviceName,
    SiteCode,
    Component
FROM #UserStatusMessages
WHERE StatusMessage LIKE '%' + @Substring + '%'
ORDER BY TimeStamp DESC;

/* Remove temporary table */
DROP TABLE #UserStatusMessages;

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/