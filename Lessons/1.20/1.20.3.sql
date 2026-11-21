SELECT
    jpf.job_title_short,
    AVG(jpf.salary_hour_avg * 40 * 52)::DECIMAL(10, 2) AS salary_hour_annual,
    AVG(jpf.salary_hour_avg * 40 * 52)::INT AS salary_hour_annual_zero_decimals
FROM 
    job_postings_fact AS jpf
WHERE
    jpf.salary_hour_avg IS NOT NULL
    AND jpf.job_country = 'United States'
GROUP BY
    jpf.job_title_short
ORDER BY
    salary_hour_annual DESC;
