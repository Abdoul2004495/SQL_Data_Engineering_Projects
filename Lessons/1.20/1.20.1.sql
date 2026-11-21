SELECT
    job_posted_date::DATE AS dt,
    COUNT(job_id) AS job_posting
FROM job_postings_fact
WHERE
    dt = '2024-12-31'
GROUP BY
    dt;