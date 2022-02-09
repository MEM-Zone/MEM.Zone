DECLARE @EmailsCSV AS NVARCHAR(MAX) = N''
DECLARE @Emails TABLE (ID INT IDENTITY(1,1), Email NVARCHAR(100))

INSERT INTO @Emails (Email)
SELECT LOWER(RTRIM(LTRIM(VALUE))) FROM STRING_SPLIT(@EmailsCSV, N',')

SELECT
    Email            = Emails.Email
    , UniqueUserName = ISNULL(Users.UniqueUserName, N'N/A')
FROM @Emails AS Emails
    OUTER APPLY (
        SELECT
            Email = Emails.Email
            , UniqueUserName = Users.Unique_User_Name0
        FROM v_R_User AS Users
        WHERE Emails.Email = Users.Mail0) AS Users
ORDER BY Users.UniqueUserName