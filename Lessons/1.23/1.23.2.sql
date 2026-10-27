WITH invalid_salaries AS (
    SELECT
        job_id,
        job_title_short,
        job_location
    FROM job_postings_fact
    WHERE 
    salary_hour_avg IS NULL 
    AND salary_year_avg IS NULL
)

SELECT *
FROM invalid_salaries;