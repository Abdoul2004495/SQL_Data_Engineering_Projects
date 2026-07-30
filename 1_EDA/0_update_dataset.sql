-- 🎁 BONUS: Build a database with the latest job data (2023-present)
--
-- ⚠️ IMPORTANT: Run this in a NEW database (data_jobs_bonus) — NOT the shared
-- course database (data_jobs). This script DROPS and rebuilds the star schema
-- tables in whatever database it runs in.
--
-- How to run (see the bonus lesson for full steps):
--   1. Save this file in your project folder with your EDA queries
--      (e.g., SQL_Data_Engineering_Course/Projects/1_EDA)
--   2. In your terminal, navigate to that folder and connect to MotherDuck:
--        duckdb "md:"
--   3. Create and switch to a new database:
--        CREATE DATABASE IF NOT EXISTS data_jobs_bonus;
--        USE data_jobs_bonus;
--   4. Run this script:   .read 0_update_dataset.sql
--
-- It creates the star schema tables and loads the latest dataset straight from
-- cloud storage — no file downloads needed. The data refreshes on the 5th of
-- every month with jobs through the end of the previous month, so just re-run
-- this script whenever you want the newest data.
-- NOTE: This is completely optional — the rest of the course uses the original
-- dataset, and your project works fine without this.

-- Set up initial configurations
PRAGMA enable_progress_bar;
PRAGMA enable_checkpoint_on_shutdown;

-- Drop existing tables (we're replacing them with the updated dataset)
DROP TABLE IF EXISTS skills_job_dim;
DROP TABLE IF EXISTS job_postings_fact;
DROP TABLE IF EXISTS skills_dim;
DROP TABLE IF EXISTS company_dim;

-- Recreate the star schema (same structure as 01_create_tables_dw.sql)
CREATE TABLE company_dim (
    company_id INTEGER PRIMARY KEY,
    name VARCHAR,
    link VARCHAR,
    link_google VARCHAR,
    thumbnail VARCHAR
);

CREATE TABLE skills_dim (
    skill_id INTEGER PRIMARY KEY,
    skills VARCHAR,
    type VARCHAR
);

CREATE TABLE job_postings_fact (
    job_id INTEGER PRIMARY KEY,
    company_id INTEGER,
    job_title_short VARCHAR,
    job_title VARCHAR,
    job_location VARCHAR,
    job_via VARCHAR,
    job_schedule_type VARCHAR,
    job_work_from_home BOOLEAN,
    search_location VARCHAR,
    job_posted_date TIMESTAMP,
    job_no_degree_mention BOOLEAN,
    job_health_insurance BOOLEAN,
    job_country VARCHAR,
    salary_rate VARCHAR,
    salary_year_avg DOUBLE,
    salary_hour_avg DOUBLE,
    FOREIGN KEY (company_id) REFERENCES company_dim(company_id)
);

CREATE TABLE skills_job_dim (
    skill_id INTEGER,
    job_id INTEGER,
    PRIMARY KEY (skill_id, job_id),
    FOREIGN KEY (skill_id) REFERENCES skills_dim(skill_id),
    FOREIGN KEY (job_id) REFERENCES job_postings_fact(job_id)
);

-- Load the UPDATED dataset (same load as 02_load_schema_dw.sql, new location)
INSERT INTO company_dim (company_id, name, link, link_google, thumbnail)
SELECT company_id, name, link, link_google, thumbnail
FROM read_csv('https://storage.googleapis.com/sql_de/bonus-80aee0e96046/company_dim.csv',
    AUTO_DETECT=true,
    HEADER=true);

INSERT INTO skills_dim (skill_id, skills, type)
SELECT skill_id, skills, type
FROM read_csv('https://storage.googleapis.com/sql_de/bonus-80aee0e96046/skills_dim.csv',
    AUTO_DETECT=true,
    HEADER=true)
WHERE skills IS NOT NULL;

INSERT INTO job_postings_fact (
    job_id, company_id, job_title_short, job_title, job_location,
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance,
    job_country, salary_rate, salary_year_avg, salary_hour_avg
)
SELECT
    job_id, company_id, job_title_short, job_title, job_location,
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance,
    job_country, salary_rate, salary_year_avg, salary_hour_avg
FROM read_csv('https://storage.googleapis.com/sql_de/bonus-80aee0e96046/job_postings_fact.csv',
    AUTO_DETECT=true,
    HEADER=true);

INSERT INTO skills_job_dim (skill_id, job_id)
SELECT skill_id, job_id
FROM read_csv('https://storage.googleapis.com/sql_de/bonus-80aee0e96046/skills_job_dim.csv',
    AUTO_DETECT=true,
    HEADER=true);

-- Verify the refresh: row counts and how recent the data goes
SELECT 'Company Dimension' AS table_name, COUNT(*) AS record_count FROM company_dim
UNION ALL
SELECT 'Skills Dimension', COUNT(*) FROM skills_dim
UNION ALL
SELECT 'Job Postings Fact', COUNT(*) FROM job_postings_fact
UNION ALL
SELECT 'Skills Job Bridge', COUNT(*) FROM skills_job_dim;

SELECT
    MIN(job_posted_date) AS earliest_posting,
    MAX(job_posted_date) AS latest_posting
FROM job_postings_fact;
