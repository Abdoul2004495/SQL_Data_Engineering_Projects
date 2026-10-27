USE company_jobs;

CREATE OR REPLACE TABLE job_postings_fact_year_salary AS
SELECT
    jpf.job_id,
    jpf.job_title_short,
    jpf.job_posted_date,
    jpf.job_location,
    jpf.salary_year_avg
FROM data_jobs.job_postings_fact AS jpf
WHERE salary_year_avg IS NOT NULL;

DELETE FROM job_postings_fact_year_salary
WHERE job_location IS NULL;

SELECT *
FROM job_postings_fact_year_salary;