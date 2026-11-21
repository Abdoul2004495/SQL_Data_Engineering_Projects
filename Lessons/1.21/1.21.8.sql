USE company_jobs;

ALTER TABLE dev.applications_fact
RENAME COLUMN follow_up_timestamp TO follow_up_date;

DESCRIBE dev.applications_fact;

SELECT *
FROM dev.applications_fact;