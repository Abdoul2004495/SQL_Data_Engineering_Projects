SELECT COUNT(*) AS remote_rows
FROM work_mode_mart.remote_jobs
UNION
SELECT COUNT(*) AS remote_rows
FROM work_mode_mart.not_remote_jobs
ORDER BY job_work_from_home;


SELECT
    r.job_title,
    r.company_id,
    r.job_location
FROM work_mode_mart.remote_jobs AS r
UNION
SELECT
    r.job_title,
    r.company_id,
    r.job_location
FROM work_mode_mart.not_remote_jobs AS r
ORDER BY
    r.job_title,
    r.company_id,
    r.job_location;