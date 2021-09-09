SELECT
    ResourceID
    , CreationDate    = LocalGroupMemebers.TimeStamp
    , UserAccount     = LocalGroupMemebers.Account0
    , SIDBinary       = UserAccountSID.BinarySID
    , SIDReadable     = UserAccountSID.ReadableSID
FROM v_GS_CM_LOCALGROUPMEMBERS AS LocalGroupMemebers
    OUTER APPLY (
        SELECT
            BinarySID
            , ReadableSID
        FROM dbo.ufn_GetUserAccountSID(LocalGroupMemebers.Account0, DEFAULT)
    ) AS UserAccountSID
WHERE LocalGroupMemebers.Type0 = 'Domain'
    AND LocalGroupMemebers.Category0 = 'UserAccount'