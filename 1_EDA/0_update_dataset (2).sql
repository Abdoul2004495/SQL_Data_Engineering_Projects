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
