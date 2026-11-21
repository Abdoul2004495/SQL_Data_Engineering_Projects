-- .read Lessons/1.24/1.24.2.sql
CREATE OR REPLACE TABLE job_skill_priorities(
    job_id      INTEGER,
    skill_id    INTEGER,
    skill_name VARCHAR,
    priority_lvl INTEGER,
    status VARCHAR
);

SELECT * FROM  main.job_skill_priorities;


INSERT INTO job_skill_priorities(
    job_id,
    skill_id,
    status
)
SELECT
    sjd.job_id,
    sjd.skill_id,
    'ACTIVE' AS status
FROM data_jobs.skills_job_dim AS sjd
INNER JOIN staging.priority_skills AS ps
    ON sjd.skill_id = ps.skill_id
LIMIT 100000;

SELECT * FROM  main.job_skill_priorities;




-- DESCRIBE data_jobs.job_postings_fact;
-- SELECT * FROM data_jobs.job_postings_fact
-- LIMIT 10;
-- DESCRIBE data_jobs.skills_job_dim;
-- SELECT * FROM data_jobs.skills_job_dim
-- LIMIT 10;
-- DESCRIBE data_jobs.skills_dim;
-- SELECT * FROM data_jobs.skills_dim
-- LIMIT 10;
-- DESCRIBE staging.priority_skills;
-- SELECT * FROM staging.priority_skills
-- LIMIT 10;
