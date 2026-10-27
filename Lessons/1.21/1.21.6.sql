USE company_jobs;

ALTER TABLE dev.applications_fact
ADD COLUMN follow_up_timestamp TIMESTAMPTZ;

SELECT *
FROM dev.applications_fact;

DESCRIBE dev.applications_fact;