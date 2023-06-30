SELECT CI_ID,
       title
FROM v_AuthListInfo

-- Naming Filtering if you want it
WHERE title LIKE '%required%'
    AND title NOT LIKE '%office%'
