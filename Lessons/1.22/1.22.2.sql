USE company_jobs;

CREATE OR REPLACE TABLE company_salary_stats AS
SELECT
    company_id,
    AVG(salary_year_avg) AS avg_yearly_salary,
    COUNT(job_id) AS job_count
FROM data_jobs.job_postings_fact
GROUP BY company_id
HAVING
    AVG(salary_year_avg) IS NOT NULL;

SELECT *
FROM company_salary_stats
;