
USE company_jobs;

UPDATE main.job_skill_priorities
SET status = 'URGENT'
WHERE status = 'ACTIVE';

SELECT * FROM main.job_skill_priorities;