SELECT
    cd.name AS company_name,
    COUNT(job_id) AS job_count,
    CASE
        WHEN job_count > 100 THEN '100 + WFH DE jobs'
        WHEN job_count >= 50 THEN '50-100 WFH DE jobs'
        WHEN job_count >= 25 THEN '25-49 + WFH DE jobs'
        ELSE 'Less than 25 WFH DE jobs'
    END AS WFH_DE_job_Category,
FROM data_jobs.job_postings_fact AS jpf
INNER JOIN data_jobs.company_dim AS cd
    ON jpf.company_id = cd.company_id
WHERE job_work_from_home = TRUE and job_title_short = 'Data Engineer'
GROUP BY company_name
ORDER BY job_count DESC
LIMIT 100;