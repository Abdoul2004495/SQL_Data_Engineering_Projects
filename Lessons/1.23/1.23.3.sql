SELECT
    jpf.job_id,
    jpf.job_title_short,
    jpf.job_location
FROM job_postings_fact AS jpf
WHERE company_id = (
    SELECT
        cd.company_id
    FROM company_dim AS cd
    WHERE name = 'Google'
)
    AND salary_year_avg > 100_000;