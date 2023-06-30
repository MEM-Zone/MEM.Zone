DECLARE @CollectionID NVARCHAR(16)= '$CollectionID';
DECLARE @UserSIDs NVARCHAR(16)= 'Disabled';
SELECT
    Client_Version = Systems.Client_Version0
    , Count = COUNT(*)
FROM fn_rbac_R_System(@UserSIDs) AS SYS
    LEFT JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership ON CollectionMembership.ResourceID = Systems.ResourceID
WHERE Systems.Client0 = 1
    AND CollectionMembership.CollectionID = @CollectionID
GROUP BY
    Systems.Client_Version0
    , Systems.Client_Type0
ORDER BY
    Systems.Client_Version0
    , Systems.Client_Type0