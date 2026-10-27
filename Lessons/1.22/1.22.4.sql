USE company_jobs;

CREATE OR REPLACE VIEW cloud_engineering_roles_view AS
SELECT
    jpf.job_title,
    cd.name AS company_name,
    sd.skills AS skill_name
FROM data_jobs.job_postings_fact AS jpf
INNER JOIN data_jobs.company_dim AS cd
    ON jpf.company_id = cd.company_id
INNER JOIN data_jobs.skills_job_dim AS sjd
    ON jpf.job_id = sjd.job_id
INNER JOIN data_jobs.skills_dim AS sd
    ON sjd.skill_id = sd.skill_id
WHERE job_title_short = 'Data Engineer' AND (skills = 'aws' OR skills = 'gcp');

SELECT *
FROM cloud_engineering_roles_view;


SELECT *
FROM data_jobs.skills_job_dim
LIMIT 10;

SELECT *
FROM data_jobs.skills_dim
LIMIT 10;

SELECT *
FROM data_jobs.company_dim
LIMIT 10;

SELECT *
FROM data_jobs.job_postings_fact
LIMIT 10;