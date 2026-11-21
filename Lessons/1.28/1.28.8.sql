SELECT
    r.job_title,
    r.company_id,
    r.job_location
FROM work_mode_mart.remote_jobs AS r
EXCEPT ALL
SELECT
    r.job_title,
    r.company_id,
    r.job_location
FROM work_mode_mart.not_remote_jobs AS r
ORDER BY
    r.job_title,
    r.company_id,
    r.job_location;