SELECT *
FROM pg_timezone_names();


SELECT
    abbrev,
    COUNT(name) AS record_count
FROM pg_timezone_names()
GROUP BY abbrev
ORDER BY record_count DESC;