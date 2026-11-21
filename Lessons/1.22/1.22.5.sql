USE company_jobs;

CREATE OR REPLACE TEMPORARY TABLE ds_skills_count_temp AS
SELECT
    sd.skills AS skill_name,
    COUNT(jpf.job_id) AS skill_count
FROM data_jobs.job_postings_fact AS jpf
INNER JOIN data_jobs.company_dim AS cd
    ON jpf.company_id = cd.company_id
INNER JOIN data_jobs.skills_job_dim AS sjd
    ON jpf.job_id = sjd.job_id
INNER JOIN data_jobs.skills_dim AS sd
    ON sjd.skill_id = sd.skill_id
WHERE job_title_short = 'Data Engineer'
GROUP BY sd.skills;

SELECT *
FROM ds_skills_count_temp;