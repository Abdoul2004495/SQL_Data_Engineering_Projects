USE company_jobs;

CREATE OR REPLACE VIEW remote_jobs_view AS
SELECT
    jpf.job_id,
    jpf.job_title_short,
    cd.name AS company_name
FROM data_jobs.job_postings_fact AS jpf
INNER JOIN data_jobs.company_dim AS cd
    ON jpf.company_id = cd.company_id
WHERE job_work_from_home = TRUE;

SELECT *
FROM remote_jobs_view;

SELECT
    company_name,
    COUNT(job_id) AS job_count
FROM remote_jobs_view
GROUP BY company_name
ORDER BY job_count DESC;