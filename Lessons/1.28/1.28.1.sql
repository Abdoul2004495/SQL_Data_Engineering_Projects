CREATE SCHEMA work_mode_mart;

CREATE TABLE work_mode_mart.remote_jobs AS
SELECT
    j.job_title,
    j.company_id,
    j.job_location
FROM data_jobs.job_postings_fact AS j
WHERE j.job_work_from_home = TRUE AND job_location = 'Anywhere';

SELECT COUNT(*) AS remote_rows
FROM work_mode_mart.remote_jobs;