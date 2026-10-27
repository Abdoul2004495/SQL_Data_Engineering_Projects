SELECT
    job_id,
    job_title,
    salary_year_avg,
    CASE
        WHEN job_title LIKE '%Lead%' OR job_title LIKE '%Manager%' THEN 'Lead/Manager'
        WHEN job_title LIKE '%Lead%' THEN 'Senior'
        WHEN job_title LIKE '%junior%' OR job_title LIKE '%Entry%' THEN 'junior/Entry'
        ELSE 'Not Specified'
    END AS experience_level,
    CASE
        WHEN job_work_from_home = TRUE THEN 'Yes'
        ELSE 'No'
    END AS remote_option
FROM job_postings_fact
WHERE salary_year_avg IS NOT NULL
ORDER BY job_id;