USE company_jobs;

DROP TABLE IF EXISTS dev.internal_applications_fact;

SELECT *
FROM information_schema.tables
WHERE table_catalog = 'company_jobs';