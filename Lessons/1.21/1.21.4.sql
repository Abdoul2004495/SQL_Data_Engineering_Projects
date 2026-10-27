USE company_jobs;

CREATE TABLE IF NOT EXISTS dev.applications_fact(
    application_id INTEGER PRIMARY KEY,
    candidate_id INTEGER,
    job_id INTEGER,
    date_applied DATE,
    application_status TEXT,
    internal_candidate BOOLEAN
);

SELECT *
FROM dev.applications_fact;

DESCRIBE dev.applications_fact;