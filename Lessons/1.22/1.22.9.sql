USE company_jobs;

CREATE OR REPLACE TABLE jan_2023_cleanup_copy AS
SELECT *
FROM data_jobs.job_postings_fact;

DELETE jan_2023_cleanup_copy
WHERE job_posted_date < '2023_01_01';

SELECT *
FROM jan_2023_cleanup_copy
ORDER BY job_posted_date DESC;