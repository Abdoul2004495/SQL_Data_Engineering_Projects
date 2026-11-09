-- Step 6: Mart - Update priority roles mart
-- Requires the DW tables created by 01_create_tables_dw.sql and 02_load_schema_dw.sql
-- and the priority_mart schema created by 05_create_priority_mart.sql.

SELECT '=== Updating Roles for Priority Mart ===' AS info;

CREATE SCHEMA IF NOT EXISTS priority_mart;

CREATE TABLE IF NOT EXISTS priority_mart.priority_roles (
  role_id      INTEGER PRIMARY KEY,
  role_name    VARCHAR,
  priority_lvl INTEGER
);

-- Ensure the baseline role set exists before any update
INSERT INTO priority_mart.priority_roles (role_id, role_name, priority_lvl)
VALUES
  (1, 'Data Engineer',        2),
  (2, 'Senior Data Engineer', 1),
  (3, 'Software Engineer',    3)
ON CONFLICT (role_id) DO NOTHING;

-- Update Data Engineer to Priority 1
UPDATE priority_mart.priority_roles
SET priority_lvl = 1
WHERE role_name = 'Data Engineer';

-- Add Data Scientist as Level 3 if it does not already exist
INSERT INTO priority_mart.priority_roles (role_id, role_name, priority_lvl)
SELECT 4, 'Data Scientist', 3
WHERE NOT EXISTS (
  SELECT 1
  FROM priority_mart.priority_roles
  WHERE role_name = 'Data Scientist'
);

SELECT * FROM priority_mart.priority_roles;

-- Create/update the temporary source table
SELECT '=== Creating Temp Source Table for Priority Mart ===' AS info;
CREATE OR REPLACE TEMP TABLE src_priority_jobs AS
SELECT
  jpf.job_id,
  jpf.job_title_short,
  cd.name AS company_name,
  jpf.job_posted_date,
  jpf.salary_year_avg,
  pr.priority_lvl,
  CURRENT_TIMESTAMP AS updated_at
FROM job_postings_fact jpf
LEFT JOIN company_dim cd ON jpf.company_id = cd.company_id
JOIN priority_mart.priority_roles pr
  ON jpf.job_title_short = pr.role_name;

-- Ensure the snapshot table exists before the merge
CREATE TABLE IF NOT EXISTS priority_mart.priority_jobs_snapshot (
  job_id              INTEGER PRIMARY KEY,
  job_title_short     VARCHAR,
  company_name        VARCHAR,
  job_posted_date     TIMESTAMP,
  salary_year_avg     DOUBLE,
  priority_lvl        INTEGER,
  updated_at          TIMESTAMP
);

-- Step 4: MERGE to sync snapshot with source
SELECT '=== Batch Updating priority_jobs_snapshot for Priority Mart ===' AS info;
MERGE INTO priority_mart.priority_jobs_snapshot AS tgt
USING src_priority_jobs AS src
ON tgt.job_id = src.job_id
WHEN MATCHED THEN
  UPDATE SET
    job_title_short = src.job_title_short,
    company_name    = src.company_name,
    job_posted_date = src.job_posted_date,
    salary_year_avg = src.salary_year_avg,
    priority_lvl    = src.priority_lvl,
    updated_at      = src.updated_at
WHEN NOT MATCHED THEN
  INSERT (
    job_id,
    job_title_short,
    company_name,
    job_posted_date,
    salary_year_avg,
    priority_lvl,
    updated_at
  )
  VALUES (
    src.job_id,
    src.job_title_short,
    src.company_name,
    src.job_posted_date,
    src.salary_year_avg,
    src.priority_lvl,
    src.updated_at
  )
WHEN NOT MATCHED BY SOURCE THEN
  DELETE;

-- Verify mart was updated
SELECT 'Priority Roles Dimension' AS table_name, COUNT(*) AS record_count FROM priority_mart.priority_roles
UNION ALL
SELECT 'Priority Jobs Snapshot', COUNT(*) FROM priority_mart.priority_jobs_snapshot;

-- Show sample data from each table
SELECT '=== Priority Roles Dimension Sample ===' AS info;
SELECT * FROM priority_mart.priority_roles;

SELECT '=== Priority Jobs Snapshot Sample ===' AS info;
SELECT
    job_title_short,
    COUNT(*) AS job_count,
    MIN(priority_lvl) AS priority_lvl,
    MIN(updated_at) AS updated_at
FROM priority_mart.priority_jobs_snapshot
GROUP BY job_title_short
ORDER BY job_count DESC;