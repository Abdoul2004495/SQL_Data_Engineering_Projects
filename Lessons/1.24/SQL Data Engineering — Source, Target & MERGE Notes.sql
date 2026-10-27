```sql
/*
===============================================================================
        SQL DATA ENGINEERING — SOURCE / TARGET / MERGE
        Job Postings Project — Luke Barousse
===============================================================================


===============================================================================
1. THE MAIN CONCEPT: SOURCE VS TARGET
===============================================================================

SOURCE
------
The SOURCE contains the data that I want to use to populate,
update, or synchronize another table.

TARGET
------
The TARGET is the table that I want to create or modify.


SIMPLE RULE TO REMEMBER
-----------------------

    SOURCE = "Here is the data that I want to apply."

    TARGET = "Here is the table that I want to bring to this state."


General schema:

    SOURCE
       |
       |  data / transformations
       v
    TARGET


In a MERGE:

    SOURCE                         TARGET
    src_priority_jobs      --->    priority_jobs_snapshot

    "Here is the current          "Here is the table
     data."                         to modify."


===============================================================================
2. IMPORTANT: A TABLE IS NOT ALWAYS SOURCE OR TARGET
===============================================================================

The role of a table depends on the operation I am performing.

Example:

    CREATE TABLE src_priority_jobs AS
    SELECT ...
    FROM data_jobs.job_postings_fact;


Here:

    data_jobs.job_postings_fact
              |
              | SELECT / transformation
              v
    src_priority_jobs


Therefore:

    job_postings_fact = SOURCE
    src_priority_jobs = TARGET


But later:

    MERGE INTO main.priority_jobs_snapshot AS tgt
    USING src_priority_jobs AS src


Now:

    src_priority_jobs          = SOURCE
    priority_jobs_snapshot     = TARGET


Therefore:

    SOURCE / TARGET depends on the operation.


===============================================================================
3. THE COMPLETE WORKFLOW OF THE PROJECT
===============================================================================

The data comes from several tables:

    data_jobs.job_postings_fact
              +
    data_jobs.company_dim
              +
    staging.priority_roles
              |
              | JOIN + SELECT + TRANSFORMATION
              v
       src_priority_jobs
              |
              | MERGE
              v
    main.priority_jobs_snapshot


We can think of this as a small ETL/ELT pipeline:

    EXTRACT
       |
       v
    TRANSFORM
       |
       v
    LOAD / SYNC
       |
       v
    TARGET


===============================================================================
4. FIRST STEP: BUILD THE INTERMEDIATE SOURCE
===============================================================================

Example:

    CREATE OR REPLACE TEMP TABLE src_priority_jobs AS

    SELECT
        jpf.job_id,
        jpf.job_title_short,
        cd.name AS company_name,
        jpf.job_posted_date,
        jpf.salary_year_avg,
        r.priority_lvl,
        CURRENT_TIMESTAMP AS updated_at

    FROM data_jobs.job_postings_fact AS jpf

    LEFT JOIN data_jobs.company_dim AS cd
        ON jpf.company_id = cd.company_id

    INNER JOIN staging.priority_roles AS r
        ON jpf.job_title_short = r.role_name;


This code builds:

    job_postings_fact
            +
       company_dim
            +
      priority_roles
            |
            | JOIN + transformation
            v
    src_priority_jobs


Why create src_priority_jobs?

Because I first want to prepare exactly the data
that should be present in my final table.

Instead of doing everything directly:

    3 tables
       |
       | JOIN
       | transformation
       | UPDATE
       | INSERT
       | DELETE
       v
    TARGET


I do:

    3 tables
       |
       | JOIN / transformation
       v
    src_priority_jobs
       |
       | MERGE
       v
    TARGET


This makes the process clearer and easier to control.


===============================================================================
5. WHY USE A TEMP TABLE?
===============================================================================

    CREATE OR REPLACE TEMP TABLE src_priority_jobs


TEMP means that the table is temporary.

It acts as a preparation/staging area.

Schema:

    SOURCE TABLES
          |
          v
    TRANSFORMATION
          |
          v
    TEMP TABLE
    src_priority_jobs
          |
          v
        MERGE
          |
          v
    FINAL TABLE
    priority_jobs_snapshot


The TEMP TABLE is therefore not necessarily the final table.

It is used to prepare the data before applying it.


===============================================================================
6. THE JOINS IN THE SOURCE
===============================================================================

First JOIN:

    LEFT JOIN data_jobs.company_dim AS cd
        ON jpf.company_id = cd.company_id


We start from:

    job_postings_fact
          |
          | company_id
          v
    company_dim


Objective:

    Retrieve the company name.


Why LEFT JOIN?

Because I want to keep the jobs even if no matching company
is found.

Example:

    job_postings_fact

    job_id    company_id
    100       25
    101       30
    102       50


    company_dim

    company_id    name
    25            Google
    30            Microsoft


Result with LEFT JOIN:

    job_id    company
    100       Google
    101       Microsoft
    102       NULL


Job 102 remains in the result.


===============================================================================
7. INNER JOIN WITH priority_roles
===============================================================================

    INNER JOIN staging.priority_roles AS r
        ON jpf.job_title_short = r.role_name


We compare:

    job_title_short
           =
    role_name


Example:

    job_postings_fact

    job_title_short
    ----------------
    Data Analyst
    Data Engineer
    Teacher


    priority_roles

    role_name       priority_lvl
    ----------------------------
    Data Analyst        2
    Data Engineer       1


With INNER JOIN:

    Data Analyst   -> kept
    Data Engineer  -> kept
    Teacher        -> removed


Why?

Because INNER JOIN keeps only the rows
that have a matching record in both tables.


===============================================================================
8. NOW: MERGE
===============================================================================

The important part:

    MERGE INTO main.priority_jobs_snapshot AS tgt

    USING src_priority_jobs AS src

    ON tgt.job_id = src.job_id;


We can read this as:

    "Take the TARGET table and compare it with the SOURCE
     using job_id to identify the same job."


Schema:

    SOURCE                              TARGET

    src_priority_jobs          --->    priority_jobs_snapshot

    job_id = 100                        job_id = 100
    job_id = 101                        job_id = 101
    job_id = 102                        job_id = 103


The condition:

    ON tgt.job_id = src.job_id


is used to determine which rows represent the same job.


===============================================================================
9. WHY IS job_id IMPORTANT?
===============================================================================

I need a key that allows me to identify a row.

In this project:

    job_id


is used as the identifier.

Example:

    TARGET                  SOURCE

    job_id = 100      <-->  job_id = 100

    Same job
       |
       v
    MATCHED


But:

    TARGET                  SOURCE

    job_id = 100      <-->  job_id = 200

    Not the same job
       |
       v
    NOT MATCHED


The key allows me to answer:

    "Does this row already exist?"


===============================================================================
10. WHEN MATCHED
===============================================================================

    WHEN MATCHED
    AND tgt.priority_lvl IS DISTINCT FROM src.priority_lvl
    THEN UPDATE


This means:

    The job exists in SOURCE and TARGET
    +
    The priority is different
    =
    UPDATE


Example:

    TARGET                  SOURCE

    job_id = 100            job_id = 100
    priority = 2            priority = 1


Same job:

    100 = 100
       |
       v
    MATCHED


But:

    2 != 1
       |
       v
    UPDATE


===============================================================================
11. WHY USE src.priority_lvl FOR UPDATE?
===============================================================================

Example:

    UPDATE
    SET priority_lvl = src.priority_lvl


This means:

    SOURCE
    priority_lvl = 1
          |
          v
    TARGET
    priority_lvl = 1


The SOURCE contains the new value.

Therefore:

    src.priority_lvl
            |
            v
    tgt.priority_lvl


If I did:

    SET priority_lvl = tgt.priority_lvl


I would simply put the old TARGET value back.

That would not be useful.


RULE:

    To update TARGET with the new data:

    SOURCE ---> TARGET


===============================================================================
12. WHEN NOT MATCHED
===============================================================================

    WHEN NOT MATCHED THEN
        INSERT (...)


This means:

    The row exists in SOURCE
    BUT
    it does not exist in TARGET.


Example:

    TARGET                  SOURCE

    job 1                   job 1
    job 2                   job 2
                            job 3


job 3 exists only in SOURCE.


Therefore:

    job 3
      |
      v
    INSERT INTO TARGET


Why?

Because the TARGET needs to receive this new job.


===============================================================================
13. WHY DOES INSERT USE src.xxx?
===============================================================================

Example:

    VALUES (
        src.job_id,
        src.job_title_short,
        src.company_name,
        src.job_posted_date,
        src.salary_year_avg,
        src.priority_lvl,
        src.updated_at
    )


The new row comes from the SOURCE.


Therefore:

    SOURCE
       |
       | new row
       v
    TARGET


That is why we use:

    src.job_id
    src.job_title_short
    src.company_name
    src.priority_lvl
    etc.


===============================================================================
14. WHEN NOT MATCHED BY SOURCE
===============================================================================

    WHEN NOT MATCHED BY SOURCE THEN DELETE;


This is the opposite situation.


It means:

    A row exists in TARGET
    BUT
    it no longer exists in SOURCE.


Example:

    TARGET                  SOURCE

    job 1                   job 1
    job 2                   job 2
    job 3


job 3 exists in TARGET
but it does not exist in SOURCE.


Therefore:

    job 3
      |
      v
    DELETE FROM TARGET


Why?

Because the TARGET should be synchronized with the SOURCE.


===============================================================================
15. THE 4 MERGE SITUATIONS
===============================================================================

                        SOURCE
                           |
                           v
                      Comparison
                           |
                           v
                         TARGET
                           |
             +-------------+-------------+
             |             |             |
             v             v             v

          MATCHED      NOT MATCHED   NOT MATCHED
                                     BY SOURCE


1. MATCHED
-----------

Exists in SOURCE + TARGET

    SOURCE       TARGET
      100   <-->   100

Action:

    UPDATE if the data has changed.


2. NOT MATCHED
--------------

Exists only in SOURCE

    SOURCE       TARGET
      200          -

Action:

    INSERT


3. NOT MATCHED BY SOURCE
------------------------

Exists only in TARGET

    SOURCE       TARGET
       -          300

Action:

    DELETE


4. MATCHED BUT NO CHANGE
------------------------

    SOURCE       TARGET
      400   <-->   400

And:

    source priority = target priority


Action:

    Nothing


===============================================================================
16. TABLE TO MEMORIZE
===============================================================================

    +------------------------------+----------+
    | Situation                    | Action   |
    +------------------------------+----------+
    | Source + Target              | Nothing  |
    | Source + Target + change     | UPDATE   |
    | Source only                  | INSERT   |
    | Target only                  | DELETE   |
    +------------------------------+----------+


Therefore:

    MATCHED
        |
        +-- change ------------> UPDATE
        |
        +-- no change ---------> NOTHING


    NOT MATCHED
        |
        +----------------------> INSERT


    NOT MATCHED BY SOURCE
        |
        +----------------------> DELETE


===============================================================================
17. IS DISTINCT FROM
===============================================================================

In your code:

    AND tgt.priority_lvl IS DISTINCT FROM src.priority_lvl


We use:

    IS DISTINCT FROM


to correctly compare values even when NULLs are present.


Example:

    TARGET       SOURCE
    -------------------
    NULL           2


Result:

    IS DISTINCT FROM = TRUE


Therefore:

    UPDATE


Other examples:

    TARGET       SOURCE       Result
    ---------------------------------
      2            2          FALSE
      2            3          TRUE
     NULL          2          TRUE
      2           NULL        TRUE
     NULL         NULL        FALSE


This allows us to correctly detect changes.


===============================================================================
18. IMPORTANT: tgt / tgr ALIAS
===============================================================================

You previously wrote:

    AND tgr.priority_lvl IS DISTINCT FROM src.priority_lvl


But your alias is:

    main.priority_jobs_snapshot AS tgt


Therefore, you should write:

    AND tgt.priority_lvl IS DISTINCT FROM src.priority_lvl


Because:

    tgt = TARGET
    src = SOURCE


There is no "tgr" alias in this query.


===============================================================================
19. THE INITIAL FILE
===============================================================================

In the INITIAL file, you create the final table:

    CREATE OR REPLACE TABLE main.priority_jobs_snapshot


Then you populate this table:

    INSERT INTO main.priority_jobs_snapshot
    SELECT ...
    FROM data_jobs.job_postings_fact AS jpf
    ...


At this point:

    job_postings_fact
    company_dim
    priority_roles
          |
          | SOURCE(S)
          v
    priority_jobs_snapshot
          |
          v
        TARGET


Therefore, the tables used in the SELECT are the SOURCES,
and priority_jobs_snapshot is the TARGET.


===============================================================================
20. THE UPDATE FILE
===============================================================================

Later, you build:

    src_priority_jobs


Then:

    MERGE INTO main.priority_jobs_snapshot AS tgt
    USING src_priority_jobs AS src
    ON tgt.job_id = src.job_id


Now:

    src_priority_jobs
          |
          | SOURCE
          v
        MERGE
          |
          v
    priority_jobs_snapshot
          |
          | TARGET
          v
       UPDATE / SYNC


This is different from the initial INSERT.


===============================================================================
21. INSERT VS MERGE
===============================================================================

INSERT:

    "Add these new rows."


Example:

    INSERT INTO target
    SELECT ...
    FROM source;


Schema:

    SOURCE
      |
      | INSERT
      v
    TARGET


But MERGE is more complete:

    SOURCE
       |
       v
     MERGE
       |
       +---- MATCHED + change ----------> UPDATE
       |
       +---- NOT MATCHED ---------------> INSERT
       |
       +---- NOT MATCHED BY SOURCE ----> DELETE


MERGE therefore allows us to synchronize the two tables.


===============================================================================
22. HOW TO CHOOSE SOURCE AND TARGET
===============================================================================

When you see a Data Engineering SQL query,
ask yourself these questions:


QUESTION 1
----------

    "Which table contains the data I want to use?"

Answer:

    SOURCE


QUESTION 2
----------

    "Which table do I need to create or modify?"

Answer:

    TARGET


QUESTION 3
----------

    "How do I identify the same row?"

Answer:

    The KEY.

In this project:

    job_id


QUESTION 4
----------

    "If the row already exists, what should I do?"

Answer:

    MATCHED
       |
       +--> check for changes
              |
              +--> UPDATE


QUESTION 5
----------

    "If the row exists only in SOURCE?"

Answer:

    NOT MATCHED
       |
       +--> INSERT


QUESTION 6
----------

    "If the row exists only in TARGET?"

Answer:

    NOT MATCHED BY SOURCE
       |
       +--> DELETE


===============================================================================
23. THE MENTAL MODEL TO USE FOR ALL EXERCISES
===============================================================================

Before writing SQL, mentally draw this:


                  Where is my data?
                         |
                         v
                     SOURCE(S)
                         |
                         |
                    TRANSFORMATION
                         |
                         v
                    FINAL SOURCE
                         |
                         | MERGE / INSERT
                         v
                      TARGET


Then ask yourself:

    1. SOURCE?
    2. TARGET?
    3. KEY?
    4. UPDATE?
    5. INSERT?
    6. DELETE?


===============================================================================
24. YOUR COMPLETE PROJECT IN ONE SCHEMA
===============================================================================

    +--------------------------+
    | job_postings_fact        |
    +--------------------------+
                |
                |
                +-------------------+
                |                   |
                v                   v
    +----------------------+   +----------------------+
    | company_dim          |   | priority_roles      |
    +----------------------+   +----------------------+
                |                   |
                +---------+---------+
                          |
                          | JOIN + TRANSFORMATION
                          v
                +----------------------+
                | src_priority_jobs    |
                |                      |
                | TEMP TABLE           |
                +----------------------+
                          |
                          | SOURCE
                          |
                          | MERGE
                          v
                +----------------------+
                | priority_jobs_       |
                | snapshot             |
                |                      |
                | TARGET               |
                +----------------------+


===============================================================================
25. THE DATA ENGINEERING CONCEPT BEHIND THE EXERCISE
===============================================================================

This is not only a SQL syntax exercise.

You are learning a small DATA ENGINEERING process:


    SOURCES
       |
       v
    EXTRACTION
       |
       v
    TRANSFORMATION
       |
       v
    STAGING / TEMP TABLE
       |
       v
    MERGE / SYNCHRONIZATION
       |
       v
    TARGET


This is similar to a real data pipeline.


===============================================================================
26. FINAL SUMMARY TO MEMORIZE
===============================================================================

SOURCE
------
The data that I want to use to populate or update another table.


TARGET
------
The table that I want to create or modify.


KEY
---
The column used to identify the same row.

In this project:

    job_id


MATCHED
-------
The row exists in both SOURCE and TARGET.


NOT MATCHED
-----------
The row exists in SOURCE but not in TARGET.

    --> INSERT


NOT MATCHED BY SOURCE
---------------------
The row exists in TARGET but not in SOURCE.

    --> DELETE


MATCHED + CHANGE
----------------
The row exists in both, but a value has changed.

    --> UPDATE


SOURCE --> TARGET
-----------------

The SOURCE provides the new values.

The TARGET receives those values.


===============================================================================
27. THE MOST IMPORTANT SENTENCE
===============================================================================

    SOURCE = "Here is what I want to have."

    TARGET = "Here is the table I need to modify
              to achieve that result."


In your project:

    src_priority_jobs
           |
           | SOURCE
           v
         MERGE
           |
           v
    priority_jobs_snapshot
           |
           | TARGET


And therefore:

    SOURCE --> TARGET


===============================================================================
*/
```
