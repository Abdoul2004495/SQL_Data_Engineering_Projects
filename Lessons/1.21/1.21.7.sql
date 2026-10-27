USE company_jobs;

ALTER TABLE dev.applications_fact
ALTER COLUMN follow_up_timestamp TYPE DATE;

DESCRIBE dev.applications_fact;

SELECT *
FROM dev.applications_fact;