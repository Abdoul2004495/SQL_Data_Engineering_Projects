SELECT
    job_title_short,
    job_no_degree_mention::INT AS job_no_degree_mention,
    COUNT(job_id) AS job_posting
FROM job_postings_fact
WHERE
    job_posted_date::DATE BETWEEN '2024-12-31' AND '2024-12-31'
GROUP BY
    job_title_short,
    job_no_degree_mention
ORDER BY
    job_title_short,
    job_no_degree_mention;