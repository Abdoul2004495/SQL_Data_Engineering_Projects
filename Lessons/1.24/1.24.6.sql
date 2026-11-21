USE company_jobs;

DELETE FROM staging.priority_skills
WHERE skill_id = 183;

MERGE INTO job_skill_priorities   AS tgt
USING staging.priority_skills AS src
ON tgt.skill_id = src.skill_id

WHEN NOT MATCHED BY SOURCE THEN
UPDATE SET
status = 'INACTIVE'

SELECT * FROM staging.priority_skills;

SELECT * FROM job_skill_priorities
ORDER by job_id;