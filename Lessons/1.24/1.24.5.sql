USE company_jobs;

UPDATE staging.priority_skills
SET priority_lvl = 1,
WHERE skill_id = 0;
UPDATE staging.priority_skills
SET priority_lvl = 2,
WHERE skill_id = 1;

MERGE INTO main.job_skill_priorities AS tgt
USING staging.priority_skills AS src
ON tgt.skill_id = src.skill_id

--tgt.priority_lvl IS DISTINCT FROM src.priority_lvl
WHEN MATCHED AND (tgt.priority_lvl <> src.priority_lvl OR tgt.priority_lvl IS NULL) THEN
UPDATE SET
priority_lvl = src.priority_lvl,
status = 'PRIORITY_CHANGE';

SELECT * FROM main.job_skill_priorities;