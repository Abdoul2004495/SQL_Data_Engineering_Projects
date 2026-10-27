SELECT *
FROM
(SELECT
    job_id,
    job_title_short,
    salary_year_avg
FROM job_postings_fact
WHERE job_work_from_home = TRUE
);