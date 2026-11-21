USE company_jobs;

WITH company_averages AS (
    SELECT
        jpf.company_id,
        AVG(salary_year_avg) AS avg_company_salary
    FROM data_jobs.job_postings_fact AS jpf
    GROUP BY jpf.company_id
)

SELECT
    jpf.job_id,
    jpf.job_title_short,
    jpf.company_id,
    jpf.salary_year_avg,
    ca.avg_company_salary
FROM data_jobs.job_postings_fact AS jpf
INNER JOIN company_averages AS ca
    ON jpf.company_id = jpf.company_id
WHERE jpf.salary_year_avg > ca.avg_company_salary;