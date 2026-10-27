USE company_jobs;

DELETE FROM job_skill_priorities AS tgt
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.priority_skills AS src
    WHERE tgt.skill_id = src.skill_id
);

SELECT * FROM job_skill_priorities WHERE skill_id = 183;