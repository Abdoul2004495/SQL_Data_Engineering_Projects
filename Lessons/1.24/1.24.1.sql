-- .read Lessons/1.24/1.24.1.sql

USE company_jobs;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE OR REPLACE TABLE staging.priority_skills (
    skill_id INTEGER PRIMARY KEY,
    skill_name VARCHAR,
    priority_lvl INTEGER
);

INSERT INTO staging.priority_skills (skill_id, skill_name, priority_lvl)
VALUES
    (0, 'sql', 1),
    (183, 'tableau', 2);

SELECT * FROM information_schema.schemata;

SELECT *
FROM staging.priority_skills;