USE company_jobs;


CREATE OR REPLACE TEMPORARY TABLE top_hiring_companies_temp AS
SELECT
    cd.company_id,
    cd.name AS company_name,
    COUNT(jpf.job_id) AS posting_count
FROM data_jobs.company_dim AS cd
INNER JOIN data_jobs.job_postings_fact AS jpf
    ON cd.company_id = jpf.company_id
GROUP BY cd.company_id, cd.name
HAVING COUNT(jpf.job_id) > 10;

SELECT *
FROM top_hiring_companies_temp;