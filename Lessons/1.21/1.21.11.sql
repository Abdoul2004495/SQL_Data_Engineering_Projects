USE company_jobs;

ALTER TABLE dev.applications_fact
RENAME TO internal_applications_fact;

SELECT *
FROM information_schema.tables
WHERE table_catalog = 'company_jobs' AND table_schema = 'dev';