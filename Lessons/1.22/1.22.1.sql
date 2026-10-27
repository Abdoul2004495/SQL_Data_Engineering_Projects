USE company_jobs;

CREATE OR REPLACE TABLE uk_jobs_archive AS
SELECT *
FROM data_jobs.job_postings_fact
WHERE job_country = 'United Kingdom';


SELECT *
FROM uk_jobs_archive;