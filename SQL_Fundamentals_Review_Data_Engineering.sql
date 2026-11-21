-- ==========================================================================
-- SQL_Fundamentals_Review_Data_Engineering.sql
-- Personal SQL revision notebook  |  Goal: return confidently to WINDOW FUNCTIONS
-- Engine: written for DuckDB, with PostgreSQL differences flagged as [PG] / [DUCKDB]
-- ==========================================================================
--
-- HOW TO USE THIS FILE
--   1. Run PART 0 first (it builds a small practice database).
--   2. Then go concept by concept. Run each EXAMPLE, change it, break it.
--   3. Try every "PRACTICE" line BEFORE looking at anything else.
--   4. Part 19 has 80 exercises (TODO). The ANSWER KEY is at the very END of the file.
--
-- ROADMAP (the progression of this notebook)
--   Fundamentals -> filtering -> aggregation -> execution order -> joins
--   -> CASE -> NULL/text -> dates -> subqueries -> CTEs -> set operators
--   -> data types -> DDL/DML -> data modeling -> WINDOW FUNCTIONS
--   -> nested functions -> SQL in Data Engineering -> best practices
--   -> debugging -> practice -> cheat sheet -> answer key
--
-- ENGINE NOTES (read once)
--   * DuckDB: run with  duckdb my.db  then  .read SQL_Fundamentals_Review_Data_Engineering.sql
--   * Strings use 'single quotes'. "Double quotes" are for identifiers (column names).
--   * Keywords are case-insensitive. Identifiers are case-insensitive in DuckDB;
--     in PostgreSQL unquoted names are folded to lowercase.
-- ==========================================================================


-- ==========================================================================
-- PART 0 — PRACTICE DATABASE (small on purpose, so you can SEE every row)
-- ==========================================================================
-- Four tables inspired by a job-postings dataset:
--   company_dim      : one row per company                  (dimension)
--   job_postings     : one row per job posting              (the "fact"-like table)
--   skills_dim       : one row per skill                    (dimension)
--   skills_job_dim   : one row per (job, skill) pair        (bridge table)
-- NOTE: The data is FAKE and tiny. Real datasets have hundreds of thousands of rows,
-- but the logic you learn here is identical.

DROP TABLE IF EXISTS skills_job_dim;
DROP TABLE IF EXISTS job_postings;
DROP TABLE IF EXISTS skills_dim;
DROP TABLE IF EXISTS company_dim;

CREATE TABLE company_dim (
    company_id  INTEGER PRIMARY KEY,
    name        VARCHAR NOT NULL
);

CREATE TABLE skills_dim (
    skill_id  INTEGER PRIMARY KEY,
    skills    VARCHAR NOT NULL,
    type      VARCHAR
);

CREATE TABLE job_postings (
    job_id              INTEGER PRIMARY KEY,
    company_id          INTEGER REFERENCES company_dim (company_id),
    job_title_short     VARCHAR,
    job_title           VARCHAR,
    job_country         VARCHAR,
    job_posted_date     TIMESTAMP,
    job_schedule_type   VARCHAR,
    job_work_from_home  BOOLEAN,
    salary_year_avg     DECIMAL(10,2)      -- NULL when the posting has no salary
);

CREATE TABLE skills_job_dim (
    job_id    INTEGER REFERENCES job_postings (job_id),
    skill_id  INTEGER REFERENCES skills_dim (skill_id),
    PRIMARY KEY (job_id, skill_id)
);

INSERT INTO company_dim VALUES
    (1, 'DataCorp'),
    (2, 'CloudNine'),
    (3, 'FinPipe'),
    (4, 'EmptyCo');                        -- company with NO postings (useful for LEFT JOIN)

INSERT INTO skills_dim VALUES
    (1, 'sql',     'programming'),
    (2, 'python',  'programming'),
    (3, 'spark',   'libraries'),
    (4, 'airflow', 'libraries'),
    (5, 'aws',     'cloud'),
    (6, 'excel',   'analyst_tools');

INSERT INTO job_postings VALUES
    ( 1, 1, 'Data Engineer',  'Senior Data Engineer', 'United States', '2025-01-05 09:30:00', 'Full-time',  FALSE, 150000),
    ( 2, 1, 'Data Engineer',  'Data Engineer',        'United States', '2025-01-20 14:00:00', 'Full-time',  TRUE,  125000),
    ( 3, 1, 'Data Analyst',   'Junior Data Analyst',  'France',        '2025-02-02 08:15:00', 'Full-time',  FALSE, NULL),
    ( 4, 2, 'Data Engineer',  'Analytics Engineer',   'France',        '2025-02-14 11:45:00', 'Contractor', TRUE,  110000),
    ( 5, 2, 'Data Scientist', 'Data Scientist',       'Germany',       '2025-02-28 16:20:00', 'Full-time',  FALSE, 130000),
    ( 6, 2, 'Data Engineer',  'data engineer ',       'Germany',       '2025-03-03 10:00:00', 'Full-time',  FALSE, NULL),   -- dirty title: lowercase + trailing space
    ( 7, 3, 'Data Engineer',  'Lead Data Engineer',   'United States', '2025-03-15 13:10:00', 'Full-time',  TRUE,  170000),
    ( 8, 3, 'Data Analyst',   'Data Analyst',         'United States', '2025-03-22 09:00:00', 'Part-time',  FALSE, 70000),
    ( 9, 3, 'Data Engineer',  'ETL Developer',        'France',        '2025-04-01 12:30:00', 'Full-time',  FALSE, 95000),
    (10, 1, 'Data Engineer',  'Data Engineer',        'France',        '2025-04-10 15:45:00', 'Full-time',  TRUE,  105000),
    (11, 2, 'Data Scientist', 'ML Scientist',         'United States', '2025-04-18 10:30:00', 'Full-time',  TRUE,  160000),
    (12, 3, 'Data Engineer',  'Cloud Data Engineer',  'Germany',       '2025-05-06 08:00:00', 'Contractor', FALSE, 120000);

INSERT INTO skills_job_dim VALUES
    (1,1),(1,2),(1,3),(1,4),
    (2,1),(2,2),(2,5),
    (3,1),(3,6),
    (4,1),(4,5),
    (5,2),(5,1),
    -- job 6 has NO skills listed on purpose
    (7,1),(7,2),(7,3),(7,5),
    (8,6),(8,1),
    (9,1),(9,4),
    (10,1),(10,2),
    (11,2),
    (12,1),(12,5),(12,3);

-- Quick look at the data you will use everywhere:
SELECT * FROM job_postings ORDER BY job_id;


-- ==========================================================================
-- PART 1 — SQL FUNDAMENTALS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: WHAT SQL IS
------------------------------------------------
-- WHAT IT MEANS:
--   SQL (Structured Query Language) is the language used to ASK QUESTIONS to a
--   database and to CHANGE the data inside it. SQL is DECLARATIVE: you describe
--   WHAT result you want, the database engine decides HOW to compute it.
--
-- WHY A DATA ENGINEER USES IT:
--   SQL is the common language of warehouses (Snowflake, BigQuery, Redshift,
--   Postgres, DuckDB). Data engineers use it to load, clean, transform,
--   model and validate data. Even when you use Python, a lot of the work is SQL.
--
-- BASIC SYNTAX (the 4 families of SQL):
--   DQL  - querying          : SELECT
--   DML  - changing rows     : INSERT, UPDATE, DELETE
--   DDL  - changing structure: CREATE, ALTER, DROP, TRUNCATE
--   DCL  - permissions       : GRANT, REVOKE   (not covered here)
--
-- EXAMPLE:
SELECT 'Hello, Data Engineering' AS message;
--
-- HOW TO THINK ABOUT IT:
--   You write a "question" in a fixed grammar. Same question + same data = same answer.
--
-- COMMON MISTAKE:
--   Thinking SQL runs top-to-bottom like Python. It does NOT (see PART 3).
--
-- PRACTICE:
--   Write a SELECT that returns your name and today's date (hint: CURRENT_DATE).


------------------------------------------------
-- CONCEPT: DATABASE vs TABLE vs ROW vs COLUMN
------------------------------------------------
-- WHAT IT MEANS:
--   DATABASE : a container of tables (and views, schemas, etc.)
--   TABLE    : a grid of data about ONE kind of thing (e.g. job_postings)
--   ROW      : ONE record/observation (e.g. ONE job posting)   a.k.a. tuple
--   COLUMN   : ONE attribute with ONE data type (e.g. job_country) a.k.a. field
--
-- WHY A DATA ENGINEER USES IT:
--   Pipelines move rows between tables. You must always know:
--   "What does ONE ROW of this table represent?"  <-- this is the GRAIN (PART 4).
--
-- BASIC SYNTAX (inspect structure):
--   DESCRIBE job_postings;                         -- [DUCKDB]
--   -- [PG]: \d job_postings   or query information_schema.columns
--
-- EXAMPLE:
DESCRIBE job_postings;

-- Works in both engines:
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'job_postings';
--
-- HOW TO THINK ABOUT IT:
--   Table = spreadsheet tab. Row = one line. Column = one header.
--   Unlike a spreadsheet, every column has a strict type and tables are related by keys.
--
-- COMMON MISTAKE:
--   Mixing grains: storing "one posting" and "one skill" in the same table row set
--   without noticing it duplicates the posting.
--
-- PRACTICE:
--   Use DESCRIBE on skills_dim. How many columns? What does ONE ROW mean there?


------------------------------------------------
-- CONCEPT: SELECT and FROM
------------------------------------------------
-- WHAT IT MEANS:
--   FROM   : which table(s) to read.
--   SELECT : which columns / expressions to return.
--
-- WHY A DATA ENGINEER USES IT:
--   Every transformation step in a pipeline is a SELECT that reshapes data.
--
-- BASIC SYNTAX:
--   SELECT column1, column2 FROM table_name;
--
-- EXAMPLE:
-- Expressions and aliases (AS) are allowed in SELECT
SELECT job_id,
       job_title,
       salary_year_avg,
       salary_year_avg / 12 AS salary_month_avg      -- computed column
FROM job_postings;
--
-- HOW TO THINK ABOUT IT:
--   FROM = "where is the data?"   SELECT = "what do I want to see?"
--
-- COMMON MISTAKE:
--   Forgetting that SELECT does NOT change the table. It only returns a result.
--
-- PRACTICE:
--   Return job_id and job_posted_date only.


------------------------------------------------
-- CONCEPT: SELECT * vs SPECIFIC COLUMNS
------------------------------------------------
-- WHAT IT MEANS:
--   * = "all columns". Specific columns = only what you name.
--
-- WHY A DATA ENGINEER USES IT:
--   SELECT * is great for EXPLORING. In pipelines avoid it: if someone adds or
--   reorders a column upstream, your job silently changes (or breaks).
--   Columnar engines (DuckDB, BigQuery, Parquet) also read LESS data
--   when you select fewer columns = faster + cheaper.
--
-- BASIC SYNTAX:
--   SELECT * FROM t;
--   SELECT col_a, col_b FROM t;
--   SELECT * EXCLUDE (col_a) FROM t;               -- [DUCKDB] all except col_a
--
-- EXAMPLE:
SELECT * FROM company_dim;                          -- exploring
SELECT company_id, name FROM company_dim;           -- production style
--
-- HOW TO THINK ABOUT IT:
--   Explore with *, build with explicit columns.
--
-- COMMON MISTAKE:
--   Leaving SELECT * in a view or ETL job.
--
-- PRACTICE:
--   Select every column of job_postings EXCEPT salary_year_avg (DuckDB: EXCLUDE).


------------------------------------------------
-- CONCEPT: DISTINCT
------------------------------------------------
-- WHAT IT MEANS:
--   Removes duplicate rows from the RESULT (comparing all selected columns together).
--
-- WHY A DATA ENGINEER USES IT:
--   To list unique values (countries, categories) and to PROFILE data quality.
--   Warning: DISTINCT is often used to "hide" duplicates created by a bad JOIN.
--   That hides the bug instead of fixing it (see PART 4 and PART 18).
--
-- BASIC SYNTAX:
--   SELECT DISTINCT col1, col2 FROM t;
--
-- EXAMPLE:
SELECT DISTINCT job_country FROM job_postings;
SELECT DISTINCT job_country, job_schedule_type FROM job_postings;   -- unique PAIRS
--
-- HOW TO THINK ABOUT IT:
--   DISTINCT applies to the whole row of selected columns, not to one column.
--
-- COMMON MISTAKE:
--   Writing  SELECT DISTINCT(job_country), job_title  and expecting only
--   country to be distinct. The parentheses change nothing.
--
-- PRACTICE:
--   List the distinct job_title_short values.


------------------------------------------------
-- CONCEPT: WHERE  +  COMPARISON OPERATORS
------------------------------------------------
-- WHAT IT MEANS:
--   WHERE keeps only the ROWS for which the condition is TRUE.
--   Operators:  =   <> (or !=)   <   <=   >   >=
--
-- WHY A DATA ENGINEER USES IT:
--   Filtering early reduces data volume, which makes every later step faster.
--   It is also how you isolate bad rows during validation.
--
-- BASIC SYNTAX:
--   SELECT ... FROM t WHERE condition;
--
-- EXAMPLE:
SELECT job_id, job_title, job_country
FROM job_postings
WHERE job_country = 'France';                       -- text uses single quotes

SELECT job_id, salary_year_avg
FROM job_postings
WHERE salary_year_avg >= 120000;
--
-- HOW TO THINK ABOUT IT:
--   WHERE is a row-by-row yes/no test. Rows that give FALSE *or NULL* are dropped.
--
-- COMMON MISTAKE:
--   Text comparison is case-sensitive: 'france' <> 'France'.
--   Using double quotes "France" (that means a column name, not text).
--
-- PRACTICE:
--   Return postings NOT in the United States.


------------------------------------------------
-- CONCEPT: AND / OR / NOT
------------------------------------------------
-- WHAT IT MEANS:
--   AND : both conditions true.   OR : at least one true.   NOT : reverses.
--   Priority: NOT first, then AND, then OR.
--
-- WHY A DATA ENGINEER USES IT:
--   Real filters are multi-condition (e.g. "valid, recent, non-test records").
--   Wrong precedence = silently wrong data in the warehouse.
--
-- BASIC SYNTAX:
--   WHERE a AND b      WHERE a OR b      WHERE NOT a
--
-- EXAMPLE:
SELECT job_id, job_title_short, job_country, salary_year_avg
FROM job_postings
WHERE job_title_short = 'Data Engineer'
  AND (job_country = 'France' OR job_country = 'Germany')    -- parentheses matter!
  AND salary_year_avg IS NOT NULL;
--
-- HOW TO THINK ABOUT IT:
--   Always add parentheses when you mix AND and OR. Never rely on memory.
--
-- COMMON MISTAKE:
--   a AND b OR c  is read as  (a AND b) OR c   -> often NOT what you meant.
--
-- PRACTICE:
--   Data Analyst OR Data Scientist postings located in the United States.
--   Write it twice: once WRONG (no parentheses) and compare the row counts.


------------------------------------------------
-- CONCEPT: IN
------------------------------------------------
-- WHAT IT MEANS:
--   Shortcut for many OR equality checks.
--
-- WHY A DATA ENGINEER USES IT:
--   Filtering on lists of codes / statuses / countries. Later, IN with a subquery
--   (PART 8) filters one table using another.
--
-- BASIC SYNTAX:
--   WHERE col IN (v1, v2, v3)      WHERE col NOT IN (v1, v2)
--
-- EXAMPLE:
SELECT job_id, job_country
FROM job_postings
WHERE job_country IN ('France', 'Germany');
--
-- HOW TO THINK ABOUT IT:
--   col IN (a,b,c)  ==  col = a OR col = b OR col = c
--
-- COMMON MISTAKE:
--   NOT IN with a list/subquery that contains a NULL returns NO rows
--   (because x <> NULL is unknown). Prefer NOT EXISTS for safety (PART 8).
--
-- PRACTICE:
--   Postings whose schedule type is Contractor or Part-time.


------------------------------------------------
-- CONCEPT: BETWEEN
------------------------------------------------
-- WHAT IT MEANS:
--   col BETWEEN a AND b   is   col >= a AND col <= b   (BOTH ENDS INCLUDED).
--
-- WHY A DATA ENGINEER USES IT:
--   Ranges of numbers/dates. With TIMESTAMPS it is risky (see PART 7).
--
-- BASIC SYNTAX:
--   WHERE col BETWEEN low AND high
--
-- EXAMPLE:
SELECT job_id, salary_year_avg
FROM job_postings
WHERE salary_year_avg BETWEEN 100000 AND 130000;
--
-- HOW TO THINK ABOUT IT:
--   Inclusive on both sides. Low value first.
--
-- COMMON MISTAKE:
--   BETWEEN 130000 AND 100000 returns nothing (low must come first).
--   With timestamps, BETWEEN '2025-01-01' AND '2025-01-31' misses most of Jan 31.
--
-- PRACTICE:
--   Postings with salary from 90000 to 110000 (check that both ends are included).


------------------------------------------------
-- CONCEPT: LIKE (pattern matching on text)
------------------------------------------------
-- WHAT IT MEANS:
--   %  = any number of characters (including none)
--   _  = exactly one character
--
-- WHY A DATA ENGINEER USES IT:
--   Quick text searching and cleaning checks (e.g. titles containing 'engineer').
--
-- BASIC SYNTAX:
--   WHERE col LIKE 'pattern'
--   WHERE col ILIKE 'pattern'      -- case-INSENSITIVE ([PG] and [DUCKDB])
--
-- EXAMPLE:
SELECT job_id, job_title
FROM job_postings
WHERE job_title ILIKE '%engineer%';     -- finds 'data engineer ' (lowercase) too
--
-- HOW TO THINK ABOUT IT:
--   '%data%'  contains   |  'data%'  starts with   |  '%data'  ends with
--
-- COMMON MISTAKE:
--   LIKE is case-sensitive in PG and DuckDB. Use ILIKE or LOWER(col) LIKE '...'.
--   A leading % ('%abc') can prevent index use on big tables (performance).
--
-- PRACTICE:
--   Titles that start with 'Data' (any case).


------------------------------------------------
-- CONCEPT: NULL  /  IS NULL  /  IS NOT NULL
------------------------------------------------
-- WHAT IT MEANS:
--   NULL = "value unknown / missing". It is NOT zero, NOT an empty string.
--   Any comparison with NULL gives UNKNOWN (neither true nor false).
--
-- WHY A DATA ENGINEER USES IT:
--   Missing data is everywhere in real pipelines. You must detect, count,
--   and decide how to handle it (keep, fill, reject).
--
-- BASIC SYNTAX:
--   WHERE col IS NULL        WHERE col IS NOT NULL
--
-- EXAMPLE:
SELECT job_id, job_title, salary_year_avg
FROM job_postings
WHERE salary_year_avg IS NULL;

-- This returns ZERO rows, because "= NULL" is never true:
SELECT job_id FROM job_postings WHERE salary_year_avg = NULL;
--
-- HOW TO THINK ABOUT IT:
--   NULL = NULL  -> NULL (unknown).   NULL <> 5  -> NULL.   Only IS [NOT] NULL works.
--
-- COMMON MISTAKE:
--   "salary <> 100000" silently EXCLUDES rows where salary is NULL.
--
-- PRACTICE:
--   Count how many postings have a salary and how many don't (hint: PART 2).


------------------------------------------------
-- CONCEPT: ORDER BY  (ASC / DESC)
------------------------------------------------
-- WHAT IT MEANS:
--   Sorts the final result. ASC = smallest first (default). DESC = largest first.
--
-- WHY A DATA ENGINEER USES IT:
--   Reading/inspecting results, top-N queries, and (inside OVER) window ordering.
--   Tables have NO guaranteed order without ORDER BY.
--
-- BASIC SYNTAX:
--   ORDER BY col1 DESC, col2 ASC
--   ORDER BY col DESC NULLS LAST        -- control NULL position
--
-- EXAMPLE:
SELECT job_id, job_country, salary_year_avg
FROM job_postings
ORDER BY job_country ASC, salary_year_avg DESC NULLS LAST;
--
-- HOW TO THINK ABOUT IT:
--   Sort by the first column; ties are broken by the next one.
--
-- COMMON MISTAKE:
--   Assuming rows come back "in insertion order" with no ORDER BY.
--   NULL placement: PG puts NULLs FIRST on DESC, DuckDB's default may differ
--   -> always write NULLS LAST / NULLS FIRST explicitly.
--
-- PRACTICE:
--   Sort postings by posted date, newest first.


------------------------------------------------
-- CONCEPT: LIMIT
------------------------------------------------
-- WHAT IT MEANS:
--   Returns only the first N rows of the result.
--
-- WHY A DATA ENGINEER USES IT:
--   Peek at big tables safely; top-N queries. Never LIMIT without ORDER BY if you
--   care WHICH rows you get.
--
-- BASIC SYNTAX:
--   LIMIT n          LIMIT n OFFSET k     -- skip k rows first
--   [SQL Server uses TOP n; Oracle uses FETCH FIRST n ROWS ONLY]
--
-- EXAMPLE:
SELECT job_id, salary_year_avg
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY salary_year_avg DESC
LIMIT 3;                                -- the 3 best-paid postings
--
-- HOW TO THINK ABOUT IT:
--   LIMIT is the LAST step: first everything is computed, sorted, then cut.
--
-- COMMON MISTAKE:
--   LIMIT 3 without ORDER BY = 3 arbitrary rows.
--
-- PRACTICE:
--   Show the 5 most recent postings.


-- ==========================================================================
-- PART 2 — AGGREGATION
-- ==========================================================================

------------------------------------------------
-- CONCEPT: COUNT / COUNT(*) / COUNT(column)
------------------------------------------------
-- WHAT IT MEANS:
--   COUNT(*)               : number of ROWS.
--   COUNT(column)          : number of rows where column is NOT NULL.
--   COUNT(DISTINCT column) : number of UNIQUE non-NULL values.
--
-- WHY A DATA ENGINEER USES IT:
--   Row counts are the #1 validation tool: source count vs target count,
--   null counts, duplicate counts.
--
-- BASIC SYNTAX:
--   SELECT COUNT(*), COUNT(col), COUNT(DISTINCT col) FROM t;
--
-- EXAMPLE:
SELECT COUNT(*)                        AS total_rows,
       COUNT(salary_year_avg)          AS rows_with_salary,
       COUNT(*) - COUNT(salary_year_avg) AS rows_missing_salary,   -- null counter trick
       COUNT(DISTINCT company_id)      AS distinct_companies
FROM job_postings;
--
-- HOW TO THINK ABOUT IT:
--   COUNT(*) counts rows. COUNT(col) skips NULLs.
--
-- COMMON MISTAKE:
--   Using COUNT(col) when you wanted all rows -> NULL rows vanish from the count.
--
-- PRACTICE:
--   How many distinct countries are there?


------------------------------------------------
-- CONCEPT: SUM / AVG / MIN / MAX
------------------------------------------------
-- WHAT IT MEANS:
--   SUM total, AVG mean, MIN smallest, MAX largest. All IGNORE NULLs.
--
-- WHY A DATA ENGINEER USES IT:
--   Building metrics/aggregated tables (marts) and sanity checks (min/max ranges).
--
-- BASIC SYNTAX:
--   SELECT SUM(col), AVG(col), MIN(col), MAX(col) FROM t;
--
-- EXAMPLE:
SELECT SUM(salary_year_avg)  AS total_salary,
       AVG(salary_year_avg)  AS avg_salary,       -- average over NON-NULL rows only (9 rows here)
       MIN(salary_year_avg)  AS min_salary,
       MAX(salary_year_avg)  AS max_salary
FROM job_postings;
--
-- HOW TO THINK ABOUT IT:
--   AVG = SUM / COUNT(col), NOT SUM / COUNT(*). NULLs are not zeros.
--
-- COMMON MISTAKE:
--   Mixing aggregates with plain columns without GROUP BY:
--   SELECT job_country, AVG(salary_year_avg) FROM job_postings;   -- ERROR
--
-- PRACTICE:
--   Average salary of Data Engineer postings only.


------------------------------------------------
-- CONCEPT: GROUP BY
------------------------------------------------
-- WHAT IT MEANS:
--   Splits rows into groups (one group per distinct value of the grouping columns)
--   and collapses each group into ONE row.   many rows -> fewer rows
--
-- WHY A DATA ENGINEER USES IT:
--   Creates summary tables, rollups, and dedup checks:
--   GROUP BY key HAVING COUNT(*) > 1  finds duplicate keys.
--
-- BASIC SYNTAX:
--   SELECT group_col, AGG(x) FROM t GROUP BY group_col;
--   GROUP BY ALL            -- [DUCKDB] groups by every non-aggregate select column
--
-- EXAMPLE:
SELECT job_country,
       COUNT(*)               AS n_postings,
       ROUND(AVG(salary_year_avg), 0) AS avg_salary
FROM job_postings
GROUP BY job_country
ORDER BY n_postings DESC;
--
-- HOW TO THINK ABOUT IT:
--   Every selected column must be EITHER in GROUP BY OR inside an aggregate.
--   The result grain = one row per group.
--
-- COMMON MISTAKE:
--   Grouping by too few columns (mixing grains) or too many (no collapse).
--
-- PRACTICE:
--   Number of postings per job_title_short and per schedule type together.


------------------------------------------------
-- CONCEPT: HAVING  and  WHERE vs HAVING
------------------------------------------------
-- WHAT IT MEANS:
--   WHERE  filters ROWS   (before grouping).
--   HAVING filters GROUPS (after grouping, can use aggregates).
--
-- WHY A DATA ENGINEER USES IT:
--   "Which keys appear more than once?"  "Which categories have too few rows?"
--
-- BASIC SYNTAX:
--   SELECT g, AGG(x) FROM t WHERE row_condition GROUP BY g HAVING group_condition;
--
-- EXAMPLE:
-- Step: WHERE removes rows with no salary and non-full-time rows (ROW filter).
-- Step: GROUP BY makes one group per country.
-- Step: HAVING keeps only countries whose AVERAGE (a GROUP property) is high.
SELECT job_country,
       COUNT(*)              AS n_postings,
       AVG(salary_year_avg)  AS avg_salary
FROM job_postings
WHERE salary_year_avg IS NOT NULL            -- rows
  AND job_schedule_type = 'Full-time'        -- rows
GROUP BY job_country
HAVING AVG(salary_year_avg) > 110000;        -- groups
--
-- HOW TO THINK ABOUT IT:
--   WHERE  filters ROWS.     HAVING filters GROUPS.
--   If the condition talks about a single row value  -> WHERE.
--   If it needs COUNT/SUM/AVG of a group              -> HAVING.
--
-- COMMON MISTAKE:
--   WHERE COUNT(*) > 3     -> ERROR: aggregates are not allowed in WHERE.
--   Putting row filters in HAVING: works, but wastes time (filters after grouping).
--
-- PRACTICE:
--   Countries with at least 4 postings.


-- ==========================================================================
-- PART 3 — LOGICAL ORDER OF EXECUTION
-- ==========================================================================
-- WHAT IT MEANS:
--   You WRITE:   SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT
--   SQL LOGICALLY PROCESSES:
--
--     1. FROM      -> get the table(s) (and do JOINs)
--     2. WHERE     -> filter rows
--     3. GROUP BY  -> form groups
--     4. HAVING    -> filter groups
--     5. SELECT    -> compute the output columns (and aliases are born HERE)
--          (window functions are computed here too - PART 14)
--     6. DISTINCT  -> remove duplicates
--     7. ORDER BY  -> sort the result
--     8. LIMIT     -> cut the result
--
--   "Logically" because the optimizer may physically reorder work for speed,
--   but results must behave AS IF this order were followed.
--
-- WHY IT MATTERS FOR A DATA ENGINEER:
--   It explains most beginner errors: aliases in WHERE, aggregates in WHERE,
--   window functions in WHERE, "why does my filter change my counts?".

-- EXAMPLE 1: an alias does not exist yet in WHERE (SELECT happens after WHERE)
-- Fails:
--   SELECT salary_year_avg / 12 AS salary_month FROM job_postings WHERE salary_month > 10000;
-- Fix: repeat the expression, or use a CTE/subquery.
SELECT salary_year_avg / 12 AS salary_month
FROM job_postings
WHERE salary_year_avg / 12 > 10000;

-- EXAMPLE 2: ORDER BY runs AFTER SELECT, so it CAN use the alias
SELECT job_country, COUNT(*) AS n
FROM job_postings
GROUP BY job_country
ORDER BY n DESC;                       -- alias n works here

-- EXAMPLE 3: filtering BEFORE vs AFTER grouping changes the result
-- (a) WHERE first: average over Full-time rows only
SELECT job_country, AVG(salary_year_avg) AS avg_full_time
FROM job_postings
WHERE job_schedule_type = 'Full-time'
GROUP BY job_country;
-- (b) No filter, group by both: you must read the right row yourself
SELECT job_country, job_schedule_type, AVG(salary_year_avg) AS avg_salary
FROM job_postings
GROUP BY job_country, job_schedule_type;

-- EXAMPLE 4: LIMIT is last; it cuts AFTER sorting
SELECT job_id, salary_year_avg
FROM job_postings
ORDER BY salary_year_avg DESC NULLS LAST
LIMIT 2;

-- EXAMPLE 5 (preview): window functions are computed in the SELECT step,
-- AFTER WHERE/GROUP BY/HAVING -> you cannot filter them in WHERE. Use a CTE (PART 14).
--
-- QUICK MEMORY TRICK:  "Fat Williams Goes Hunting, Showing Off Lions"
--   FROM, WHERE, GROUP BY, HAVING, SELECT, ORDER BY, LIMIT
--
-- COMMON MISTAKE:
--   Believing SELECT runs first because it is written first.
--
-- PRACTICE:
--   Explain in a comment why this fails, then fix it with a subquery or CTE:
--     SELECT job_country, COUNT(*) AS n FROM job_postings WHERE n > 3 GROUP BY job_country;


-- ==========================================================================
-- PART 4 — JOINS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: WHY DATABASES USE MULTIPLE TABLES (+ keys)
------------------------------------------------
-- WHAT IT MEANS:
--   Instead of repeating the company name on every posting row, we store the
--   company ONCE in company_dim and refer to it by company_id. This is
--   NORMALIZATION (PART 13): less duplication, fewer inconsistencies.
--
--   PRIMARY KEY (PK): column(s) that uniquely identify ONE row in a table.
--                     Unique + NOT NULL.  e.g. company_dim.company_id
--   FOREIGN KEY (FK): column in table B that points to the PK of table A.
--                     e.g. job_postings.company_id -> company_dim.company_id
--
-- WHY A DATA ENGINEER USES IT:
--   Keys are how you reconnect data. Broken keys (orphans, duplicates) are the
--   top cause of wrong numbers in a warehouse.
--
-- RELATIONSHIP TYPES (cardinality):
--   ONE-TO-ONE    : one row in A <-> at most one row in B
--                   (e.g. employee <-> employee_badge)
--   ONE-TO-MANY   : one row in A <-> many rows in B
--                   (one company -> many job_postings)         <-- most common
--   MANY-TO-MANY  : many in A <-> many in B. Needs a BRIDGE table.
--                   (jobs <-> skills via skills_job_dim)
--
-- THE MAP OF OUR MINI DATABASE:
--   company_dim (1) ----< job_postings (many)
--   job_postings (1) ----< skills_job_dim >---- (1) skills_dim
--
-- PRACTICE:
--   For each table, write the PK and the FK(s) in a comment.


------------------------------------------------
-- CONCEPT: INNER JOIN  (+ ON, aliases, join keys)
------------------------------------------------
-- WHAT IT MEANS:
--   Combines rows from two tables where the ON condition matches.
--   INNER JOIN keeps ONLY matching rows from both sides.
--
-- WHY A DATA ENGINEER USES IT:
--   Attaching descriptive attributes (company name) to fact-like rows;
--   building enriched/denormalized tables.
--
-- BASIC SYNTAX:
--   SELECT a.col, b.col
--   FROM table_a AS a
--   INNER JOIN table_b AS b
--       ON a.key = b.key;               -- the JOIN KEY(s)
--
-- EXAMPLE:
SELECT jp.job_id,
       jp.job_title,
       cd.name AS company_name           -- alias (jp, cd) keeps code short and clear
FROM job_postings AS jp
INNER JOIN company_dim AS cd
    ON jp.company_id = cd.company_id;
--
-- HOW TO THINK ABOUT IT:
--   "For every row of A, look for rows in B where ON is true; output each pair."
--   JOIN = INNER JOIN (INNER is optional).
--
-- COMMON MISTAKE:
--   Forgetting the ON condition (accidental CROSS JOIN) or joining on the
--   wrong column. Also: selecting a column that exists in both tables without
--   a prefix -> "ambiguous column" error.
--
-- PRACTICE:
--   Show job_id, job_country and company name only for Data Engineer postings.


------------------------------------------------
-- CONCEPT: LEFT JOIN
------------------------------------------------
-- WHAT IT MEANS:
--   Keep ALL rows from the LEFT table. If there is no match on the right,
--   right-side columns are NULL.
--
-- WHY A DATA ENGINEER USES IT:
--   The default join for enrichment: you never want to LOSE rows from your main
--   table just because a dimension lookup is missing.
--   Also used to find "missing" things (anti-join pattern).
--
-- BASIC SYNTAX:
--   FROM a LEFT JOIN b ON a.key = b.key
--
-- EXAMPLE 1: all companies, even those with zero postings
SELECT cd.name, COUNT(jp.job_id) AS n_postings      -- COUNT(right_col), not COUNT(*)
FROM company_dim AS cd
LEFT JOIN job_postings AS jp
    ON jp.company_id = cd.company_id
GROUP BY cd.name
ORDER BY n_postings DESC;

-- EXAMPLE 2 (anti-join): companies with NO postings
SELECT cd.company_id, cd.name
FROM company_dim AS cd
LEFT JOIN job_postings AS jp
    ON jp.company_id = cd.company_id
WHERE jp.job_id IS NULL;                -- "no match found on the right"
--
-- HOW TO THINK ABOUT IT:
--   Left table = the one you protect. Unmatched right columns become NULL.
--
-- COMMON MISTAKE:
--   Putting a filter on the RIGHT table in WHERE turns the LEFT JOIN into an
--   INNER JOIN (NULL rows get removed). Put right-table filters in the ON clause:
--     LEFT JOIN job_postings jp ON jp.company_id = cd.company_id AND jp.job_country = 'France'
--   COUNT(*) after a LEFT JOIN counts the NULL-extended row as 1 (use COUNT(right_key)).
--
-- PRACTICE:
--   List ALL skills and how many jobs require each (skills with zero jobs show 0).


------------------------------------------------
-- CONCEPT: RIGHT JOIN and FULL OUTER JOIN
------------------------------------------------
-- WHAT IT MEANS:
--   RIGHT JOIN      : keep all rows of the RIGHT table (mirror of LEFT JOIN).
--   FULL OUTER JOIN : keep ALL rows from BOTH sides, NULLs where no match.
--
-- WHY A DATA ENGINEER USES IT:
--   RIGHT JOIN is rare (just swap the table order and use LEFT).
--   FULL OUTER JOIN is great for RECONCILIATION: compare two tables
--   (source vs target) and see what exists on one side only.
--
-- BASIC SYNTAX:
--   FROM a RIGHT JOIN b ON ...        FROM a FULL OUTER JOIN b ON ...
--
-- EXAMPLE: companies vs. postings, nothing hidden on either side
SELECT cd.name, jp.job_id
FROM company_dim AS cd
FULL OUTER JOIN job_postings AS jp
    ON jp.company_id = cd.company_id
ORDER BY cd.name, jp.job_id;
--
-- HOW TO THINK ABOUT IT:
--   INNER = intersection. LEFT = all left + matches. FULL = union of both sides.
--
-- COMMON MISTAKE:
--   Using FULL JOIN where LEFT is enough; or forgetting NULLs appear on both sides.
--   [MySQL does not support FULL OUTER JOIN. PG and DuckDB do.]
--
-- PRACTICE:
--   Reconcile skills_dim and skills_job_dim: any skill never used? any job_id orphan?


------------------------------------------------
-- CONCEPT: CROSS JOIN
------------------------------------------------
-- WHAT IT MEANS:
--   Every row of A paired with every row of B (Cartesian product).
--   rows = rows(A) x rows(B).
--
-- WHY A DATA ENGINEER USES IT:
--   On purpose: build a complete grid (every country x every month) to find
--   missing combinations or to create a calendar spine.
--   By accident: it explodes row counts and can crash a pipeline.
--
-- BASIC SYNTAX:
--   FROM a CROSS JOIN b          -- no ON
--
-- EXAMPLE: grid of every country x every schedule type, then see which are missing
WITH countries AS (SELECT DISTINCT job_country FROM job_postings),
     schedules AS (SELECT DISTINCT job_schedule_type FROM job_postings)
SELECT c.job_country,
       s.job_schedule_type,
       COUNT(jp.job_id) AS n_postings
FROM countries AS c
CROSS JOIN schedules AS s
LEFT JOIN job_postings AS jp
       ON jp.job_country = c.job_country
      AND jp.job_schedule_type = s.job_schedule_type
GROUP BY c.job_country, s.job_schedule_type
ORDER BY c.job_country, s.job_schedule_type;
--
-- HOW TO THINK ABOUT IT:
--   3 countries x 3 schedule types = 9 rows. 1,000 x 1,000 = 1,000,000 rows!
--
-- COMMON MISTAKE:
--   Old-style  FROM a, b  (comma) with a forgotten WHERE = accidental CROSS JOIN.
--
-- PRACTICE:
--   Build the grid job_title_short x job_work_from_home (TRUE/FALSE) with counts.


------------------------------------------------
-- CONCEPT: SELF JOIN
------------------------------------------------
-- WHAT IT MEANS:
--   Joining a table to ITSELF using two different aliases.
--
-- WHY A DATA ENGINEER USES IT:
--   Comparing rows of the same table (employee/manager hierarchies, pairs of
--   events). Window functions (LAG/LEAD) often replace self joins in modern SQL.
--
-- BASIC SYNTAX:
--   FROM t AS a JOIN t AS b ON a.something = b.something AND a.id < b.id
--
-- EXAMPLE: pairs of postings from the same company, with their salary gap
SELECT a.job_id AS job_a,
       b.job_id AS job_b,
       a.company_id,
       b.salary_year_avg - a.salary_year_avg AS salary_gap
FROM job_postings AS a
JOIN job_postings AS b
  ON a.company_id = b.company_id
 AND a.job_id < b.job_id                -- avoids (1,1) and mirrored pairs (1,2)/(2,1)
WHERE a.salary_year_avg IS NOT NULL
  AND b.salary_year_avg IS NOT NULL
ORDER BY a.company_id, a.job_id, b.job_id;
--
-- HOW TO THINK ABOUT IT:
--   Imagine two copies of the same table. "a" and "b" are just labels.
--
-- COMMON MISTAKE:
--   Forgetting a.job_id < b.job_id -> every row paired with itself and duplicates.
--
-- PRACTICE:
--   For postings in the same country, list pairs where one posting is remote
--   and the other is not.


------------------------------------------------
-- CONCEPT: MANY-TO-MANY (bridge table) — JOINING THREE TABLES
------------------------------------------------
-- WHAT IT MEANS:
--   One job needs many skills, one skill is needed by many jobs.
--   The bridge table skills_job_dim stores one row per (job, skill) pair.
--
-- BASIC SYNTAX:
--   FROM job_postings jp
--   JOIN skills_job_dim sj ON sj.job_id = jp.job_id
--   JOIN skills_dim s      ON s.skill_id = sj.skill_id
--
-- EXAMPLE: top skills for Data Engineer postings
SELECT s.skills,
       COUNT(*) AS n_jobs
FROM job_postings    AS jp
JOIN skills_job_dim  AS sj ON sj.job_id   = jp.job_id
JOIN skills_dim      AS s  ON s.skill_id  = sj.skill_id
WHERE jp.job_title_short = 'Data Engineer'
GROUP BY s.skills
ORDER BY n_jobs DESC, s.skills;
--
-- PRACTICE:
--   Average salary per skill (skills only from jobs that have a salary).


------------------------------------------------
-- CONCEPT: GRAIN  +  HOW A JOIN MULTIPLIES ROWS   *** VERY IMPORTANT ***
------------------------------------------------
-- WHAT IT MEANS:
--   GRAIN = what ONE ROW of a table (or query result) represents.
--     job_postings    : one row = one job posting
--     skills_job_dim  : one row = one (job, skill) pair
--     company_dim     : one row = one company
--
-- WHY A DATA ENGINEER USES IT:
--   Before joining A to B ask: "What is the grain of each? What will the
--   grain of the result be?"
--   Joining a ONE-grain table to a MANY-grain table repeats the "one" side
--   once per matching "many" row.  Then SUM/COUNT over the repeated values
--   are WRONG (double counting). This is the most common silent bug in pipelines.
--
-- EXAMPLE: job 1 has 4 skills.  After joining skills, job 1 appears 4 TIMES.
SELECT COUNT(*) AS postings_rows FROM job_postings;                      -- 12

SELECT COUNT(*) AS rows_after_join                                       -- 27
FROM job_postings AS jp
JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id;

-- THE DAMAGE: total salary is inflated, because each salary is repeated per skill
SELECT SUM(salary_year_avg) AS correct_total FROM job_postings;

SELECT SUM(jp.salary_year_avg) AS inflated_total
FROM job_postings AS jp
JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id;

-- ALSO: an INNER JOIN silently DROPPED job 6 (it has no skills) -> lost rows.
-- Compare distinct jobs before/after:
SELECT COUNT(DISTINCT jp.job_id) AS jobs_after_inner_join
FROM job_postings AS jp
JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id;                      -- 11, not 12

-- FIX PATTERN 1: aggregate the "many" side to the grain of the "one" side BEFORE joining
WITH skills_per_job AS (
    SELECT job_id, COUNT(*) AS n_skills        -- grain: one row per job_id
    FROM skills_job_dim
    GROUP BY job_id
)
SELECT jp.job_id,
       jp.salary_year_avg,
       COALESCE(spj.n_skills, 0) AS n_skills   -- LEFT JOIN keeps job 6
FROM job_postings AS jp
LEFT JOIN skills_per_job AS spj ON spj.job_id = jp.job_id;

-- FIX PATTERN 2: if you need skill-level analysis, accept the skill grain and
-- do not SUM job-level measures at that grain (count DISTINCT jobs instead).
--
-- DEFENSIVE CHECKS BEFORE/AFTER EVERY JOIN:
--   (a) row count before vs after
--   (b) is the join key UNIQUE on the side that should be "one"?
--         SELECT company_id, COUNT(*) FROM company_dim GROUP BY 1 HAVING COUNT(*) > 1;
--   (c) COUNT(*) vs COUNT(DISTINCT key)
--
-- COMMON MISTAKE:
--   Adding DISTINCT to "fix" duplicate rows. It hides the problem and may
--   remove legitimately repeated rows. Find the cause (the grain) instead.
--
-- PRACTICE:
--   Write the grain of each of these results in a comment:
--     (1) job_postings JOIN company_dim
--     (2) job_postings JOIN skills_job_dim
--     (3) job_postings JOIN skills_job_dim JOIN skills_dim, grouped by skills


-- ==========================================================================
-- PART 5 — CASE EXPRESSIONS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: CASE (searched and simple)
------------------------------------------------
-- WHAT IT MEANS:
--   SQL's if / else-if / else. Returns ONE value per row.
--   Conditions are checked top to bottom; the FIRST true one wins.
--   No ELSE and no match -> NULL.
--
-- WHY A DATA ENGINEER USES IT:
--   Categorizing, standardizing codes, handling missing values, and building
--   conditional metrics during transformation (the "T" in ETL/ELT).
--
-- BASIC SYNTAX:
--   -- Searched CASE (any condition):
--   CASE WHEN condition1 THEN value1
--        WHEN condition2 THEN value2
--        ELSE default_value
--   END
--   -- Simple CASE (compare ONE expression to equal values):
--   CASE expression WHEN 'a' THEN 1 WHEN 'b' THEN 2 ELSE 0 END
--
-- EXAMPLE 1: searched CASE for CATEGORIZATION (salary bands)
SELECT job_id,
       salary_year_avg,
       CASE
           WHEN salary_year_avg IS NULL    THEN 'Unknown'      -- handle NULL FIRST
           WHEN salary_year_avg >= 140000  THEN 'High'
           WHEN salary_year_avg >= 100000  THEN 'Mid'
           ELSE 'Low'
       END AS salary_band
FROM job_postings;

-- EXAMPLE 2: simple CASE for DATA TRANSFORMATION (code -> label)
SELECT job_id,
       job_schedule_type,
       CASE job_schedule_type
           WHEN 'Full-time'  THEN 'FT'
           WHEN 'Part-time'  THEN 'PT'
           WHEN 'Contractor' THEN 'CTR'
           ELSE 'OTHER'
       END AS schedule_code
FROM job_postings;

-- EXAMPLE 3: CASE with NULL — why order matters
--   WHEN salary_year_avg < 100000 would be UNKNOWN for NULL salaries, so those
--   rows would fall to ELSE and be mislabelled 'Mid/High'. Always test IS NULL first.
SELECT job_id,
       CASE WHEN salary_year_avg IS NULL THEN 'no salary'
            WHEN salary_year_avg < 100000 THEN 'below 100k'
            ELSE '100k+'
       END AS check_low
FROM job_postings;

-- EXAMPLE 4: CASE for CONDITIONAL AGGREGATION (pivot-like summary in one pass)
SELECT job_country,
       COUNT(*)                                                   AS n_postings,
       COUNT(CASE WHEN job_work_from_home THEN 1 END)             AS n_remote,   -- COUNT ignores NULL (no ELSE)
       SUM(CASE WHEN job_work_from_home THEN 0 ELSE 1 END)        AS n_onsite,
       ROUND(AVG(CASE WHEN job_title_short = 'Data Engineer'
                      THEN salary_year_avg END), 0)               AS avg_salary_de   -- NULL for others -> ignored by AVG
FROM job_postings
GROUP BY job_country;

-- [PG] and [DUCKDB] shortcut for conditional aggregation: FILTER
SELECT job_country,
       COUNT(*) FILTER (WHERE job_work_from_home) AS n_remote
FROM job_postings
GROUP BY job_country;
--
-- HOW TO THINK ABOUT IT:
--   CASE is a row-by-row translator. Inside an aggregate it becomes a
--   "count/sum only the rows I care about" switch.
--
-- COMMON MISTAKES:
--   * Forgetting END.
--   * Mixing result types (THEN 1 ... ELSE 'x') -> type error.
--   * Forgetting that no ELSE returns NULL.
--   * Putting the broad condition before the specific one (first match wins!).
--
-- PRACTICE:
--   Label postings 'Remote' / 'On-site' using job_work_from_home, then count each.


-- ==========================================================================
-- PART 6 — NULL AND TEXT FUNCTIONS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: NULL is NOT 0 and NOT ''  (+ COALESCE, NULLIF)
------------------------------------------------
-- WHAT IT MEANS:
--   NULL  = unknown/missing.   0 = the number zero.   '' = an empty text.
--   Salary NULL = "we don't know"; salary 0 = "it pays nothing". Very different!
--
-- WHY A DATA ENGINEER USES IT:
--   Each NULL needs a decision: keep as NULL, replace with a default, or reject
--   the row. Replacing NULL with 0 can corrupt averages.
--
-- BASIC SYNTAX:
--   COALESCE(a, b, c)   -> first NON-NULL value among the arguments
--   NULLIF(a, b)        -> NULL if a = b, otherwise a   (turns "bad values" into NULL)
--
-- EXAMPLE 1: the 0 vs NULL trap with AVG
SELECT AVG(salary_year_avg)                     AS avg_ignoring_nulls,   -- honest
       AVG(COALESCE(salary_year_avg, 0))        AS avg_nulls_as_zero     -- WRONG: pulled down
FROM job_postings;

-- EXAMPLE 2: COALESCE for display / defaults
SELECT job_id,
       COALESCE(salary_year_avg, 0)  AS salary_or_zero,                  -- numeric default
       COALESCE(job_schedule_type, 'Unknown') AS schedule_clean
FROM job_postings;

-- EXAMPLE 3: NULLIF to avoid division by zero (and to convert '' to NULL)
SELECT job_country,
       COUNT(CASE WHEN job_work_from_home THEN 1 END) * 1.0
         / NULLIF(COUNT(*), 0) AS remote_share            -- NULLIF(0,0) = NULL, no crash
FROM job_postings
GROUP BY job_country;

-- EXAMPLE 4: empty string vs NULL
SELECT NULLIF('', '')       AS empty_becomes_null,        -- NULL
       COALESCE(NULL, '')   AS null_becomes_empty;        -- ''
--
-- HOW TO THINK ABOUT IT:
--   COALESCE = "plan A, else plan B, else plan C".
--   NULLIF   = "if it's this junk value, treat it as missing".
--
-- COMMON MISTAKE:
--   Filling NULL with 0 before averaging; comparing with = NULL; forgetting that
--   NULL + 5 = NULL and NULL || 'text' = NULL.
--
-- PRACTICE:
--   Show job_id and salary as text, using 'not disclosed' when NULL (cast first!).


------------------------------------------------
-- CONCEPT: TEXT FUNCTIONS  (LOWER UPPER TRIM LENGTH SUBSTRING REPLACE CONCAT)
------------------------------------------------
-- WHAT IT MEANS:
--   Functions that clean and reshape text values.
--
-- WHY A DATA ENGINEER USES IT:
--   Raw data is messy: extra spaces, mixed case, inconsistent labels.
--   Standardizing text BEFORE joins/grouping is essential: 'France' and
--   'france ' would otherwise be different groups and different join keys.
--
-- BASIC SYNTAX:
--   LOWER(x)  UPPER(x)  TRIM(x)  LTRIM(x)  RTRIM(x)
--   LENGTH(x)                         -- number of characters
--   SUBSTRING(x, start, length)       -- start is 1-based. [PG] also: SUBSTRING(x FROM 1 FOR 4)
--   REPLACE(x, 'old', 'new')
--   CONCAT(a, b, ...)                 -- NULL treated as '' in PG and DuckDB
--   a || b                            -- NULL if either side is NULL
--
-- EXAMPLE 1: spot dirty values
SELECT job_id,
       job_title,
       LENGTH(job_title)         AS len_raw,
       LENGTH(TRIM(job_title))   AS len_trimmed         -- different => hidden spaces
FROM job_postings
WHERE LENGTH(job_title) <> LENGTH(TRIM(job_title));

-- EXAMPLE 2: standardize a text column (TRIM + LOWER, composed)
SELECT job_id,
       LOWER(TRIM(job_title)) AS job_title_clean
FROM job_postings
ORDER BY job_id;

-- EXAMPLE 3: show why cleaning matters for grouping
SELECT COUNT(DISTINCT job_title)                  AS distinct_raw,
       COUNT(DISTINCT LOWER(TRIM(job_title)))     AS distinct_clean
FROM job_postings;

-- EXAMPLE 4: substring / replace / concat
SELECT job_id,
       SUBSTRING(job_title, 1, 4)                         AS first_4_chars,
       REPLACE(LOWER(TRIM(job_title)), ' ', '_')          AS title_slug,
       CONCAT(job_title_short, ' - ', job_country)        AS label,
       job_title_short || ' - ' || job_country            AS label_pipes
FROM job_postings;

-- EXAMPLE 5: simple "data cleaning" step combining everything
SELECT job_id,
       COALESCE(NULLIF(TRIM(job_title), ''), 'Unknown')   AS job_title_clean,
       UPPER(job_country)                                 AS country_code_like
FROM job_postings;
--
-- HOW TO THINK ABOUT IT:
--   Clean text FIRST, join/group SECOND.
--
-- COMMON MISTAKES:
--   * SUBSTRING index starts at 1 (not 0 like Python).
--   * LENGTH counts characters in DuckDB/PG; some engines count bytes (use CHAR_LENGTH).
--   * Forgetting TRIM before JOIN keys: 'abc ' <> 'abc' silently drops matches.
--   * Using || with a NULL and losing the whole string.
--
-- PRACTICE:
--   Build a column 'DE_TITLE_FLAG' that is TRUE when the cleaned title contains
--   the word 'engineer' (any case, any spaces).


-- ==========================================================================
-- PART 7 — DATE FUNCTIONS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: DATE vs TIMESTAMP, extracting parts
------------------------------------------------
-- WHAT IT MEANS:
--   DATE      : calendar day only            2025-03-15
--   TIMESTAMP : date + time of day           2025-03-15 13:10:00
--   (TIMESTAMPTZ / TIMESTAMP WITH TIME ZONE also stores the time zone context.)
--
-- WHY A DATA ENGINEER USES IT:
--   Time is the backbone of pipelines: incremental loads, partitions,
--   monthly aggregates, SLA checks, time-series windows (PART 14).
--
-- BASIC SYNTAX:
--   CAST(ts AS DATE)  or  ts::DATE            -- timestamp -> date  ([PG] and [DUCKDB])
--   EXTRACT(YEAR FROM ts)   EXTRACT(MONTH FROM ts)   EXTRACT(DAY FROM ts)
--   [DUCKDB] also: year(ts), month(ts), day(ts), dayname(ts), date_part('year', ts)
--
-- EXAMPLE:
SELECT job_id,
       job_posted_date,
       CAST(job_posted_date AS DATE)       AS posted_day,
       EXTRACT(YEAR  FROM job_posted_date) AS posted_year,
       EXTRACT(MONTH FROM job_posted_date) AS posted_month,
       EXTRACT(DAY   FROM job_posted_date) AS posted_day_of_month
FROM job_postings
ORDER BY job_id;
--
-- HOW TO THINK ABOUT IT:
--   Convert/extract to the precision you need. Grouping by TIMESTAMP gives one
--   group per second — almost never what you want. Group by DATE or month.
--
-- COMMON MISTAKE:
--   Comparing a TIMESTAMP with a DATE string and forgetting the time part.
--
-- PRACTICE:
--   Count postings per weekday (hint: DuckDB dayname(job_posted_date)).


------------------------------------------------
-- CONCEPT: DATE FILTERING  (the safe half-open range pattern)
------------------------------------------------
-- WHAT IT MEANS:
--   Filter a timestamp column using  >= start  AND  < next_start.
--
-- WHY A DATA ENGINEER USES IT:
--   Incremental loads ("rows since the last run") and partition pruning.
--   The half-open range never misses the last day's time-of-day values.
--
-- BASIC SYNTAX:
--   WHERE ts >= '2025-03-01' AND ts < '2025-04-01'
--
-- EXAMPLE: all of March 2025
SELECT job_id, job_posted_date
FROM job_postings
WHERE job_posted_date >= '2025-03-01'
  AND job_posted_date <  '2025-04-01';
--
-- HOW TO THINK ABOUT IT:
--   Start included, end excluded. Works for month, week, day, year alike.
--
-- COMMON MISTAKE:
--   BETWEEN '2025-03-01' AND '2025-03-31'  -> misses 2025-03-31 10:00 because
--   '2025-03-31' means 2025-03-31 00:00:00.
--
-- PRACTICE:
--   Postings from Q2 2025 (April through June).


------------------------------------------------
-- CONCEPT: DATE ARITHMETIC and DIFFERENCES
------------------------------------------------
-- WHAT IT MEANS:
--   Add/subtract intervals; compute the gap between two dates.
--
-- WHY A DATA ENGINEER USES IT:
--   Data freshness ("how old is this record?"), retention windows,
--   lag between events, SLA monitoring.
--
-- BASIC SYNTAX:
--   ts + INTERVAL '7 days'          ts - INTERVAL '1 month'     (works in both engines)
--   date_b - date_a                 -> integer number of days for DATEs  ([PG] and [DUCKDB])
--   [DUCKDB]  date_diff('day', a, b)       date_sub('day', a, b)
--   [PG]      AGE(b, a)  returns an interval;  (b::date - a::date) gives days
--   [PG]      timestamp - timestamp = INTERVAL (not a number!) -> cast to DATE first
--
-- EXAMPLE:
SELECT job_id,
       CAST(job_posted_date AS DATE)                              AS posted_day,
       CAST(job_posted_date AS DATE) + INTERVAL '30 days'         AS expires_day,   -- becomes TIMESTAMP in DuckDB
       DATE '2025-06-01' - CAST(job_posted_date AS DATE)          AS days_old       -- integer days
FROM job_postings
ORDER BY job_id;
--
-- HOW TO THINK ABOUT IT:
--   Use a FIXED reference date (not CURRENT_DATE) in practice notebooks so
--   results stay reproducible. In pipelines, pass the run date as a parameter.
--
-- COMMON MISTAKE:
--   Assuming timestamp - timestamp returns days. It returns an interval.
--
-- PRACTICE:
--   For each posting, compute days between posting date and 2025-12-31.


------------------------------------------------
-- CONCEPT: DATE TRUNCATION
------------------------------------------------
-- WHAT IT MEANS:
--   Rounds a date/timestamp DOWN to the start of a period (day, week, month...).
--
-- WHY A DATA ENGINEER USES IT:
--   The standard way to build monthly/weekly rollups and time-series buckets.
--
-- BASIC SYNTAX:
--   DATE_TRUNC('month', ts)         -- [PG] and [DUCKDB]
--
-- EXAMPLE: postings per month
SELECT DATE_TRUNC('month', job_posted_date) AS posted_month,
       COUNT(*)                             AS n_postings
FROM job_postings
GROUP BY DATE_TRUNC('month', job_posted_date)
ORDER BY posted_month;
--
-- HOW TO THINK ABOUT IT:
--   2025-03-15 13:10 -> truncated to month -> 2025-03-01 00:00. All March rows
--   share the same bucket, so GROUP BY works.
--
-- COMMON MISTAKE:
--   Using EXTRACT(MONTH ...) alone: Jan 2025 and Jan 2026 would merge together.
--   Always include the year (or use DATE_TRUNC).
--
-- PRACTICE:
--   Average salary per month.


------------------------------------------------
-- CONCEPT: CONVERTING TEXT TO DATES
------------------------------------------------
-- WHAT IT MEANS:
--   Raw files often store dates as text. Convert them into real DATE/TIMESTAMP.
--
-- WHY A DATA ENGINEER USES IT:
--   Casting is a core STAGING step. Text dates sort wrongly ('10/01/2025' < '2/01/2025')
--   and cannot be used with date functions.
--
-- BASIC SYNTAX:
--   CAST('2025-03-15' AS DATE)                -- ISO format YYYY-MM-DD works everywhere
--   [PG]     TO_DATE('15/03/2025', 'DD/MM/YYYY')   TO_TIMESTAMP(text, format)
--   [DUCKDB] STRPTIME('15/03/2025', '%d/%m/%Y')    -- returns TIMESTAMP
--   [DUCKDB] TRY_CAST(x AS DATE)              -- NULL instead of an error on bad values
--
-- EXAMPLE:
SELECT CAST('2025-03-15' AS DATE)                    AS iso_date,
       CAST(STRPTIME('15/03/2025', '%d/%m/%Y') AS DATE) AS from_european_text,   -- [DUCKDB]
       TRY_CAST('not a date' AS DATE)                AS bad_value_becomes_null;
--
-- HOW TO THINK ABOUT IT:
--   Decide in staging what happens to bad values: fail loudly, or become NULL
--   and be counted in a data-quality report.
--
-- COMMON MISTAKE:
--   Day/month confusion: is '03/04/2025' March 4th or April 3rd? Always specify
--   the format explicitly.
--
-- PRACTICE:
--   Convert '2025-07-04 18:30:00' to a TIMESTAMP and extract the hour.


-- ==========================================================================
-- PART 8 — SUBQUERIES
-- ==========================================================================

------------------------------------------------
-- CONCEPT: WHAT A SUBQUERY IS  (scalar, IN, FROM, correlated, EXISTS)
------------------------------------------------
-- WHAT IT MEANS:
--   A SELECT nested inside another query, wrapped in parentheses.
--   Types:
--     SCALAR      : returns ONE value (1 row, 1 column) -> use like a number
--     LIST        : returns ONE column -> use with IN
--     TABLE       : in FROM, acts like a temporary table (needs an alias)
--     CORRELATED  : refers to the outer query's current row; runs "per row" logically
--
-- WHY A DATA ENGINEER USES IT:
--   Break a problem in two: "first compute X, then use X".
--
-- EXAMPLE 1: SCALAR subquery in WHERE — postings paid above the overall average
SELECT job_id, salary_year_avg
FROM job_postings
WHERE salary_year_avg > (SELECT AVG(salary_year_avg) FROM job_postings)
ORDER BY salary_year_avg DESC;

-- EXAMPLE 2: subquery with IN — postings of companies that have a posting >= 150000
SELECT job_id, company_id, job_title
FROM job_postings
WHERE company_id IN (SELECT company_id
                     FROM job_postings
                     WHERE salary_year_avg >= 150000);

-- EXAMPLE 3: subquery in FROM — average of the per-company averages
SELECT AVG(company_avg) AS avg_of_company_avgs
FROM (
    SELECT company_id, AVG(salary_year_avg) AS company_avg
    FROM job_postings
    GROUP BY company_id
) AS company_stats;                      -- alias is REQUIRED in PG

-- EXAMPLE 4: CORRELATED subquery — postings paid above THEIR OWN company's average
SELECT jp.job_id, jp.company_id, jp.salary_year_avg
FROM job_postings AS jp
WHERE jp.salary_year_avg > (
        SELECT AVG(x.salary_year_avg)
        FROM job_postings AS x
        WHERE x.company_id = jp.company_id        -- <- refers to the OUTER row
      );
-- (A window function does this more simply and usually faster: PART 14)

-- EXAMPLE 5: EXISTS — companies with at least one remote posting
SELECT cd.name
FROM company_dim AS cd
WHERE EXISTS (SELECT 1
              FROM job_postings AS jp
              WHERE jp.company_id = cd.company_id
                AND jp.job_work_from_home);

-- EXAMPLE 6: NOT EXISTS — safe anti-join (companies with no postings)
SELECT cd.name
FROM company_dim AS cd
WHERE NOT EXISTS (SELECT 1 FROM job_postings AS jp WHERE jp.company_id = cd.company_id);
--
-- HOW TO THINK ABOUT IT:
--   Work from the inside out: run the inner query alone first, check it, then wrap it.
--
-- WHEN A CTE IS EASIER:
--   * the same subquery is needed twice
--   * you have 2+ levels of nesting
--   * you want to name each step so a reader understands the intent
--   -> Write it as WITH ... (PART 9). Same result, much more readable.
--
-- COMMON MISTAKES:
--   * Scalar subquery returning more than one row -> error.
--   * Forgetting the alias on a FROM subquery.
--   * NOT IN (subquery containing NULL) returns nothing; use NOT EXISTS.
--
-- PRACTICE:
--   List postings whose salary is above the average salary of THEIR country
--   (correlated subquery version).


-- ==========================================================================
-- PART 9 — CTEs (COMMON TABLE EXPRESSIONS)
-- ==========================================================================

------------------------------------------------
-- CONCEPT: WITH (CTE)
------------------------------------------------
-- WHAT IT MEANS:
--   A named temporary result, defined at the top of a query with WITH,
--   that exists only for that query. Think of it as a labelled step.
--
-- WHY A DATA ENGINEER USES IT:
--   Real transformations have many steps. CTEs let you write them as a PIPELINE:
--
--        STEP 1  ->  STEP 2  ->  STEP 3  ->  FINAL RESULT
--        (clean)     (enrich)    (aggregate)  (SELECT ... FROM step3)
--
--   Each step is small, testable (SELECT * FROM step_n) and readable.
--   This mirrors dbt models and ETL stages.
--
-- BASIC SYNTAX:
--   WITH step1 AS (SELECT ...),
--        step2 AS (SELECT ... FROM step1 ...),
--        step3 AS (SELECT ... FROM step2 ...)
--   SELECT * FROM step3;
--
-- EXAMPLE 1: ONE CTE used for transformation (cleaning)
WITH clean_postings AS (
    SELECT job_id,
           company_id,
           LOWER(TRIM(job_title))                 AS job_title_clean,
           job_country,
           CAST(job_posted_date AS DATE)          AS posted_day,
           salary_year_avg
    FROM job_postings
)
SELECT *
FROM clean_postings
WHERE job_title_clean LIKE '%data engineer%';

-- EXAMPLE 2: MULTIPLE CTEs — clean -> aggregate -> final
WITH clean_postings AS (                                     -- STEP 1
    SELECT job_id, company_id, job_country,
           DATE_TRUNC('month', job_posted_date) AS posted_month,
           salary_year_avg
    FROM job_postings
),
monthly_summary AS (                                         -- STEP 2 (aggregation)
    SELECT posted_month,
           COUNT(*)                     AS n_postings,
           ROUND(AVG(salary_year_avg),0) AS avg_salary
    FROM clean_postings
    GROUP BY posted_month
)
SELECT *                                                     -- FINAL RESULT
FROM monthly_summary
ORDER BY posted_month;

-- EXAMPLE 3: CTE USED BEFORE A JOIN — fix the grain first, join second
WITH jobs_per_skill AS (                                     -- grain: one row per skill_id
    SELECT skill_id, COUNT(*) AS n_jobs
    FROM skills_job_dim
    GROUP BY skill_id
)
SELECT s.skills, COALESCE(j.n_jobs, 0) AS n_jobs
FROM skills_dim AS s
LEFT JOIN jobs_per_skill AS j ON j.skill_id = s.skill_id
ORDER BY n_jobs DESC, s.skills;

-- EXAMPLE 4: CTE TO MAKE COMPLEX SQL READABLE
--   Question: "Per company: postings, share of remote postings, and salary vs. overall average"
WITH company_metrics AS (
    SELECT company_id,
           COUNT(*)                                        AS n_postings,
           AVG(CASE WHEN job_work_from_home THEN 1.0 ELSE 0.0 END) AS remote_share,
           AVG(salary_year_avg)                            AS avg_salary
    FROM job_postings
    GROUP BY company_id
),
overall AS (
    SELECT AVG(salary_year_avg) AS overall_avg_salary FROM job_postings
)
SELECT cd.name,
       cm.n_postings,
       ROUND(cm.remote_share, 2)                         AS remote_share,
       ROUND(cm.avg_salary - o.overall_avg_salary, 0)    AS salary_vs_overall
FROM company_metrics AS cm
JOIN company_dim AS cd ON cd.company_id = cm.company_id
CROSS JOIN overall AS o                       -- 1-row table: safe CROSS JOIN
ORDER BY cm.n_postings DESC;
--
-- HOW TO THINK ABOUT IT:
--   Each CTE = one small question. Name it after the grain it produces
--   (jobs_per_skill, monthly_summary). Test each step alone.
--
-- GOOD TO KNOW:
--   * CTEs can reference earlier CTEs, not later ones.
--   * [PG 12+] CTEs are inlined by default; MATERIALIZED / NOT MATERIALIZED hints exist.
--   * WITH RECURSIVE exists for hierarchies (org charts, graphs) - later topic.
--   * A CTE is NOT stored: it vanishes after the query. To keep results, use
--     CREATE TABLE ... AS or CREATE VIEW (PART 12).
--
-- COMMON MISTAKES:
--   * Forgetting the comma between CTEs (no comma before the final SELECT!).
--   * Nesting CTE names that clash with table names.
--   * Building a 12-CTE monster without testing intermediate steps.
--
-- PRACTICE:
--   Step 1: clean titles. Step 2: count postings per cleaned title. Step 3: keep
--   titles with 2+ postings. Return the final list.


-- ==========================================================================
-- PART 10 — SET OPERATORS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: UNION / UNION ALL / INTERSECT / EXCEPT
------------------------------------------------
-- WHAT IT MEANS:
--   Combine the results of two SELECTs VERTICALLY (stack rows), unlike JOIN which
--   combines horizontally (adds columns).
--   RULES: same number of columns, compatible types, column names come from the first query.
--
--   UNION      : stack, then REMOVE duplicates   (slower: needs a dedup step)
--   UNION ALL  : stack, KEEP everything          (faster, preserves row counts)
--   INTERSECT  : only rows that appear in BOTH
--   EXCEPT     : rows in the first result that are NOT in the second
--                [Oracle calls it MINUS]
--
-- WHY A DATA ENGINEER USES IT:
--   * UNION ALL: append monthly files / partitions / sources into one table.
--   * INTERSECT / EXCEPT: compare two tables (what's new? what disappeared?).
--
-- EXAMPLE 1: UNION vs UNION ALL — the difference that matters
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Engineer'
UNION ALL
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Analyst';
--   -> keeps every row (duplicates stay)

SELECT job_country FROM job_postings WHERE job_title_short = 'Data Engineer'
UNION
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Analyst';
--   -> unique countries only (duplicates removed)

-- EXAMPLE 2: INTERSECT — countries that have BOTH a Data Engineer and a Data Analyst posting
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Engineer'
INTERSECT
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Analyst';

-- EXAMPLE 3: EXCEPT — countries with Data Engineer postings but NO Data Scientist postings
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Engineer'
EXCEPT
SELECT job_country FROM job_postings WHERE job_title_short = 'Data Scientist';

-- EXAMPLE 4: pipeline use — append two "monthly files" with UNION ALL
WITH jan AS (SELECT * FROM job_postings WHERE job_posted_date < '2025-02-01'),
     feb AS (SELECT * FROM job_postings WHERE job_posted_date >= '2025-02-01' AND job_posted_date < '2025-03-01')
SELECT COUNT(*) AS rows_appended FROM (SELECT * FROM jan UNION ALL SELECT * FROM feb) AS combined;
--
-- HOW TO THINK ABOUT IT:
--   UNION ALL = "paste one under the other".  UNION = "paste, then dedupe".
--   DEFAULT CHOICE in ETL: UNION ALL (fast, honest). Use UNION only when you
--   truly want deduplication - and know what "duplicate" means (all columns equal).
--
-- COMMON MISTAKES:
--   * Using UNION when you meant UNION ALL -> silently lose rows + slower.
--   * Columns in different ORDER (matching is by position, not name!).
--   * ORDER BY only once, at the very end.
--
-- PRACTICE:
--   Which job_titles (cleaned) appear in France but not in the United States?


-- ==========================================================================
-- PART 11 — DATA TYPES
-- ==========================================================================

------------------------------------------------
-- CONCEPT: IMPORTANT DATA TYPES and WHY THEY MATTER IN ETL/ELT
------------------------------------------------
-- WHAT IT MEANS:
--   Every column has a type that decides what values it can store and how they behave.
--
--   INTEGER            whole numbers (about +/- 2.1 billion)          counts, small ids
--   BIGINT             large whole numbers (about +/- 9.2 x 10^18)    big ids, event counts
--   DECIMAL(p,s) / NUMERIC  exact decimals. p = total digits, s = digits after the point
--                      MONEY, salaries, anything needing exactness
--   FLOAT / DOUBLE     approximate decimals (binary floating point)   measurements, ML scores
--   VARCHAR / TEXT     text                                          names, titles, codes
--   BOOLEAN            TRUE / FALSE / NULL                           flags
--   DATE               calendar day
--   TIMESTAMP          date + time (TIMESTAMPTZ if time zone matters)
--
-- WHY A DATA ENGINEER USES IT:
--   * Wrong type = wrong results: text '10' sorts before '9'.
--   * Floating point cannot store 0.1 exactly -> use DECIMAL for money.
--   * INTEGER overflow can crash loads when ids/volumes grow -> BIGINT for surrogate keys.
--   * Integer division surprise: 7/2 may return 3 in PG (integer) but 3.5 in DuckDB.
--   * Smaller/right types = less storage and faster scans.
--   * In pipelines: RAW layer = often all text; STAGING layer = CAST to correct types.
--
-- BASIC SYNTAX:
--   CAST(value AS type)        value::type            TRY_CAST(value AS type) [DUCKDB]
--   typeof(x) [DUCKDB]         pg_typeof(x) [PG]
--
-- EXAMPLE 1: inspect types
SELECT typeof(1)                       AS int_type,
       typeof(1.5)                     AS decimal_type,
       typeof(1.5::DOUBLE)             AS double_type,
       typeof('abc')                   AS text_type,
       typeof(TRUE)                    AS bool_type,
       typeof(DATE '2025-01-01')       AS date_type;

-- EXAMPLE 2: exact vs approximate numbers
SELECT 0.1::DOUBLE + 0.2::DOUBLE = 0.3::DOUBLE      AS double_equal,    -- FALSE (!)
       0.1::DECIMAL(3,1) + 0.2::DECIMAL(3,1) = 0.3::DECIMAL(3,1) AS decimal_equal;   -- TRUE

-- EXAMPLE 3: text vs number sorting
SELECT x FROM (VALUES ('10'), ('9'), ('100')) AS t(x) ORDER BY x;                 -- text order: 10, 100, 9
SELECT CAST(x AS INTEGER) AS x FROM (VALUES ('10'), ('9'), ('100')) AS t(x) ORDER BY 1;   -- numeric order

-- EXAMPLE 4: integer division — make one side decimal to be safe
SELECT 7 / 2          AS maybe_integer_division,   -- [DUCKDB] 3.5 ; [PG] 3
       7 * 1.0 / 2    AS always_decimal,           -- 3.5 in both
       7 // 2         AS duckdb_int_division;      -- [DUCKDB] 3 (use  7 / 2  in PG)

-- EXAMPLE 5: a failed cast and the safe alternative
--   SELECT CAST('abc' AS INTEGER);      -- ERROR: pipeline stops
SELECT TRY_CAST('abc' AS INTEGER) AS safe_result;   -- NULL  ([PG] has no TRY_CAST; use regex check + CASE)
--
-- HOW TO THINK ABOUT IT:
--   Decide types at the STAGING step. Everything downstream trusts them.
--
-- COMMON MISTAKES:
--   * Storing dates as text.  * Storing money as FLOAT.
--   * Joining text key to integer key (implicit cast = slow / wrong).
--   * Assuming BOOLEAN works the same everywhere (some engines use 0/1).
--
-- PRACTICE:
--   Cast salary_year_avg to INTEGER and to DOUBLE. Which values change?


-- ==========================================================================
-- PART 12 — DDL AND DML
-- ==========================================================================

------------------------------------------------
-- CONCEPT: SELECT = QUERYING (reads), DDL = STRUCTURE, DML = ROWS
------------------------------------------------
-- WHAT IT MEANS:
--   Querying (DQL): SELECT                  -> reads, changes nothing
--   DDL (Data Definition Language)          -> changes STRUCTURE
--       CREATE (build)  ALTER (modify)  DROP (delete object)  TRUNCATE (empty a table)
--   DML (Data Manipulation Language)        -> changes ROWS
--       INSERT (add)    UPDATE (modify)  DELETE (remove)
--
-- WHY A DATA ENGINEER USES IT:
--   Pipelines CREATE tables, INSERT loaded data, UPDATE/DELETE corrections,
--   and DROP/TRUNCATE temporary or staging data.
--
-- We use a separate table (practice_jobs) so our main tables stay untouched.

-- CREATE TABLE: define columns, types, and constraints
DROP TABLE IF EXISTS practice_jobs;
CREATE TABLE practice_jobs (
    job_id       INTEGER PRIMARY KEY,                 -- unique + not null
    job_title    VARCHAR NOT NULL,                    -- must have a value
    country      VARCHAR,
    salary       DECIMAL(10,2) CHECK (salary >= 0),   -- rule: no negative salaries
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- filled automatically
);

-- INSERT: add rows (always list the columns explicitly!)
INSERT INTO practice_jobs (job_id, job_title, country, salary)
VALUES (1, 'Data Engineer', 'France', 100000),
       (2, 'Data Analyst',  'Germany', 70000),
       (3, 'Data Scientist', NULL,     NULL);

-- INSERT ... SELECT: copy rows from another query (the real ETL workhorse)
INSERT INTO practice_jobs (job_id, job_title, country, salary)
SELECT job_id + 100, job_title, job_country, salary_year_avg
FROM job_postings
WHERE job_country = 'Germany';

SELECT * FROM practice_jobs ORDER BY job_id;

-- UPDATE: modify existing rows.  ALWAYS test the WHERE with a SELECT first.
SELECT * FROM practice_jobs WHERE job_id = 2;                      -- 1) look
UPDATE practice_jobs SET salary = 75000 WHERE job_id = 2;          -- 2) change
SELECT * FROM practice_jobs WHERE job_id = 2;                      -- 3) verify

-- DELETE: remove rows. Same discipline.
SELECT * FROM practice_jobs WHERE country IS NULL;
DELETE FROM practice_jobs WHERE country IS NULL;

-- ALTER: change structure
ALTER TABLE practice_jobs ADD COLUMN source_system VARCHAR;
UPDATE practice_jobs SET source_system = 'manual_demo';
ALTER TABLE practice_jobs DROP COLUMN source_system;
-- [PG]/[DUCKDB]: ALTER TABLE t RENAME COLUMN a TO b;    ALTER TABLE t ALTER COLUMN x TYPE BIGINT;  -- ([DUCKDB] also supports this form)

-- CREATE TABLE AS SELECT (CTAS): build a table from a query result
DROP TABLE IF EXISTS practice_country_summary;
CREATE TABLE practice_country_summary AS
SELECT job_country, COUNT(*) AS n_postings, ROUND(AVG(salary_year_avg),0) AS avg_salary
FROM job_postings
GROUP BY job_country;

-- VIEW: a saved query (no data stored, always fresh)
CREATE OR REPLACE VIEW practice_de_jobs AS
SELECT job_id, job_title, job_country FROM job_postings WHERE job_title_short = 'Data Engineer';

-- UPSERT: insert, or update if the key already exists  ([PG] and [DUCKDB])
INSERT INTO practice_jobs (job_id, job_title, country, salary)
VALUES (1, 'Senior Data Engineer', 'France', 110000)
ON CONFLICT (job_id) DO UPDATE SET job_title = EXCLUDED.job_title,
                                   salary    = EXCLUDED.salary;

-- TRANSACTION: group changes; undo them if something looks wrong
BEGIN TRANSACTION;                       -- [PG]: BEGIN;
DELETE FROM practice_jobs;               -- dangerous? we can still undo
SELECT COUNT(*) AS rows_inside_transaction FROM practice_jobs;   -- 0
ROLLBACK;                                -- undo!  (COMMIT would make it permanent)
SELECT COUNT(*) AS rows_after_rollback FROM practice_jobs;       -- back to normal

-- TRUNCATE vs DELETE vs DROP
--   DELETE FROM t;     remove rows (can have WHERE); logged row by row
--   TRUNCATE TABLE t;  remove ALL rows quickly, keeps the table structure  (no WHERE)
--   DROP TABLE t;      remove the table itself (structure + data)
TRUNCATE TABLE practice_jobs;
DROP TABLE IF EXISTS practice_jobs;
--
-- HOW TO THINK ABOUT IT:
--   SELECT = look.  DML = touch rows.  DDL = touch the table itself.
--
-- !!! DANGER !!!
--   UPDATE practice_jobs SET salary = 0;        -- no WHERE -> EVERY row changes
--   DELETE FROM practice_jobs;                  -- no WHERE -> EVERY row is deleted
--   Safe habit: (1) write the SELECT with the same WHERE, check the row count,
--   (2) run inside BEGIN ... then ROLLBACK/COMMIT, (3) back up or use CTAS first.
--
-- COMMON MISTAKES:
--   * INSERT without column list (breaks when columns change).
--   * Running DDL repeatedly without IF EXISTS / IF NOT EXISTS (pipelines must be re-runnable).
--   * Violating constraints (NOT NULL, PRIMARY KEY, CHECK) and not reading the error.
--
-- PRACTICE:
--   Create practice_skills (skill_id PK, skill_name NOT NULL, skill_type), insert
--   3 rows, update one, delete one, then DROP it.


-- ==========================================================================
-- PART 13 — DATA MODELING
-- ==========================================================================
-- WHAT IT MEANS:
--   Data modeling = deciding WHAT tables exist, WHAT ONE ROW means in each (the
--   GRAIN), and HOW tables connect (keys). It is the blueprint of a database.
--
-- WHY A DATA ENGINEER USES IT:
--   A good model makes queries simple, fast, and correct; a bad model causes
--   duplicated data, double-counting and broken dashboards. Modeling is the
--   heart of data warehousing (your upcoming course sections).

------------------------------------------------
-- CONCEPT: NORMALIZATION vs DENORMALIZATION
------------------------------------------------
-- NORMALIZATION: split data into several tables so each fact is stored ONCE.
--   + no repeated values, easy and safe updates (change a company name in ONE place)
--   + smaller storage, fewer inconsistencies
--   - needs JOINs to read, queries are longer
--   Typical home: OLTP systems (apps, transactions) -> "3rd normal form".
--
-- DENORMALIZATION: deliberately repeat/merge data into wider tables.
--   + fewer joins, faster analytics, simpler for analysts
--   - duplicated values, updates must be propagated, more storage
--   Typical home: analytics warehouses / marts.
--
-- EXAMPLE of the SAME information, two shapes:
--   Normalized  : job_postings(company_id) + company_dim(company_id, name)
--   Denormalized: one wide table with company name copied onto every posting row.
CREATE OR REPLACE VIEW v_job_postings_wide AS               -- [PG] CREATE OR REPLACE VIEW works too
SELECT jp.job_id, jp.job_title, jp.job_country, jp.salary_year_avg, cd.name AS company_name
FROM job_postings AS jp
LEFT JOIN company_dim AS cd ON cd.company_id = jp.company_id;
SELECT * FROM v_job_postings_wide LIMIT 5;
--
-- RULE OF THUMB:  OLTP -> normalize.   Analytics -> model for reading (star schema).
--
-- PRACTICE:
--   In a comment, list one anomaly that can occur if the company name were stored
--   on every posting row and a company renames itself.


------------------------------------------------
-- CONCEPT: FACT TABLES, DIMENSION TABLES, STAR and SNOWFLAKE SCHEMAS, GRAIN
------------------------------------------------
-- FACT TABLE      : records EVENTS / MEASUREMENTS. Many rows, mostly keys + numbers.
--                   Here: one row = one job posting. Measures: salary_year_avg.
-- DIMENSION TABLE : describes the WHO / WHAT / WHERE / WHEN. Fewer rows, many text attributes.
--                   dim_company, dim_job, dim_location, dim_date.
-- GRAIN           : the exact meaning of ONE fact row. Decide it FIRST, write it down.
--                   fact_job_postings grain = ONE JOB POSTING.
-- SURROGATE KEY   : a meaningless integer key generated by the warehouse (company_key),
--                   independent of source ids (which can change/collide across systems).
-- PK / FK         : fact table holds FOREIGN KEYS to each dimension's PRIMARY KEY.
--
-- STAR SCHEMA:                                    dim_date
--                                                    |
--                           dim_company ---- fact_job_postings ---- dim_job
--                                                    |
--                                               dim_location
--   One central fact table, dimensions directly around it (denormalized dimensions).
--   + simple joins (fact -> dimension, one hop)  + fast  + analyst friendly
--
-- SNOWFLAKE SCHEMA: dimensions are further normalized into sub-dimensions
--   e.g. dim_location -> dim_country -> dim_region.
--   + less duplication in dimensions   - more joins, harder to read.
--   Most teams prefer a STAR unless a dimension is huge or highly hierarchical.
--
-- WHY DESIGN THE WAREHOUSE THIS WAY (job-posting example)?
--   * Questions like "postings per country per month by job type" become
--     fact JOIN a few small dimensions, then GROUP BY.
--   * Descriptive text lives in dimensions (stored once) -> fact stays small & fast.
--   * Adding a new attribute (e.g. company industry) touches ONE dimension only.
--   * The skill relationship is many-to-many -> bridge table bridge_job_skill
--     (do NOT put skills into the fact at job grain, or you multiply rows).
--
-- BUILD IT (small, but a real star schema). Run this block top-to-bottom.
DROP TABLE IF EXISTS fact_job_postings;
DROP TABLE IF EXISTS dim_company;
DROP TABLE IF EXISTS dim_job;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_date;

-- dim_company: grain = one row per company.
-- (ROW_NUMBER is a WINDOW FUNCTION: you'll understand it fully in PART 14.
--  Here it just creates 1,2,3... as surrogate keys.)
CREATE TABLE dim_company AS
SELECT ROW_NUMBER() OVER (ORDER BY company_id) AS company_key,
       company_id                              AS company_id_source,
       name                                    AS company_name
FROM company_dim;

-- dim_job: grain = one row per (job_title_short, schedule type) combination.
CREATE TABLE dim_job AS
SELECT ROW_NUMBER() OVER (ORDER BY job_title_short, job_schedule_type) AS job_key,
       job_title_short,
       job_schedule_type
FROM (SELECT DISTINCT job_title_short, job_schedule_type FROM job_postings) AS d;

-- dim_location: grain = one row per country.
CREATE TABLE dim_location AS
SELECT ROW_NUMBER() OVER (ORDER BY job_country) AS location_key,
       job_country
FROM (SELECT DISTINCT job_country FROM job_postings) AS d;

-- dim_date: grain = one row per calendar day. Smart key YYYYMMDD is common.
CREATE TABLE dim_date AS
SELECT DISTINCT
       CAST(EXTRACT(YEAR FROM d) * 10000 + EXTRACT(MONTH FROM d) * 100 + EXTRACT(DAY FROM d) AS INTEGER) AS date_key,
       d                          AS full_date,
       EXTRACT(YEAR    FROM d)    AS year,
       EXTRACT(QUARTER FROM d)    AS quarter,
       EXTRACT(MONTH   FROM d)    AS month
FROM (SELECT CAST(job_posted_date AS DATE) AS d FROM job_postings) AS x;

-- fact_job_postings: grain = ONE JOB POSTING. Keys + measures only.
CREATE TABLE fact_job_postings AS
SELECT jp.job_id,
       dc.company_key,
       dj.job_key,
       dl.location_key,
       CAST(EXTRACT(YEAR FROM jp.job_posted_date) * 10000
          + EXTRACT(MONTH FROM jp.job_posted_date) * 100
          + EXTRACT(DAY FROM jp.job_posted_date) AS INTEGER) AS date_key,
       jp.job_work_from_home,
       jp.salary_year_avg
FROM job_postings AS jp
LEFT JOIN dim_company  AS dc ON dc.company_id_source = jp.company_id
LEFT JOIN dim_job      AS dj ON dj.job_title_short = jp.job_title_short
                            AND dj.job_schedule_type = jp.job_schedule_type
LEFT JOIN dim_location AS dl ON dl.job_country = jp.job_country;
-- In a full warehouse you would also declare PK/FK constraints (or enforce them
-- with validation queries, PART 16) — many analytical engines do not enforce FKs.

-- A question answered from the star schema: postings and avg salary per country per month
SELECT dl.job_country,
       dd.year, dd.month,
       COUNT(*)                         AS n_postings,
       ROUND(AVG(f.salary_year_avg), 0) AS avg_salary
FROM fact_job_postings AS f
JOIN dim_location AS dl ON dl.location_key = f.location_key
JOIN dim_date     AS dd ON dd.date_key     = f.date_key
GROUP BY dl.job_country, dd.year, dd.month
ORDER BY dl.job_country, dd.year, dd.month;

-- The many-to-many relationship gets its own BRIDGE table (grain: one row per job-skill pair)
DROP TABLE IF EXISTS bridge_job_skill;
CREATE TABLE bridge_job_skill AS
SELECT job_id, skill_id FROM skills_job_dim;
--
-- HOW TO THINK ABOUT IT:
--   Fact = verbs and numbers.  Dimension = nouns and labels.
--   Before joining a bridge table, remember: it changes the grain (PART 4).
--
-- COMMON MISTAKES:
--   * Mixing grains in one fact table (a row sometimes = posting, sometimes = skill).
--   * Putting measures in dimensions, or descriptive text in the fact.
--   * Over-normalizing dimensions in analytics (too many joins).
--
-- PRACTICE:
--   Sketch (in comments) a dim_skill + bridge design. What is the grain of the
--   bridge? Why would adding skill_id directly to fact_job_postings be wrong?


-- ==========================================================================
-- PART 14 — WINDOW FUNCTIONS   *** THIS IS WHERE YOU STOPPED — TAKE YOUR TIME ***
-- ==========================================================================
-- Build the idea in 4 steps:
--   STEP A: the problem GROUP BY cannot solve
--   STEP B: OVER() = "look at a window of rows, but do not collapse them"
--   STEP C: PARTITION BY and ORDER BY inside OVER
--   STEP D: the function families (ranking, offset, aggregate) + frames

------------------------------------------------
-- STEP A — WHY GROUP BY IS NOT ENOUGH
------------------------------------------------
-- QUESTION: "Show EVERY posting, and next to it the average salary of its country."
--
-- Attempt 1 — GROUP BY: we get the average, but the postings DISAPPEAR.
SELECT job_country, AVG(salary_year_avg) AS avg_salary_country
FROM job_postings
GROUP BY job_country;
--   GROUP BY:   12 rows  ->  3 rows            (many rows -> fewer rows)
--
-- Attempt 2 — the old way: aggregate, then JOIN back (works, but verbose).
SELECT jp.job_id, jp.job_country, jp.salary_year_avg, a.avg_salary_country
FROM job_postings AS jp
JOIN (SELECT job_country, AVG(salary_year_avg) AS avg_salary_country
      FROM job_postings GROUP BY job_country) AS a
  ON a.job_country = jp.job_country;
--
-- Attempt 3 — WINDOW FUNCTION: the same, in one line, rows stay.
SELECT job_id, job_country, salary_year_avg,
       AVG(salary_year_avg) OVER (PARTITION BY job_country) AS avg_salary_country
FROM job_postings
ORDER BY job_country, job_id;
--   WINDOW:     12 rows  ->  12 rows + an extra calculated column
--
--   GROUP BY         many rows -> fewer rows      (collapses)
--   WINDOW FUNCTION  many rows -> SAME rows + extra calculation (keeps detail)


------------------------------------------------
-- STEP B — OVER()  (the window clause)
------------------------------------------------
-- WHAT IT MEANS:
--   function(...) OVER (window definition)
--   The function is computed for EACH ROW looking at a "window" of related rows.
--   OVER () with nothing inside = the window is the WHOLE result set.
--
-- BASIC SYNTAX:
--   function_name(args) OVER (
--       [PARTITION BY col1, col2]       -- split into independent groups of rows
--       [ORDER BY col3]                 -- order rows inside each group
--       [frame: ROWS BETWEEN ... AND ...]   -- which rows around the current one count
--   )
--
-- EXAMPLE: overall average next to every row, and the gap to it
SELECT job_id,
       salary_year_avg,
       AVG(salary_year_avg) OVER ()                         AS overall_avg,
       salary_year_avg - AVG(salary_year_avg) OVER ()       AS diff_from_overall
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_id;
--
-- HOW TO THINK ABOUT IT:
--   "For each row, compute this over a set of rows, and write the answer on THIS row."
--
-- COMMON MISTAKE:
--   Forgetting OVER: AVG(salary) with no OVER and no GROUP BY is an aggregate error.


------------------------------------------------
-- STEP C — PARTITION BY and ORDER BY inside OVER
------------------------------------------------
-- PARTITION BY job_country   : the window restarts for each country (like GROUP BY
--                              for the CALCULATION, but WITHOUT collapsing rows).
-- ORDER BY inside OVER       : orders rows WITHIN each partition so the function can
--                              rank, look backward/forward, or accumulate.
--
-- >>> GROUP BY job_country   versus   PARTITION BY job_country <<<
--
--   GROUP BY job_country        -> one OUTPUT ROW per country.
--   PARTITION BY job_country    -> ALL rows stay; the country only defines which rows
--                                  are "neighbours" for the calculation.
--
-- SIDE BY SIDE:
-- (1) GROUP BY — 3 rows
SELECT job_country, COUNT(*) AS n_postings
FROM job_postings
GROUP BY job_country;

-- (2) PARTITION BY — 12 rows, each also knows its country total
SELECT job_id, job_country,
       COUNT(*) OVER (PARTITION BY job_country) AS n_postings_in_country
FROM job_postings
ORDER BY job_country, job_id;

-- (3) Partition by TWO columns: "same country AND same schedule type"
SELECT job_id, job_country, job_schedule_type,
       COUNT(*) OVER (PARTITION BY job_country, job_schedule_type) AS n_same_country_and_schedule
FROM job_postings
ORDER BY job_country, job_schedule_type, job_id;

-- (4) Percent of total: each country's share (window over a GROUP BY result)
SELECT job_country,
       COUNT(*)                                          AS n_postings,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all_postings
FROM job_postings
GROUP BY job_country;
-- Reading (4): GROUP BY runs first (3 rows), THEN SUM(...) OVER () sums the 3 counts.
--
-- >>> ORDER BY at the end of the query   versus   ORDER BY inside OVER() <<<
--
--   ORDER BY (end of query)  : sorts the FINAL OUTPUT rows for display. Does not
--                              change any calculation.
--   ORDER BY inside OVER()   : defines the order the FUNCTION sees rows in.
--                              It changes the VALUES calculated (rank, running total,
--                              previous row) but does NOT sort the final output.
--
-- DEMO: the window is ordered by salary, the display is ordered by job_id.
SELECT job_id, salary_year_avg,
       RANK() OVER (ORDER BY salary_year_avg DESC) AS salary_rank      -- calculation order
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_id;                                                       -- display order
--
-- DEMO 2: adding ORDER BY inside OVER on an aggregate changes its meaning!
SELECT job_id, job_country, salary_year_avg,
       SUM(salary_year_avg) OVER (PARTITION BY job_country)                        AS total_country,        -- whole partition
       SUM(salary_year_avg) OVER (PARTITION BY job_country ORDER BY job_posted_date) AS running_total       -- up to current row
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_posted_date;
--   No ORDER BY in OVER -> every row sees the WHOLE partition.
--   With ORDER BY in OVER -> every row sees rows UP TO itself (running calculation).


------------------------------------------------
-- STEP D1 — RANKING: ROW_NUMBER, RANK, DENSE_RANK
------------------------------------------------
-- WHAT THEY MEAN (all need ORDER BY inside OVER):
--   ROW_NUMBER() : 1,2,3,4...        unique numbers, ties broken ARBITRARILY
--   RANK()       : 1,2,2,4...        ties share a rank, then a GAP
--   DENSE_RANK() : 1,2,2,3...        ties share a rank, NO gap
--
-- DEMO with ties (inline data so you can see the ties):
SELECT name, score,
       ROW_NUMBER() OVER (ORDER BY score DESC) AS row_num,
       RANK()       OVER (ORDER BY score DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rnk
FROM (VALUES ('A', 90), ('B', 80), ('C', 80), ('D', 70)) AS t(name, score)
ORDER BY score DESC, name;
--   name score row_num rnk dense_rnk
--   A    90    1       1   1
--   B    80    2       2   2
--   C    80    3       2   2          <- tie
--   D    70    4       4   3          <- RANK skips 3, DENSE_RANK does not
--
-- RANKING WITHIN GROUPS (PARTITION BY restarts the numbering):
SELECT job_id, job_country, salary_year_avg,
       RANK() OVER (PARTITION BY job_country ORDER BY salary_year_avg DESC NULLS LAST) AS salary_rank_in_country
FROM job_postings
ORDER BY job_country, salary_rank_in_country;

-- TOP N PER GROUP: top 2 best-paid postings per country.
-- Window functions cannot be used in WHERE (they are computed AFTER WHERE),
-- so compute the rank in a CTE, then filter in the next step.
WITH ranked AS (
    SELECT job_id, job_country, salary_year_avg,
           ROW_NUMBER() OVER (PARTITION BY job_country
                              ORDER BY salary_year_avg DESC, job_id) AS rn   -- job_id = tie-breaker
    FROM job_postings
    WHERE salary_year_avg IS NOT NULL
)
SELECT * FROM ranked WHERE rn <= 2 ORDER BY job_country, rn;

-- [DUCKDB] shortcut: QUALIFY filters on window results directly (not in PG):
--   SELECT job_id, job_country, salary_year_avg
--   FROM job_postings WHERE salary_year_avg IS NOT NULL
--   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_country ORDER BY salary_year_avg DESC) <= 2;

-- DEDUPLICATION pattern (very common in ETL): keep the LATEST row per key.
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY job_posted_date DESC) AS rn
    FROM job_postings
)
SELECT company_id, job_id, job_posted_date
FROM ranked
WHERE rn = 1;                          -- latest posting per company
--
-- WHEN TO USE WHICH:
--   ROW_NUMBER : "pick exactly one row per group" (dedup, top 1).
--   RANK       : competition style, gaps after ties.
--   DENSE_RANK : "top 3 salary LEVELS" without gaps.
--
-- COMMON MISTAKES:
--   * ROW_NUMBER with ties and no tie-breaker -> results can change between runs.
--     Add a deterministic extra column to ORDER BY (a key).
--   * Forgetting NULLS LAST: NULL salaries can rank first on DESC order.
--   * Trying WHERE RANK() ... -> not allowed (use CTE / QUALIFY).


------------------------------------------------
-- STEP D2 — OFFSET FUNCTIONS: LAG and LEAD
------------------------------------------------
-- WHAT THEY MEAN:
--   LAG(col, n, default)  : value from n rows BEFORE the current row (default n = 1)
--   LEAD(col, n, default) : value from n rows AFTER  the current row
--   The row order is defined by ORDER BY inside OVER (so it is mandatory in practice).
--   First/last row of a partition gets NULL (or the default you provide).
--
-- WHY A DATA ENGINEER USES IT:
--   Change detection, time between events, month-over-month growth,
--   gap detection in event logs. Replaces many self-joins.
--
-- EXAMPLE 1: compare the current posting with the previous one of the SAME company
SELECT company_id,
       job_id,
       CAST(job_posted_date AS DATE)                                                       AS posted_day,
       LAG(CAST(job_posted_date AS DATE)) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS prev_posted_day,
       CAST(job_posted_date AS DATE)
         - LAG(CAST(job_posted_date AS DATE)) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS days_since_prev
FROM job_postings
ORDER BY company_id, job_posted_date;

-- EXAMPLE 2: compare current row with the NEXT row (LEAD) — next salary in the company
SELECT company_id, job_id, salary_year_avg,
       LEAD(salary_year_avg) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS next_salary,
       LEAD(salary_year_avg, 1, 0) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS next_salary_or_zero
FROM job_postings
ORDER BY company_id, job_posted_date;

-- EXAMPLE 3: month-over-month change in the number of postings
WITH monthly AS (
    SELECT DATE_TRUNC('month', job_posted_date) AS posted_month,
           COUNT(*)                             AS n_postings
    FROM job_postings
    GROUP BY DATE_TRUNC('month', job_posted_date)
)
SELECT posted_month,
       n_postings,
       LAG(n_postings) OVER (ORDER BY posted_month)                  AS prev_month,
       n_postings - LAG(n_postings) OVER (ORDER BY posted_month)     AS change_vs_prev,
       ROUND(100.0 * (n_postings - LAG(n_postings) OVER (ORDER BY posted_month))
             / NULLIF(LAG(n_postings) OVER (ORDER BY posted_month), 0), 1) AS pct_change
FROM monthly
ORDER BY posted_month;
--
-- COMMON MISTAKES:
--   * LAG without PARTITION BY when you need it per company -> you compare across companies.
--   * LAG without a proper ORDER BY -> "previous" is meaningless.
--   * Forgetting the first row is NULL (handle with COALESCE or the default argument).


------------------------------------------------
-- STEP D3 — AGGREGATE WINDOWS, RUNNING TOTALS, MOVING AVERAGES, FRAMES
------------------------------------------------
-- SUM / AVG / COUNT / MIN / MAX can all be used with OVER.
--
-- THE FRAME = which rows (around the current row) the function actually uses.
--   ROWS BETWEEN <start> AND <end>
--     UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
--
--   DEFAULT when ORDER BY is present:  RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--   DEFAULT when NO ORDER BY:          the whole partition
--
-- EXAMPLE 1: running total of postings per month (cumulative)
WITH monthly AS (
    SELECT DATE_TRUNC('month', job_posted_date) AS posted_month, COUNT(*) AS n_postings
    FROM job_postings
    GROUP BY 1
)
SELECT posted_month,
       n_postings,
       SUM(n_postings) OVER (ORDER BY posted_month
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM monthly
ORDER BY posted_month;

-- EXAMPLE 2: moving average of salary over the current + 2 previous postings
WITH paid AS (
    SELECT job_id, job_posted_date, salary_year_avg
    FROM job_postings
    WHERE salary_year_avg IS NOT NULL
)
SELECT job_id,
       CAST(job_posted_date AS DATE) AS posted_day,
       salary_year_avg,
       ROUND(AVG(salary_year_avg) OVER (ORDER BY job_posted_date
                                        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3
FROM paid
ORDER BY job_posted_date;
--   The first rows average fewer than 3 values (not enough previous rows).

-- EXAMPLE 3: ROWS vs RANGE — the classic trap with ties
--   Without an explicit frame, ties are "peers": they receive the SAME running value.
SELECT job_id, job_country, salary_year_avg,
       SUM(salary_year_avg) OVER (ORDER BY job_country)                                           AS default_frame_range,
       SUM(salary_year_avg) OVER (ORDER BY job_country, job_id
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)               AS rows_frame_per_row
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_id;
--   Compare the two columns: default_frame_range repeats the same number inside a country.

-- EXAMPLE 4: COUNT() OVER and share of the partition
SELECT job_id, job_country, salary_year_avg,
       COUNT(*) OVER (PARTITION BY job_country)                                             AS n_in_country,
       ROUND(100.0 * salary_year_avg / SUM(salary_year_avg) OVER (PARTITION BY job_country), 1) AS pct_of_country_payroll
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_id;

-- EXAMPLE 5: other useful window functions
SELECT job_id, job_country, salary_year_avg,
       NTILE(2) OVER (ORDER BY salary_year_avg)                                             AS half_bucket,       -- split into 2 equal groups
       FIRST_VALUE(job_id) OVER (PARTITION BY job_country ORDER BY salary_year_avg DESC NULLS LAST) AS best_paid_job_in_country,
       MAX(salary_year_avg) OVER (PARTITION BY job_country)                                 AS max_in_country
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_id;
--   NOTE: LAST_VALUE with the default frame returns the CURRENT row (frame ends at current).
--   Use  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING  to see the real last value.
--
------------------------------------------------
-- MENTAL MODEL + CHECKLIST FOR WINDOW FUNCTIONS
------------------------------------------------
--   1. Window functions run in the SELECT step: AFTER FROM/JOIN/WHERE/GROUP BY/HAVING.
--        -> They see only rows that survived the WHERE (filtering changes the result!).
--        -> You cannot put them in WHERE / HAVING / GROUP BY. Use a CTE, then filter.
--   2. Ask yourself, in order:
--        a) Which rows do I want to compare?            -> PARTITION BY
--        b) In what order?                              -> ORDER BY inside OVER
--        c) Which neighbours count?                     -> frame (ROWS BETWEEN ...)
--        d) What calculation?                           -> function
--   3. Output row count NEVER changes (unlike GROUP BY).
--   4. Add deterministic tie-breakers in ORDER BY.
--
--   COMMON MISTAKES:
--     * Filtering rows (WHERE) before the window when you needed them inside it.
--     * Wrong partition (e.g. partition by company when you meant country).
--     * Expecting OVER(ORDER BY ...) to sort the final output.
--     * Using ROW_NUMBER when ties matter (use RANK/DENSE_RANK).
--
-- PRACTICE:
--   (1) Show each posting with the rank of its salary inside its job_title_short.
--   (2) Show each posting with the salary of the previous posting in the same country.
--   (3) Running count of postings per country ordered by posting date.


-- ==========================================================================
-- PART 15 — NESTED FUNCTIONS
-- ==========================================================================

------------------------------------------------
-- CONCEPT: FUNCTIONS INSIDE FUNCTIONS
------------------------------------------------
-- WHAT IT MEANS:
--   The output of one function becomes the input of another:
--       ROUND( AVG( COALESCE(salary, 0) ), 2 )
--   There is no new syntax. It is just composition, like f(g(h(x))).
--
-- WHY A DATA ENGINEER USES IT:
--   Cleaning and transformation steps are chains: trim -> lowercase -> replace -> null-handle.
--   Metrics are chains too: CASE -> aggregate -> round -> divide.
--
-- HOW TO READ A COMPLICATED EXPRESSION: FROM THE INSIDE OUT
--   Expression:  ROUND(AVG(CASE WHEN job_work_from_home THEN salary_year_avg END), 0)
--     1) job_work_from_home           -> a TRUE/FALSE flag per row
--     2) CASE WHEN flag THEN salary   -> salary for remote rows, NULL for others (per row)
--     3) AVG( ... )                   -> average of the non-NULL values (per group)
--     4) ROUND( ..., 0)               -> round to whole numbers
--
-- EXAMPLE 1: text cleaning chain (read inside out: COALESCE -> TRIM -> LOWER -> REPLACE)
SELECT job_id,
       REPLACE(LOWER(TRIM(COALESCE(job_title, 'unknown'))), ' ', '_') AS title_slug
FROM job_postings;

-- EXAMPLE 2: CASE + aggregate + ROUND (conditional metric)
SELECT job_country,
       ROUND(AVG(CASE WHEN job_work_from_home THEN salary_year_avg END), 0) AS avg_salary_remote,
       ROUND(AVG(CASE WHEN NOT job_work_from_home THEN salary_year_avg END), 0) AS avg_salary_onsite
FROM job_postings
GROUP BY job_country;

-- EXAMPLE 3: window function inside ROUND (and COALESCE for the first row)
SELECT job_id, job_country, salary_year_avg,
       ROUND(salary_year_avg - AVG(salary_year_avg) OVER (PARTITION BY job_country), 0) AS diff_vs_country_avg,
       COALESCE(LAG(salary_year_avg) OVER (PARTITION BY job_country ORDER BY job_posted_date), 0) AS prev_salary
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_posted_date;

-- EXAMPLE 4: aggregate INSIDE a window function (allowed) — read from the inside out
--   COUNT(*)                     -> per-group count (GROUP BY step)
--   SUM(COUNT(*)) OVER ()        -> window over the grouped result
--   ROUND(100.0 * x / y, 1)      -> percentage
SELECT job_title_short,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM job_postings
GROUP BY job_title_short
ORDER BY n DESC;

-- RULES OF THE GAME (what is NOT allowed):
--   * A window function inside an aggregate:  SUM(ROW_NUMBER() OVER (...))  -> ERROR.
--       Fix: compute the window in a CTE, aggregate in the next step.
--   * An aggregate inside WHERE.  -> use HAVING or a CTE.
--   * A window function inside another window function. -> use a CTE.
--
-- HOW TO THINK ABOUT IT:
--   Inner function runs first. If it's unreadable, split it into CTE steps and
--   give each intermediate result a name. Readability beats cleverness.
--
-- COMMON MISTAKES:
--   * Unbalanced parentheses (format on several lines to match them).
--   * Putting ROUND around the wrong piece (ROUND(AVG(x)) vs AVG(ROUND(x))).
--   * Integer division inside nested expressions (use 100.0, not 100).
--
-- PRACTICE:
--   Write one expression that returns the upper-case first 3 letters of the
--   trimmed job_country, replacing NULL with 'N/A'. Read it inside out in a comment.


-- ==========================================================================
-- PART 16 — SQL FOR DATA ENGINEERING (putting everything together)
-- ==========================================================================
-- THE PIPELINE:
--
--   RAW DATA          files / APIs / app databases, loaded as-is, untouched
--      |              SQL: COPY / INSERT into raw tables (often all VARCHAR)
--      v
--   STAGING           1:1 copy of raw, but with proper names + types (CAST)
--      |              SQL: SELECT with CAST, TRIM, renames, TRY_CAST
--      v
--   CLEANING          fix NULLs, standardize text, remove duplicates, fix bad values
--      |              SQL: COALESCE, NULLIF, TRIM/LOWER, ROW_NUMBER dedup, CASE
--      v
--   TRANSFORMATION    business logic: derive columns, join sources, aggregate
--      |              SQL: JOIN, CASE, CTEs, window functions
--      v
--   DATA MODEL        shape into facts + dimensions (star schema)
--      |              SQL: CREATE TABLE AS, surrogate keys, joins to dimensions
--      v
--   WAREHOUSE         final, trusted, documented tables (+ validation)
--      |              SQL: constraints, validation queries, incremental loads
--      v
--   ANALYTICS         dashboards, reports, ML features
--                     SQL: GROUP BY, window metrics, marts / views
--
-- RULES OF A GOOD PIPELINE: re-runnable (idempotent), testable at every layer,
-- never overwrite RAW, keep the grain explicit, validate before you publish.
--
-- Below is a MINI PIPELINE you can run end-to-end.

------------------------------------------------
-- STAGE 1 — RAW: messy text data, exactly as "received"
------------------------------------------------
DROP TABLE IF EXISTS raw_job_postings;
CREATE TABLE raw_job_postings (          -- everything VARCHAR: raw never rejects data
    job_id           VARCHAR,
    company_name     VARCHAR,
    job_title        VARCHAR,
    job_country      VARCHAR,
    posted_date      VARCHAR,
    salary_year_avg  VARCHAR,
    loaded_at        VARCHAR
);
INSERT INTO raw_job_postings VALUES
    ('101', ' DataCorp ',  'Data Engineer ',   'france',  '2025-05-01', '105000', '2025-06-01 02:00:00'),
    ('102', 'CloudNine',    'data engineer',    'France ', '2025-05-03', '',       '2025-06-01 02:00:00'),
    ('103', 'FinPipe',      'ETL Developer',    'Germany', '2025-05-07', 'N/A',    '2025-06-01 02:00:00'),
    ('104', 'FinPipe',      'Data Analyst',     'Germany', '2025-05-09', '72000',  '2025-06-01 02:00:00'),
    ('104', 'FinPipe',      'Data Analyst',     'Germany', '2025-05-09', '74000',  '2025-06-02 02:00:00'),   -- same job_id loaded again (updated salary)
    ('105', 'DataCorp',     'Data Scientist',   NULL,      '2025-05-12', '98000',  '2025-06-01 02:00:00');

------------------------------------------------
-- STAGE 2 — STAGING: rename, TRIM, CAST. No business logic yet.
------------------------------------------------
DROP TABLE IF EXISTS stg_job_postings;
CREATE TABLE stg_job_postings AS
SELECT CAST(job_id AS INTEGER)                          AS job_id,
       TRIM(company_name)                               AS company_name,
       TRIM(job_title)                                  AS job_title,
       TRIM(job_country)                                AS job_country,
       CAST(posted_date AS DATE)                        AS posted_date,
       TRY_CAST(NULLIF(TRIM(salary_year_avg), '') AS DECIMAL(10,2)) AS salary_year_avg,   -- '' and 'N/A' -> NULL   [DUCKDB TRY_CAST]
       CAST(loaded_at AS TIMESTAMP)                     AS loaded_at
FROM raw_job_postings;
-- [PG] no TRY_CAST: use  CASE WHEN col ~ '^[0-9]+(\.[0-9]+)?$' THEN col::numeric END

------------------------------------------------
-- STAGE 3 — CLEANING: standardize, fill NULLs, DEDUPLICATE
------------------------------------------------
DROP TABLE IF EXISTS clean_job_postings;
CREATE TABLE clean_job_postings AS
WITH standardized AS (                                   -- step 1: standardize text and NULLs
    SELECT job_id,
           company_name,
           LOWER(job_title)                              AS job_title,
           COALESCE(UPPER(SUBSTRING(LOWER(job_country),1,1)) || SUBSTRING(LOWER(job_country),2), 'Unknown') AS job_country,   -- capitalize first letter ([PG] also has INITCAP)
           posted_date,
           salary_year_avg,
           loaded_at
    FROM stg_job_postings
),
deduplicated AS (                                        -- step 2: keep the LATEST load per job_id
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY loaded_at DESC) AS rn
    FROM standardized
)
SELECT job_id, company_name, job_title, job_country, posted_date, salary_year_avg, loaded_at
FROM deduplicated
WHERE rn = 1;
-- NOTE: [PG] offers INITCAP(x) for capitalization; here we build it with UPPER + SUBSTRING so it also works in DuckDB.

------------------------------------------------
-- STAGE 4 — TRANSFORMATION + JOIN DIMENSIONS
------------------------------------------------
-- Enrich with the company dimension; use LEFT JOIN so no posting is lost.
DROP TABLE IF EXISTS int_job_postings_enriched;
CREATE TABLE int_job_postings_enriched AS
SELECT c.job_id,
       d.company_key,
       c.job_title,
       c.job_country,
       c.posted_date,
       c.salary_year_avg,
       CASE WHEN c.salary_year_avg IS NULL    THEN 'Unknown'
            WHEN c.salary_year_avg >= 100000  THEN 'High'
            ELSE 'Standard' END                 AS salary_band
FROM clean_job_postings AS c
LEFT JOIN dim_company AS d
       ON d.company_name = c.company_name;      -- join key: cleaned company name

------------------------------------------------
-- STAGE 5 — FACT TABLE (grain: one row per job posting) + AGGREGATED MART
------------------------------------------------
DROP TABLE IF EXISTS fact_job_postings_new;
CREATE TABLE fact_job_postings_new AS
SELECT job_id, company_key, posted_date, salary_year_avg, salary_band
FROM int_job_postings_enriched;

DROP TABLE IF EXISTS mart_country_summary;
CREATE TABLE mart_country_summary AS
SELECT job_country,
       COUNT(*)                         AS n_postings,
       COUNT(salary_year_avg)           AS n_with_salary,
       ROUND(AVG(salary_year_avg), 0)   AS avg_salary
FROM clean_job_postings
GROUP BY job_country;

SELECT * FROM mart_country_summary ORDER BY job_country;

------------------------------------------------
-- STAGE 6 — VALIDATION (run after EVERY load; a pipeline without tests is a rumor)
------------------------------------------------
-- (1) Row-count reconciliation: raw distinct jobs must equal clean rows
SELECT (SELECT COUNT(DISTINCT job_id) FROM raw_job_postings) AS raw_distinct_jobs,
       (SELECT COUNT(*)               FROM clean_job_postings) AS clean_rows;

-- (2) Duplicate keys (should return ZERO rows)
SELECT job_id, COUNT(*) AS n FROM clean_job_postings GROUP BY job_id HAVING COUNT(*) > 1;

-- (3) NULL profile of important columns
SELECT COUNT(*) AS total_rows,
       COUNT(*) - COUNT(job_country)     AS null_country,
       COUNT(*) - COUNT(salary_year_avg) AS null_salary,
       COUNT(*) - COUNT(posted_date)     AS null_date
FROM clean_job_postings;

-- (4) Orphan keys: postings that did not find a company in the dimension (should be ZERO)
SELECT job_id FROM int_job_postings_enriched WHERE company_key IS NULL;

-- (5) Range / sanity checks
SELECT MIN(salary_year_avg) AS min_salary, MAX(salary_year_avg) AS max_salary,
       MIN(posted_date)     AS first_day,  MAX(posted_date)     AS last_day
FROM clean_job_postings;

-- (6) Join did not multiply rows: fact count = clean count
SELECT (SELECT COUNT(*) FROM fact_job_postings_new) AS fact_rows,
       (SELECT COUNT(*) FROM clean_job_postings)    AS clean_rows;

-- IDEMPOTENT / INCREMENTAL LOAD IDEA:
--   Re-running the pipeline must not create duplicates. Options:
--     * DROP + CREATE TABLE AS (full refresh)           -- simple, used above
--     * INSERT ... ON CONFLICT (key) DO UPDATE          -- upsert (PART 12)
--     * DELETE WHERE load_date = :run_date; INSERT ...  -- partition overwrite
--     * incremental filter: WHERE loaded_at > (SELECT MAX(loaded_at) FROM target)
--
-- HOW TO THINK ABOUT IT:
--   Each stage = one responsibility. Raw is a backup of reality; staging is typed;
--   clean is trustworthy; the model is shaped for analytics; validation protects trust.
--
-- COMMON MISTAKES:
--   * Cleaning inside the RAW layer (you lose the original).
--   * Joining BEFORE deduplicating (multiplies rows).
--   * No validation queries. Silent bad data is worse than a failed job.
--
-- PRACTICE:
--   Add a 7th stage check: do all mart_country_summary.n_postings add up to the number of
--   rows in clean_job_postings?


-- ==========================================================================
-- PART 17 — SQL BEST PRACTICES
-- ==========================================================================
-- 1. MEANINGFUL ALIASES.   jp / cd / sd are fine IF consistent;  a, b, c are not.
--      BAD : SELECT a.x, b.y FROM t1 a JOIN t2 b ON a.k = b.k
--      GOOD: SELECT jp.job_id, cd.name FROM job_postings AS jp JOIN company_dim AS cd ON cd.company_id = jp.company_id
-- 2. AVOID SELECT * IN PRODUCTION. Name the columns (schema changes, performance, clarity).
-- 3. FORMAT CLEARLY: one clause per line, indent consistently, one column per line in long selects,
--      keywords in UPPERCASE, comma at the end of the line (or the start — pick ONE team style).
-- 4. USE CTEs FOR COMPLEX TRANSFORMATIONS, named by the grain they produce.
-- 5. UNDERSTAND THE GRAIN of every table before joining (write it in a comment).
-- 6. CHECK NULLs in keys, measures and join columns.
-- 7. CHECK DUPLICATES on the key that should be unique:
--      SELECT key, COUNT(*) FROM t GROUP BY key HAVING COUNT(*) > 1;
-- 8. VALIDATE JOINS: row counts before/after; look at unmatched rows (LEFT JOIN ... IS NULL).
-- 9. AVOID ACCIDENTAL CARTESIAN PRODUCTS: every JOIN needs an ON; check the row count.
-- 10. MAKE TRANSFORMATIONS REPRODUCIBLE: no hard-coded "today" (pass a date parameter),
--      deterministic ORDER BY (tie-breakers), CREATE ... IF NOT EXISTS / DROP IF EXISTS,
--      no manual edits to data.
-- 11. COMMENT COMPLICATED LOGIC: explain WHY (business rule), not WHAT (the code shows what).
-- 12. TEST STEP BY STEP: run the CTEs one at a time; build the query in layers.
-- 13. FILTER EARLY, select only needed columns, avoid functions on indexed/partitioned columns in WHERE.
-- 14. USE EXPLICIT JOIN ... ON syntax (never comma joins).
-- 15. NEVER trust a UNION: prefer UNION ALL unless you really need dedup.
--
-- A WELL-WRITTEN QUERY (compare it with the bad one in PART 18):
WITH remote_de_jobs AS (                     -- grain: one row per remote Data Engineer posting
    SELECT job_id,
           company_id,
           job_country,
           salary_year_avg
    FROM job_postings
    WHERE job_title_short = 'Data Engineer'
      AND job_work_from_home
)
SELECT cd.name                              AS company_name,
       COUNT(*)                             AS n_remote_de_jobs,
       ROUND(AVG(r.salary_year_avg), 0)     AS avg_salary
FROM remote_de_jobs AS r
JOIN company_dim AS cd
  ON cd.company_id = r.company_id
GROUP BY cd.name
ORDER BY n_remote_de_jobs DESC, company_name;


-- ==========================================================================
-- PART 18 — SQL DEBUGGING
-- ==========================================================================
-- THE DEBUGGING MINDSET:
--   Never debug a 60-line query as a whole. Shrink it, isolate the broken step,
--   check ROW COUNTS at every step, then fix and rebuild.
--
-- Each problem below: SYMPTOM -> CAUSE -> HOW TO FIND IT -> FIX.
-- (The broken queries are commented out so this file still runs.)

------------------------------------------------
-- 1. SYNTAX ERROR
------------------------------------------------
--   SELECT job_id job_title FROM job_postings;     -- missing comma -> job_title became an alias!
--   SELECT job_id, job_title, FROM job_postings;   -- trailing comma before FROM -> syntax error
-- FIND IT: the error message shows the position near the problem; look just BEFORE it.
-- FIX: SELECT job_id, job_title FROM job_postings;
-- TIPS: balanced parentheses, commas between CTEs, quotes closed, keywords spelled right.

------------------------------------------------
-- 2. WRONG COLUMN / TABLE NAME
------------------------------------------------
--   SELECT job_titel FROM job_postings;            -- "column not found" (DuckDB suggests similar names)
-- FIND IT: DESCRIBE job_postings;  or  SELECT * FROM job_postings LIMIT 1;
-- FIX: use the exact name. Remember "double quotes" mean identifiers, 'single quotes' mean text.

------------------------------------------------
-- 3. AMBIGUOUS COLUMN
------------------------------------------------
--   SELECT company_id FROM job_postings JOIN company_dim USING (company_id)   -- fine with USING
--   SELECT company_id FROM job_postings jp JOIN company_dim cd ON jp.company_id = cd.company_id;  -- ERROR: ambiguous
-- FIX: prefix every column with its alias:  jp.company_id
SELECT jp.company_id, cd.name
FROM job_postings AS jp
JOIN company_dim AS cd ON cd.company_id = jp.company_id
LIMIT 3;

------------------------------------------------
-- 4. DUPLICATE ROWS AFTER A JOIN
------------------------------------------------
-- SYMPTOM: totals too big, row count higher than expected.
-- CAUSE: joined to a table that is not unique on the join key (wrong grain).
-- FIND IT: compare counts, then look for the key that repeats.
SELECT COUNT(*) AS before_join FROM job_postings;
SELECT COUNT(*) AS after_join
FROM job_postings AS jp
JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id;                -- larger -> one-to-many
SELECT job_id, COUNT(*) AS n FROM skills_job_dim GROUP BY job_id HAVING COUNT(*) > 1 ORDER BY n DESC;
-- FIX: aggregate the many-side first (CTE), or accept the new grain and count DISTINCT keys.
-- NOT A FIX: slapping DISTINCT on the result.

------------------------------------------------
-- 5. UNEXPECTED NULLs
------------------------------------------------
-- SYMPTOM: columns full of NULL after a LEFT JOIN, or averages that look off.
-- CAUSES: no match on the key (typo, whitespace, case, wrong type), real missing values,
--         arithmetic with NULL (NULL + 1 = NULL), CASE without ELSE.
-- FIND IT:
SELECT jp.job_id, cd.name
FROM job_postings AS jp
LEFT JOIN company_dim AS cd ON cd.company_id = jp.company_id
WHERE cd.company_id IS NULL;                                       -- unmatched rows (none here = good)
-- FIX: clean keys (TRIM/LOWER/CAST) before joining; COALESCE only where meaningful.

------------------------------------------------
-- 6. INCORRECT GROUP BY / WRONG AGGREGATION
------------------------------------------------
--   SELECT job_country, job_title_short, COUNT(*) FROM job_postings GROUP BY job_country;
--     -> ERROR: job_title_short is neither grouped nor aggregated. (DuckDB: GROUP BY ALL fixes it)
-- Wrong results (no error!):
--   * COUNT(col) instead of COUNT(*)  -> NULLs dropped.
--   * AVG over a joined, duplicated table -> weighted by the duplicates.
--   * Grouping by a timestamp instead of a month.
-- FIND IT: calculate one group by hand with a simple WHERE, and compare.
SELECT AVG(salary_year_avg) FROM job_postings WHERE job_country = 'France';   -- manual check for France

------------------------------------------------
-- 7. WRONG JOIN KEY
------------------------------------------------
--   JOIN company_dim cd ON cd.company_id = jp.job_id       -- ids look similar, meaning differs
-- SYMPTOM: weird matches or few matches. FIND IT: check that the join columns mean the same thing;
-- test key uniqueness and overlap:
SELECT COUNT(*) AS matched
FROM job_postings AS jp
JOIN company_dim  AS cd ON cd.company_id = jp.company_id;
SELECT COUNT(*) AS orphan_fk
FROM job_postings AS jp
WHERE NOT EXISTS (SELECT 1 FROM company_dim cd WHERE cd.company_id = jp.company_id);

------------------------------------------------
-- 8. INCORRECT WINDOW PARTITION
------------------------------------------------
-- SYMPTOM: rank restarts at the wrong place, LAG compares unrelated rows, totals ignore groups.
-- BUG: ranking salaries across ALL rows when you wanted per country:
SELECT job_id, job_country, salary_year_avg,
       RANK() OVER (ORDER BY salary_year_avg DESC NULLS LAST)                        AS rank_global_bug,
       RANK() OVER (PARTITION BY job_country ORDER BY salary_year_avg DESC NULLS LAST) AS rank_in_country_ok
FROM job_postings
ORDER BY job_country, rank_in_country_ok;
-- FIND IT: pick ONE partition value, filter it with WHERE, and read the numbers manually.

------------------------------------------------
-- 9. INCORRECT ORDER BY
------------------------------------------------
-- (a) ORDER BY at the end vs inside OVER (PART 14): they do different jobs.
-- (b) LAG/LEAD/running totals without ORDER BY inside OVER => meaningless or random.
-- (c) LIMIT without ORDER BY => random rows.
-- (d) ORDER BY 2 (column position) breaks when SELECT changes. Prefer names.
-- (e) NULL ordering: always write NULLS LAST / NULLS FIRST.
-- (f) ORDER BY text numbers: '10' < '9' (cast first).

------------------------------------------------
-- SYSTEMATIC DEBUGGING CHECKLIST
------------------------------------------------
--   [ ] 1. Read the error message fully; go to the position it names.
--   [ ] 2. Run the query in pieces: each CTE / subquery alone with LIMIT 10.
--   [ ] 3. Check the GRAIN of each input table (what does ONE row mean?).
--   [ ] 4. Check key uniqueness: GROUP BY key HAVING COUNT(*) > 1.
--   [ ] 5. Row counts before and after EVERY join / filter / union.
--   [ ] 6. Look for NULLs in keys, measures, and CASE results.
--   [ ] 7. Look at unmatched rows: LEFT JOIN ... WHERE right_key IS NULL.
--   [ ] 8. Verify one group/one row by hand with a simple query.
--   [ ] 9. Check data types and hidden spaces/case (TYPEOF, LENGTH vs LENGTH(TRIM())).
--   [ ] 10. Re-check logical order of execution (alias in WHERE? window in WHERE?).
--   [ ] 11. Reduce to a minimal reproducible example with 5-10 inline rows (VALUES).
--   [ ] 12. After the fix, add a validation query so the bug cannot come back silently.
--
-- TRICK: build mini test data inline:
SELECT * FROM (VALUES (1, 'a'), (2, NULL), (2, 'b')) AS t(id, label);
--
-- PRACTICE:
--   Each query below hides ONE bug. Find it and write the fix in a comment:
--   (1) SELECT job_country, AVG(salary_year_avg) FROM job_postings WHERE AVG(salary_year_avg) > 100000 GROUP BY job_country;
--   (2) SELECT jp.job_id, cd.name FROM job_postings jp LEFT JOIN company_dim cd ON cd.company_id = jp.company_id WHERE cd.name = 'DataCorp';   -- why is it not really a left join anymore?
--   (3) SELECT job_id, LAG(salary_year_avg) OVER () FROM job_postings;


-- ==========================================================================
-- PART 19 — PRACTICE SECTION  (80 exercises, progressively harder)
-- ==========================================================================
-- RULES:
--   * Use the practice database from PART 0 (job_postings, company_dim, skills_dim,
--     skills_job_dim) and the tables built in PART 13 / PART 16.
--   * Write your solution under each TODO. Run it. Check row counts.
--   * Do NOT open the ANSWER KEY (end of file) until you have really tried.
--   * Tip: for each exercise first write the GRAIN of the result in a comment.


-- ##########################################################################
-- LEVEL 1 — FUNDAMENTALS (10)
-- ##########################################################################

-- 1.1  Return all columns and rows of company_dim.
-- TODO: Solve this yourself.

-- 1.2  Return only job_title and job_country from job_postings.
-- TODO: Solve this yourself.

-- 1.3  List the distinct countries in job_postings.
-- TODO: Solve this yourself.

-- 1.4  Return all postings located in France.
-- TODO: Solve this yourself.

-- 1.5  Return 'Data Engineer' (job_title_short) postings in the United States.
-- TODO: Solve this yourself.

-- 1.6  Return postings that have no salary.
-- TODO: Solve this yourself.

-- 1.7  Return postings with salary between 100000 and 130000 (inclusive).
-- TODO: Solve this yourself.

-- 1.8  Return postings whose job_title contains the word 'engineer', ignoring case.
-- TODO: Solve this yourself.

-- 1.9  Return postings from France or Germany, using IN.
-- TODO: Solve this yourself.

-- 1.10 Return the 3 best-paid postings (ignore NULL salaries).
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 2 — FILTERING AND AGGREGATION (10)
-- ##########################################################################

-- 2.1  How many postings are there in total?
-- TODO: Solve this yourself.

-- 2.2  How many postings have a salary?
-- TODO: Solve this yourself.

-- 2.3  What is the average salary of Data Engineer (job_title_short) postings?
-- TODO: Solve this yourself.

-- 2.4  Return the minimum and maximum salary of all postings.
-- TODO: Solve this yourself.

-- 2.5  Number of postings per country.
-- TODO: Solve this yourself.

-- 2.6  Average salary per country, highest first (NULLs in the average are ignored).
-- TODO: Solve this yourself.

-- 2.7  Countries that have MORE than 3 postings.
-- TODO: Solve this yourself.

-- 2.8  For each job_title_short, how many postings are remote (job_work_from_home)?
-- TODO: Solve this yourself.

-- 2.9  Among Full-time postings with a salary: countries whose average salary is above 110000.
-- TODO: Solve this yourself.

-- 2.10 For each country, how many DIFFERENT companies posted jobs?
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 3 — JOINs (10)
-- ##########################################################################

-- 3.1  Return job_id, job_title and the company NAME for every posting.
-- TODO: Solve this yourself.

-- 3.2  Return every company with its number of postings (companies with zero must appear with 0).
-- TODO: Solve this yourself.

-- 3.3  Return the companies that have NO postings (anti-join).
-- TODO: Solve this yourself.

-- 3.4  Return job_id and the skill NAMES required for each job (one row per job-skill).
-- TODO: Solve this yourself.

-- 3.5  Count how many postings require each skill (skill name + count), most demanded first.
-- TODO: Solve this yourself.

-- 3.6  Return the postings that have NO skills listed.
-- TODO: Solve this yourself.

-- 3.7  Average salary per company NAME (only companies that have postings).
-- TODO: Solve this yourself.

-- 3.8  Top 3 skills among Data Engineer (job_title_short) postings.
-- TODO: Solve this yourself.

-- 3.9  Show that joining job_postings to skills_job_dim multiplies rows:
--      return the row count before and after the join in one result row.
-- TODO: Solve this yourself.

-- 3.10 SELF JOIN: pairs of postings of the SAME company (no mirrored pairs, no self-pairs)
--      with the two job_ids and their posting dates.
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 4 — CASE / NULL / DATES / TEXT (10)
-- ##########################################################################

-- 4.1  Add a salary_band: 'High' (>=140000), 'Mid' (100000-139999), 'Low' (<100000), 'Unknown' (NULL).
-- TODO: Solve this yourself.

-- 4.2  Count postings per salary_band (reuse the logic of 4.1).
-- TODO: Solve this yourself.

-- 4.3  Per country: number of remote postings and number of on-site postings (conditional aggregation).
-- TODO: Solve this yourself.

-- 4.4  Compare the average salary ignoring NULLs with the average treating NULL as 0. Explain the gap in a comment.
-- TODO: Solve this yourself.

-- 4.5  Clean job_title with LOWER and TRIM. How many distinct titles before vs after cleaning?
-- TODO: Solve this yourself.

-- 4.6  Return job_id and the first 10 characters of job_title in UPPER case.
-- TODO: Solve this yourself.

-- 4.7  Number of postings per month (use DATE_TRUNC).
-- TODO: Solve this yourself.

-- 4.8  Postings published in Q1 2025 (January to March) using a half-open date range.
-- TODO: Solve this yourself.

-- 4.9  For each posting, the number of days between its posting date and 2025-06-01.
-- TODO: Solve this yourself.

-- 4.10 Remote share (0 to 1) per country, using NULLIF to protect against division by zero.
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 5 — CTEs AND SUBQUERIES (10)
-- ##########################################################################

-- 5.1  Scalar subquery: postings with salary above the overall average salary.
-- TODO: Solve this yourself.

-- 5.2  IN subquery: postings from companies that have at least one posting with salary >= 150000.
-- TODO: Solve this yourself.

-- 5.3  FROM subquery: the average of the per-company average salaries.
-- TODO: Solve this yourself.

-- 5.4  Correlated subquery: postings paid above THEIR OWN company's average salary.
-- TODO: Solve this yourself.

-- 5.5  Rewrite 5.1 using a CTE.
-- TODO: Solve this yourself.

-- 5.6  Two CTEs: postings per company and average salary per company; join them with the company name.
-- TODO: Solve this yourself.

-- 5.7  CTE before a join: count jobs per skill in a CTE, then join to skills_dim (skills with 0 jobs must show 0).
-- TODO: Solve this yourself.

-- 5.8  EXISTS: companies that have at least one remote posting.
-- TODO: Solve this yourself.

-- 5.9  CTE: monthly posting counts, then keep only the months whose count is above the average monthly count.
-- TODO: Solve this yourself.

-- 5.10 Multi-step CTE: find the 3 most demanded skills, then count how many DISTINCT companies
--      have at least one posting requiring any of them.
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 6 — DATA MODELING (5)
-- ##########################################################################

-- 6.1  In comments: state the GRAIN of job_postings, skills_job_dim, and fact_job_postings.
-- TODO: Solve this yourself.

-- 6.2  In comments: list the PK of each source table and every FK relationship between them.
-- TODO: Solve this yourself.

-- 6.3  Write CREATE TABLE for practice_dim_skill (surrogate key, natural id, name, type) with sensible constraints.
-- TODO: Solve this yourself.

-- 6.4  In comments: classify each as FACT measure, FACT key, or DIMENSION attribute:
--      salary_year_avg, company name, job_posted_date, job_work_from_home, skill name.
-- TODO: Solve this yourself.

-- 6.5  Write CREATE TABLE for practice_bridge_job_skill (many-to-many) and explain in a comment
--      why a comma-separated skills column in the fact table would be a bad design.
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 7 — WINDOW FUNCTIONS (15)
-- ##########################################################################

-- 7.1  Each posting with salary, plus the overall average salary in a new column (rows with salary only).
-- TODO: Solve this yourself.

-- 7.2  Each posting (with salary) plus the average salary of ITS country.
-- TODO: Solve this yourself.

-- 7.3  Same as 7.2 plus the difference between the posting's salary and its country average.
-- TODO: Solve this yourself.

-- 7.4  Number all postings 1..N by posting date, oldest first (ROW_NUMBER).
-- TODO: Solve this yourself.

-- 7.5  Rank postings by salary (highest = 1) WITHIN each country, with RANK (ignore NULL salaries).
-- TODO: Solve this yourself.

-- 7.6  Rank postings inside each country ordered by job_title_short (ties!), using RANK and DENSE_RANK
--      side by side. Explain the difference in a comment.
-- TODO: Solve this yourself.

-- 7.7  Top 2 highest-paid postings per country (CTE + ROW_NUMBER).
-- TODO: Solve this yourself.

-- 7.8  The LATEST posting of each company (one row per company).
-- TODO: Solve this yourself.

-- 7.9  For each posting, the previous posting date of the same company and the days since it (LAG).
-- TODO: Solve this yourself.

-- 7.10 For each posting, the salary of the NEXT posting of the same company (LEAD).
-- TODO: Solve this yourself.

-- 7.11 Monthly posting counts and a running total of postings over the months.
-- TODO: Solve this yourself.

-- 7.12 Running total of salary ordered by posting date (rows with salary only; use an explicit ROWS frame).
-- TODO: Solve this yourself.

-- 7.13 3-posting moving average of salary ordered by posting date (current row + 2 previous; rows with salary only).
-- TODO: Solve this yourself.

-- 7.14 Each country's percentage of all postings, using COUNT/SUM OVER (result: one row per country).
-- TODO: Solve this yourself.

-- 7.15 Month-over-month change in the number of postings (LAG over monthly counts).
-- TODO: Solve this yourself.


-- ##########################################################################
-- LEVEL 8 — DATA ENGINEERING SQL (10)
-- ##########################################################################

-- 8.1  Create a staging table practice_stg_postings from job_postings with: job_id, cleaned title
--      (lower + trim), job_country, posted_date as DATE, salary_year_avg.
-- TODO: Solve this yourself.

-- 8.2  Check for duplicate job_id values in job_postings (should return zero rows).
-- TODO: Solve this yourself.

-- 8.3  Null profile of job_postings: one row with the count of NULLs in company_id, job_country,
--      job_posted_date and salary_year_avg.
-- TODO: Solve this yourself.

-- 8.4  Orphan check: postings whose company_id does not exist in company_dim (NOT EXISTS version).
-- TODO: Solve this yourself.

-- 8.5  Row-count reconciliation: compare the row count of job_postings with fact_job_postings and
--      flag the result as 'OK' or 'MISMATCH'.
-- TODO: Solve this yourself.

-- 8.6  Deduplicate raw_job_postings: keep the latest loaded_at row per job_id (ROW_NUMBER).
-- TODO: Solve this yourself.

-- 8.7  Build practice_dim_company from company_dim with a surrogate key (ROW_NUMBER) and the source id.
-- TODO: Solve this yourself.

-- 8.8  Build a mart table practice_mart_monthly: country, month, n_postings, avg_salary.
-- TODO: Solve this yourself.

-- 8.9  Validate that joining job_postings to company_dim does NOT multiply rows
--      (count before, count after, and a status column).
-- TODO: Solve this yourself.

-- 8.10 Idempotent reload: write the statements to rebuild practice_mart_monthly so that running them twice
--      gives the same result (no duplicates).
-- TODO: Solve this yourself.


-- ==========================================================================
-- PART 20 — FINAL SQL CHEAT SHEET   (meaning in one line + minimal syntax)
-- ==========================================================================
-- SELECT        choose columns/expressions to return
--               SELECT col1, col2 AS alias FROM t;
-- FROM          which table(s) to read (and JOIN)
--               FROM table_name AS t
-- WHERE         filter ROWS before grouping
--               WHERE col = 'x' AND col2 > 10
-- DISTINCT      remove duplicate rows in the result
--               SELECT DISTINCT col FROM t;
-- GROUP BY      collapse rows into groups (many rows -> fewer)
--               SELECT g, COUNT(*) FROM t GROUP BY g;     -- DuckDB: GROUP BY ALL
-- HAVING        filter GROUPS (after aggregation)
--               ... GROUP BY g HAVING COUNT(*) > 3
-- ORDER BY      sort the final result
--               ORDER BY col DESC NULLS LAST
-- LIMIT         keep the first N rows
--               LIMIT 10 [OFFSET 20]
-- JOIN          combine tables horizontally using keys
--               a INNER|LEFT|RIGHT|FULL JOIN b ON a.k = b.k    /  CROSS JOIN b
-- CASE          if / else-if logic per row
--               CASE WHEN cond THEN v1 WHEN cond2 THEN v2 ELSE v3 END
-- COALESCE      first non-NULL value
--               COALESCE(a, b, 'default')
-- CTE           named temporary step: WITH step AS (SELECT ...) SELECT * FROM step;
-- SUBQUERY      a SELECT inside another query
--               WHERE x > (SELECT AVG(x) FROM t)   /  FROM (SELECT ...) AS s
-- UNION         stack results (UNION removes duplicates, UNION ALL keeps them)
--               SELECT a FROM t1 UNION ALL SELECT a FROM t2;
--               (also INTERSECT = in both, EXCEPT = in first only)
-- DATE FUNCTIONS
--               DATE_TRUNC('month', ts)   EXTRACT(YEAR FROM ts)   CAST(ts AS DATE)
--               ts + INTERVAL '7 days'    date_b - date_a (days)  CURRENT_DATE
-- TEXT FUNCTIONS
--               LOWER(x) UPPER(x) TRIM(x) LENGTH(x) SUBSTRING(x, 1, 3) REPLACE(x,'a','b') CONCAT(a,b)
-- WINDOW FUNCTIONS
--               fn(...) OVER (PARTITION BY g ORDER BY o ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
--               rows stay, an extra calculation is added; cannot be used in WHERE
-- ROW_NUMBER    unique sequence 1,2,3 per window (use for dedup / top-1)
--               ROW_NUMBER() OVER (PARTITION BY k ORDER BY d DESC)
-- RANK          rank with gaps after ties (1,2,2,4)
--               RANK() OVER (PARTITION BY g ORDER BY score DESC)
-- DENSE_RANK    rank without gaps (1,2,2,3)
--               DENSE_RANK() OVER (ORDER BY score DESC)
-- LAG           value from a PREVIOUS row (NULL at the start)
--               LAG(col, 1, default) OVER (PARTITION BY g ORDER BY d)
-- LEAD          value from a NEXT row (NULL at the end)
--               LEAD(col, 1, default) OVER (PARTITION BY g ORDER BY d)
--
-- EXTRA REMINDERS
--   Execution order : FROM -> WHERE -> GROUP BY -> HAVING -> SELECT (windows) -> ORDER BY -> LIMIT
--   WHERE = rows, HAVING = groups.   NULL: use IS NULL, never = NULL.
--   Before every JOIN: what is the GRAIN?  After every JOIN: did the row count change?
--   Top-N per group: ROW_NUMBER() in a CTE, then WHERE rn <= N.   (DuckDB: QUALIFY)






-- ##########################################################################
-- ##########################################################################
-- ##                                                                      ##
-- ##   ANSWER KEY — STOP! SOLVE THE EXERCISES OF PART 19 FIRST.           ##
-- ##                                                                      ##
-- ##   (Tip: in your editor, fold this section, or cut it into a          ##
-- ##    separate file once you have the feel of the notebook.)            ##
-- ##                                                                      ##
-- ##########################################################################
-- ##########################################################################
-- Your answer may differ and still be correct. Compare RESULTS (row counts and values), not text.
-- Run this key as a whole only after the exercises: it re-creates a few practice_ tables.






-- ======================== LEVEL 1 — ANSWERS ========================
-- 1.1
SELECT * FROM company_dim;
-- 1.2
SELECT job_title, job_country FROM job_postings;
-- 1.3
SELECT DISTINCT job_country FROM job_postings;
-- 1.4
SELECT * FROM job_postings WHERE job_country = 'France';
-- 1.5
SELECT * FROM job_postings WHERE job_title_short = 'Data Engineer' AND job_country = 'United States';
-- 1.6
SELECT * FROM job_postings WHERE salary_year_avg IS NULL;
-- 1.7
SELECT * FROM job_postings WHERE salary_year_avg BETWEEN 100000 AND 130000;
-- 1.8   (ILIKE = case-insensitive; alternative: LOWER(job_title) LIKE '%engineer%')
SELECT job_id, job_title FROM job_postings WHERE job_title ILIKE '%engineer%';
-- 1.9
SELECT * FROM job_postings WHERE job_country IN ('France', 'Germany');
-- 1.10
SELECT job_id, job_title, salary_year_avg
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY salary_year_avg DESC
LIMIT 3;


-- ======================== LEVEL 2 — ANSWERS ========================
-- 2.1
SELECT COUNT(*) AS total_postings FROM job_postings;
-- 2.2   (COUNT(col) ignores NULLs)
SELECT COUNT(salary_year_avg) AS postings_with_salary FROM job_postings;
-- 2.3
SELECT AVG(salary_year_avg) AS avg_salary_de FROM job_postings WHERE job_title_short = 'Data Engineer';
-- 2.4
SELECT MIN(salary_year_avg) AS min_salary, MAX(salary_year_avg) AS max_salary FROM job_postings;
-- 2.5
SELECT job_country, COUNT(*) AS n_postings FROM job_postings GROUP BY job_country ORDER BY n_postings DESC;
-- 2.6
SELECT job_country, AVG(salary_year_avg) AS avg_salary
FROM job_postings
GROUP BY job_country
ORDER BY avg_salary DESC NULLS LAST;
-- 2.7   (HAVING filters groups)
SELECT job_country, COUNT(*) AS n_postings
FROM job_postings
GROUP BY job_country
HAVING COUNT(*) > 3;
-- 2.8
SELECT job_title_short, COUNT(*) AS n_remote
FROM job_postings
WHERE job_work_from_home
GROUP BY job_title_short;
-- 2.9   (WHERE for rows, HAVING for the group average)
SELECT job_country, AVG(salary_year_avg) AS avg_salary
FROM job_postings
WHERE job_schedule_type = 'Full-time' AND salary_year_avg IS NOT NULL
GROUP BY job_country
HAVING AVG(salary_year_avg) > 110000;
-- 2.10
SELECT job_country, COUNT(DISTINCT company_id) AS n_companies
FROM job_postings
GROUP BY job_country;


-- ======================== LEVEL 3 — ANSWERS ========================
-- 3.1
SELECT jp.job_id, jp.job_title, cd.name AS company_name
FROM job_postings AS jp
JOIN company_dim AS cd ON cd.company_id = jp.company_id;
-- 3.2   (LEFT JOIN from companies; COUNT(right key), not COUNT(*))
SELECT cd.name, COUNT(jp.job_id) AS n_postings
FROM company_dim AS cd
LEFT JOIN job_postings AS jp ON jp.company_id = cd.company_id
GROUP BY cd.name
ORDER BY n_postings DESC;
-- 3.3
SELECT cd.company_id, cd.name
FROM company_dim AS cd
LEFT JOIN job_postings AS jp ON jp.company_id = cd.company_id
WHERE jp.job_id IS NULL;
-- 3.4
SELECT sj.job_id, s.skills
FROM skills_job_dim AS sj
JOIN skills_dim AS s ON s.skill_id = sj.skill_id
ORDER BY sj.job_id, s.skills;
-- 3.5
SELECT s.skills, COUNT(*) AS n_jobs
FROM skills_job_dim AS sj
JOIN skills_dim AS s ON s.skill_id = sj.skill_id
GROUP BY s.skills
ORDER BY n_jobs DESC, s.skills;
-- 3.6
SELECT jp.job_id, jp.job_title
FROM job_postings AS jp
LEFT JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id
WHERE sj.job_id IS NULL;
-- 3.7
SELECT cd.name, ROUND(AVG(jp.salary_year_avg), 0) AS avg_salary
FROM job_postings AS jp
JOIN company_dim AS cd ON cd.company_id = jp.company_id
GROUP BY cd.name;
-- 3.8
SELECT s.skills, COUNT(*) AS n_jobs
FROM job_postings AS jp
JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id
JOIN skills_dim AS s ON s.skill_id = sj.skill_id
WHERE jp.job_title_short = 'Data Engineer'
GROUP BY s.skills
ORDER BY n_jobs DESC, s.skills
LIMIT 3;
-- 3.9   (12 -> 27: one posting appears once per skill; job 6 disappears with INNER JOIN)
SELECT (SELECT COUNT(*) FROM job_postings) AS rows_before,
       (SELECT COUNT(*) FROM job_postings AS jp JOIN skills_job_dim AS sj ON sj.job_id = jp.job_id) AS rows_after;
-- 3.10
SELECT a.company_id, a.job_id AS job_a, b.job_id AS job_b,
       CAST(a.job_posted_date AS DATE) AS date_a, CAST(b.job_posted_date AS DATE) AS date_b
FROM job_postings AS a
JOIN job_postings AS b ON a.company_id = b.company_id AND a.job_id < b.job_id
ORDER BY a.company_id, a.job_id, b.job_id;


-- ======================== LEVEL 4 — ANSWERS ========================
-- 4.1
SELECT job_id, salary_year_avg,
       CASE WHEN salary_year_avg IS NULL   THEN 'Unknown'
            WHEN salary_year_avg >= 140000 THEN 'High'
            WHEN salary_year_avg >= 100000 THEN 'Mid'
            ELSE 'Low' END AS salary_band
FROM job_postings;
-- 4.2
WITH banded AS (
    SELECT CASE WHEN salary_year_avg IS NULL   THEN 'Unknown'
                WHEN salary_year_avg >= 140000 THEN 'High'
                WHEN salary_year_avg >= 100000 THEN 'Mid'
                ELSE 'Low' END AS salary_band
    FROM job_postings
)
SELECT salary_band, COUNT(*) AS n_postings FROM banded GROUP BY salary_band ORDER BY n_postings DESC;
-- 4.3
SELECT job_country,
       COUNT(CASE WHEN job_work_from_home THEN 1 END)     AS n_remote,
       COUNT(CASE WHEN NOT job_work_from_home THEN 1 END) AS n_onsite
FROM job_postings
GROUP BY job_country;
-- 4.4   (zeros are fake salaries: they pull the average down. NULL means "unknown", not 0)
SELECT AVG(salary_year_avg) AS avg_ignoring_nulls,
       AVG(COALESCE(salary_year_avg, 0)) AS avg_nulls_as_zero
FROM job_postings;
-- 4.5
SELECT COUNT(DISTINCT job_title) AS distinct_raw,
       COUNT(DISTINCT LOWER(TRIM(job_title))) AS distinct_clean
FROM job_postings;
-- 4.6
SELECT job_id, UPPER(SUBSTRING(job_title, 1, 10)) AS title_10
FROM job_postings;
-- 4.7
SELECT DATE_TRUNC('month', job_posted_date) AS posted_month, COUNT(*) AS n_postings
FROM job_postings
GROUP BY DATE_TRUNC('month', job_posted_date)
ORDER BY posted_month;
-- 4.8
SELECT job_id, job_posted_date
FROM job_postings
WHERE job_posted_date >= '2025-01-01' AND job_posted_date < '2025-04-01';
-- 4.9
SELECT job_id, DATE '2025-06-01' - CAST(job_posted_date AS DATE) AS days_old
FROM job_postings;
-- 4.10
SELECT job_country,
       COUNT(CASE WHEN job_work_from_home THEN 1 END) * 1.0 / NULLIF(COUNT(*), 0) AS remote_share
FROM job_postings
GROUP BY job_country;


-- ======================== LEVEL 5 — ANSWERS ========================
-- 5.1
SELECT job_id, salary_year_avg
FROM job_postings
WHERE salary_year_avg > (SELECT AVG(salary_year_avg) FROM job_postings);
-- 5.2
SELECT job_id, company_id, salary_year_avg
FROM job_postings
WHERE company_id IN (SELECT company_id FROM job_postings WHERE salary_year_avg >= 150000);
-- 5.3
SELECT AVG(company_avg) AS avg_of_company_avgs
FROM (SELECT company_id, AVG(salary_year_avg) AS company_avg FROM job_postings GROUP BY company_id) AS s;
-- 5.4
SELECT jp.job_id, jp.company_id, jp.salary_year_avg
FROM job_postings AS jp
WHERE jp.salary_year_avg > (SELECT AVG(x.salary_year_avg) FROM job_postings AS x WHERE x.company_id = jp.company_id);
-- 5.5
WITH overall AS (SELECT AVG(salary_year_avg) AS avg_salary FROM job_postings)
SELECT jp.job_id, jp.salary_year_avg
FROM job_postings AS jp
CROSS JOIN overall AS o
WHERE jp.salary_year_avg > o.avg_salary;
-- 5.6
WITH n_per_company AS (
    SELECT company_id, COUNT(*) AS n_postings FROM job_postings GROUP BY company_id
),
salary_per_company AS (
    SELECT company_id, ROUND(AVG(salary_year_avg), 0) AS avg_salary FROM job_postings GROUP BY company_id
)
SELECT cd.name, n.n_postings, s.avg_salary
FROM company_dim AS cd
JOIN n_per_company AS n ON n.company_id = cd.company_id
JOIN salary_per_company AS s ON s.company_id = cd.company_id;
-- 5.7
WITH jobs_per_skill AS (SELECT skill_id, COUNT(*) AS n_jobs FROM skills_job_dim GROUP BY skill_id)
SELECT s.skills, COALESCE(j.n_jobs, 0) AS n_jobs
FROM skills_dim AS s
LEFT JOIN jobs_per_skill AS j ON j.skill_id = s.skill_id
ORDER BY n_jobs DESC, s.skills;
-- 5.8
SELECT cd.name
FROM company_dim AS cd
WHERE EXISTS (SELECT 1 FROM job_postings AS jp WHERE jp.company_id = cd.company_id AND jp.job_work_from_home);
-- 5.9
WITH monthly AS (
    SELECT DATE_TRUNC('month', job_posted_date) AS posted_month, COUNT(*) AS n_postings
    FROM job_postings GROUP BY 1
)
SELECT posted_month, n_postings
FROM monthly
WHERE n_postings > (SELECT AVG(n_postings) FROM monthly)
ORDER BY posted_month;
-- 5.10
WITH top_skills AS (
    SELECT skill_id FROM skills_job_dim GROUP BY skill_id ORDER BY COUNT(*) DESC, skill_id LIMIT 3
),
jobs_with_top_skills AS (
    SELECT DISTINCT sj.job_id FROM skills_job_dim AS sj JOIN top_skills AS t ON t.skill_id = sj.skill_id
)
SELECT COUNT(DISTINCT jp.company_id) AS n_companies
FROM job_postings AS jp
JOIN jobs_with_top_skills AS j ON j.job_id = jp.job_id;


-- ======================== LEVEL 6 — ANSWERS ========================
-- 6.1  GRAIN
--   job_postings       : one row = one job posting (PK job_id)
--   skills_job_dim     : one row = one (job, skill) pair (PK job_id + skill_id)
--   fact_job_postings  : one row = one job posting (same as the source grain, with dimension keys)
-- 6.2  KEYS
--   company_dim.company_id (PK)            skills_dim.skill_id (PK)
--   job_postings.job_id (PK)               job_postings.company_id (FK -> company_dim.company_id)
--   skills_job_dim (job_id, skill_id) composite PK
--   skills_job_dim.job_id (FK -> job_postings) and skills_job_dim.skill_id (FK -> skills_dim)
--   Relationships: company 1-to-many postings; postings many-to-many skills (via the bridge).
-- 6.3
DROP TABLE IF EXISTS practice_dim_skill;
CREATE TABLE practice_dim_skill (
    skill_key   INTEGER PRIMARY KEY,          -- surrogate key (generated by the warehouse)
    skill_id    INTEGER NOT NULL UNIQUE,      -- natural/source id
    skill_name  VARCHAR NOT NULL,
    skill_type  VARCHAR
);
-- 6.4
--   salary_year_avg      -> FACT measure (numeric, aggregated with SUM/AVG)
--   company name         -> DIMENSION attribute (dim_company.company_name)
--   job_posted_date      -> FACT key (date_key pointing to dim_date); the date details are DIMENSION attributes
--   job_work_from_home   -> low-cardinality flag: either a FACT degenerate attribute/flag or a DIMENSION attribute
--                           (dim_job). Both are acceptable if documented.
--   skill name           -> DIMENSION attribute (dim_skill.skill_name)
-- 6.5
DROP TABLE IF EXISTS practice_bridge_job_skill;
CREATE TABLE practice_bridge_job_skill (
    job_id    INTEGER NOT NULL,
    skill_id  INTEGER NOT NULL,
    PRIMARY KEY (job_id, skill_id)            -- grain: one row per job-skill pair
);
--   Why not 'sql,python,aws' in one column? You cannot join, filter, count or enforce
--   referential integrity on it (1NF violation); queries need fragile string parsing,
--   and it breaks the atomic-value principle. A bridge table keeps each fact in its own row.
--   Putting skill_id directly in the job-grain fact would repeat each posting once per skill
--   (changing the grain and double-counting salaries).
DROP TABLE IF EXISTS practice_bridge_job_skill;     -- cleanup of the demo
DROP TABLE IF EXISTS practice_dim_skill;


-- ======================== LEVEL 7 — ANSWERS ========================
-- 7.1
SELECT job_id, salary_year_avg, AVG(salary_year_avg) OVER () AS overall_avg
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_id;
-- 7.2
SELECT job_id, job_country, salary_year_avg,
       AVG(salary_year_avg) OVER (PARTITION BY job_country) AS avg_country
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_id;
-- 7.3
SELECT job_id, job_country, salary_year_avg,
       ROUND(AVG(salary_year_avg) OVER (PARTITION BY job_country), 0) AS avg_country,
       ROUND(salary_year_avg - AVG(salary_year_avg) OVER (PARTITION BY job_country), 0) AS diff_vs_country
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, job_id;
-- 7.4
SELECT job_id, job_posted_date,
       ROW_NUMBER() OVER (ORDER BY job_posted_date, job_id) AS row_num
FROM job_postings
ORDER BY row_num;
-- 7.5
SELECT job_id, job_country, salary_year_avg,
       RANK() OVER (PARTITION BY job_country ORDER BY salary_year_avg DESC) AS salary_rank
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_country, salary_rank;
-- 7.6   RANK leaves gaps after ties (1,1,3); DENSE_RANK does not (1,1,2).
SELECT job_id, job_country, job_title_short,
       RANK()       OVER (PARTITION BY job_country ORDER BY job_title_short) AS rnk,
       DENSE_RANK() OVER (PARTITION BY job_country ORDER BY job_title_short) AS dense_rnk
FROM job_postings
ORDER BY job_country, job_title_short, job_id;
-- 7.7
WITH ranked AS (
    SELECT job_id, job_country, salary_year_avg,
           ROW_NUMBER() OVER (PARTITION BY job_country ORDER BY salary_year_avg DESC, job_id) AS rn
    FROM job_postings
    WHERE salary_year_avg IS NOT NULL
)
SELECT job_id, job_country, salary_year_avg, rn FROM ranked WHERE rn <= 2 ORDER BY job_country, rn;
-- 7.8
WITH ranked AS (
    SELECT company_id, job_id, job_posted_date,
           ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY job_posted_date DESC, job_id DESC) AS rn
    FROM job_postings
)
SELECT company_id, job_id, job_posted_date FROM ranked WHERE rn = 1 ORDER BY company_id;
-- 7.9
SELECT company_id, job_id,
       CAST(job_posted_date AS DATE) AS posted_day,
       LAG(CAST(job_posted_date AS DATE)) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS prev_posted_day,
       CAST(job_posted_date AS DATE)
         - LAG(CAST(job_posted_date AS DATE)) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS days_since_prev
FROM job_postings
ORDER BY company_id, job_posted_date;
-- 7.10
SELECT company_id, job_id, salary_year_avg,
       LEAD(salary_year_avg) OVER (PARTITION BY company_id ORDER BY job_posted_date) AS next_salary
FROM job_postings
ORDER BY company_id, job_posted_date;
-- 7.11
WITH monthly AS (
    SELECT DATE_TRUNC('month', job_posted_date) AS posted_month, COUNT(*) AS n_postings
    FROM job_postings GROUP BY 1
)
SELECT posted_month, n_postings,
       SUM(n_postings) OVER (ORDER BY posted_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM monthly
ORDER BY posted_month;
-- 7.12
SELECT job_id, CAST(job_posted_date AS DATE) AS posted_day, salary_year_avg,
       SUM(salary_year_avg) OVER (ORDER BY job_posted_date, job_id
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_salary
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_posted_date, job_id;
-- 7.13
SELECT job_id, CAST(job_posted_date AS DATE) AS posted_day, salary_year_avg,
       ROUND(AVG(salary_year_avg) OVER (ORDER BY job_posted_date, job_id
                                        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3
FROM job_postings
WHERE salary_year_avg IS NOT NULL
ORDER BY job_posted_date, job_id;
-- 7.14
SELECT job_country,
       COUNT(*) AS n_postings,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all
FROM job_postings
GROUP BY job_country
ORDER BY n_postings DESC;
-- 7.15
WITH monthly AS (
    SELECT DATE_TRUNC('month', job_posted_date) AS posted_month, COUNT(*) AS n_postings
    FROM job_postings GROUP BY 1
)
SELECT posted_month, n_postings,
       n_postings - LAG(n_postings) OVER (ORDER BY posted_month) AS change_vs_prev_month
FROM monthly
ORDER BY posted_month;


-- ======================== LEVEL 8 — ANSWERS ========================
-- 8.1
DROP TABLE IF EXISTS practice_stg_postings;
CREATE TABLE practice_stg_postings AS
SELECT job_id,
       LOWER(TRIM(job_title))            AS job_title_clean,
       job_country,
       CAST(job_posted_date AS DATE)     AS posted_date,
       salary_year_avg
FROM job_postings;
-- 8.2   (zero rows = OK)
SELECT job_id, COUNT(*) AS n FROM job_postings GROUP BY job_id HAVING COUNT(*) > 1;
-- 8.3
SELECT COUNT(*) - COUNT(company_id)      AS null_company_id,
       COUNT(*) - COUNT(job_country)     AS null_job_country,
       COUNT(*) - COUNT(job_posted_date) AS null_job_posted_date,
       COUNT(*) - COUNT(salary_year_avg) AS null_salary
FROM job_postings;
-- 8.4   (zero rows = OK)
SELECT jp.job_id, jp.company_id
FROM job_postings AS jp
WHERE jp.company_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM company_dim AS cd WHERE cd.company_id = jp.company_id);
-- 8.5
SELECT s.n AS source_rows, f.n AS fact_rows,
       CASE WHEN s.n = f.n THEN 'OK' ELSE 'MISMATCH' END AS status
FROM (SELECT COUNT(*) AS n FROM job_postings) AS s
CROSS JOIN (SELECT COUNT(*) AS n FROM fact_job_postings) AS f;
-- 8.6
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY CAST(loaded_at AS TIMESTAMP) DESC) AS rn
    FROM raw_job_postings
)
SELECT job_id, company_name, job_title, salary_year_avg, loaded_at
FROM ranked
WHERE rn = 1
ORDER BY job_id;
-- 8.7
DROP TABLE IF EXISTS practice_dim_company;
CREATE TABLE practice_dim_company AS
SELECT ROW_NUMBER() OVER (ORDER BY company_id) AS company_key,
       company_id                              AS company_id_source,
       name                                    AS company_name
FROM company_dim;
-- 8.8
DROP TABLE IF EXISTS practice_mart_monthly;
CREATE TABLE practice_mart_monthly AS
SELECT job_country,
       DATE_TRUNC('month', job_posted_date)  AS posted_month,
       COUNT(*)                              AS n_postings,
       ROUND(AVG(salary_year_avg), 0)        AS avg_salary
FROM job_postings
GROUP BY job_country, DATE_TRUNC('month', job_posted_date);
-- 8.9
SELECT b.n AS rows_before, a.n AS rows_after,
       CASE WHEN a.n = b.n THEN 'OK: no multiplication' ELSE 'PROBLEM: join changed the row count' END AS status
FROM (SELECT COUNT(*) AS n FROM job_postings) AS b
CROSS JOIN (SELECT COUNT(*) AS n
            FROM job_postings AS jp
            LEFT JOIN company_dim AS cd ON cd.company_id = jp.company_id) AS a;
-- 8.10  Full refresh (idempotent): the result is the same no matter how many times it runs.
DROP TABLE IF EXISTS practice_mart_monthly;
CREATE TABLE practice_mart_monthly AS
SELECT job_country,
       DATE_TRUNC('month', job_posted_date)  AS posted_month,
       COUNT(*)                              AS n_postings,
       ROUND(AVG(salary_year_avg), 0)        AS avg_salary
FROM job_postings
GROUP BY job_country, DATE_TRUNC('month', job_posted_date);
--   Alternative for incremental loads: DELETE FROM target WHERE posted_month = :month;
--   then INSERT ... SELECT for that month only (partition overwrite), or INSERT ... ON CONFLICT DO UPDATE.


-- ==========================================================================
-- END OF FILE.  NEXT STEP: go back to the Window Functions section of the course (PART 14 is
-- your bridge), then Nested Functions -> Git/GitHub -> Data Warehouse & ETL -> Projects.
-- ==========================================================================
