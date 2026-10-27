USE company_jobs;

AlTER TABLE dev.internal_applications_fact
DROP COLUMN IF EXISTS internal_candidate;

SELECT *
FROM dev.internal_applications_fact;