SELECT
    job_id,
    job_title_short,
    job_location,
    job_posted_date,
    EXTRACT(YEAR FROM job_posted_date) AS job_posted_year,
    EXTRACT(MONTH FROM job_posted_date) AS job_posted_month,
    EXTRACT(DAY FROM job_posted_date) AS job_posted_day,
    EXTRACT(QUARTER FROM job_posted_date) AS job_posted_quarter
FROM job_postings_fact
WHERE job_posted_date::DATE BETWEEN '2023-01-01' AND '2024-12-31';