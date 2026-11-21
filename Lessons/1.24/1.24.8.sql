INSERT INTO staging.priority_skills (skill_id, skill_name, priority_lvl)
VALUES (77, 'aws', 3);

MERGE INTO job_skill_priorities AS tgt
USING (
SELECT
    sjd.job_id,
    ps.skill_id,
    ps.skill_name,
    ps.priority_lvl
FROM data_jobs.skills_job_dim AS sjd
INNER JOIN staging.priority_skills AS ps
ON sjd.skill_id = ps.skill_id
) AS src
ON tgt.job_id = src.job_id
    AND tgt.skill_id = src.skill_id

WHEN MATCHED THEN
UPDATE SET
priority_lvl = src.priority_lvl,
skill_name = src.skill_name

WHEN NOT MATCHED THEN
INSERT(
    job_id,
    skill_id,
    skill_name,
    priority_lvl,
    status
)
VALUES
(
    src.job_id,
    src.skill_id,
    src.skill_name,
    src.priority_lvl,
    'NEW_SKILL'
);

SELECT * FROM staging.priority_skills;

SELECT * FROM job_skill_priorities
ORDER BY job_id;