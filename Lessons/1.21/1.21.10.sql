USE company_jobs;

UPDATE dev.applications_fact
SET internal_candidate = TRUE
WHERE application_id = 1;

UPDATE dev.applications_fact
SET internal_candidate = TRUE
WHERE application_id = 3;

SELECT *
FROM dev.applications_fact;
