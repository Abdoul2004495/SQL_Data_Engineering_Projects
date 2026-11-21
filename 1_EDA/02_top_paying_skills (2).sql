/*
Question: What are the highest-paying skills for data engineers?
- Calculate the median salary for each skill required in data engineer positions
- Focus on remote positions with specified salaries
- Include skill frequency to identify both salary and demand
- Why? Helps identify which skills command the highest compensation while also showing 
    how common those skills are, providing a more complete picture for skill development priorities
*/


SELECT
    sd.skills,
    ROUND(MEDIAN(jpf.salary_year_avg), 0 )AS median_salary,
    COUNT(jpf.*) AS demand_count
FROM job_postings_fact AS jpf 
INNER JOIN skills_job_dim AS sjd 
    ON jpf.job_id = sjd.job_id 
INNER JOIN skills_dim AS sd
    ON sjd.skill_id = sd.skill_id
WHERE 
    jpf.job_title_short = 'Data Engineer'
    AND jpf.job_work_from_home = TRUE
GROUP BY
    sd.skills
HAVING 
    COUNT(jpf.*) > 100
ORDER BY
    median_salary DESC
LIMIT 25;

/*
    Highest-Paying Skills for Data Engineers — Full Analysis

    Here's a breakdown of the highest-paying skills for Data Engineers:

Key Insights:
- GDPR now leads as the top-paying skill at $183.8K median salary, with solid demand (681 postings) — a notable shift from the previous ranking.
- Rust drops to second place at $171,875 median salary, still with limited demand (234 postings).
- Zoom and Neo4j follow closely, at $170,938 and $170K median salary respectively, both with modest demand (156 and 272 postings).
- Other notable skills with both high pay and moderate-to-high frequency include:
  - GraphQL: $168.5K median salary (454 postings)
  - Spring: $168,469 median salary (399 postings)
  - Terraform: $166K median salary (3,476 postings)
  - Kubernetes: $155K median salary (4,470 postings)
  - Airflow: $150K median salary (10,608 postings)
  - Kafka: $145K median salary (6,852 postings)
- Bitbucket, Ruby, Redis, Ansible, and Jupyter all appear in the top 25 for pay, each with hundreds of postings.
- Kafka enters the top 25 for the first time, combining a strong $145K median salary with very high demand (6,852 postings).
- Most skills on the list are no longer extreme statistical outliers with just a handful of postings; instead, many show consistently strong demand.

Takeaway: While the very top-paying skill (GDPR) still has less demand than major cloud and data tools, most of the top-paying skills have both solid salaries and significant demand. This suggests that learning tools like Terraform, Kubernetes, Spring, GraphQL, and especially core data engineering tools (Airflow, Kafka) provides a strong balance between compensation and marketability.
┌────────────┬───────────────┬──────────────┐
│   skills   │ median_salary │ demand_count │
│  varchar   │    double     │    int64     │
├────────────┼───────────────┼──────────────┤
│ gdpr       │      183802.0 │          681 │
│ rust       │      171875.0 │          234 │
│ zoom       │      170938.0 │          156 │
│ neo4j      │      170000.0 │          272 │
│ graphql    │      168500.0 │          454 │
│ spring     │      168469.0 │          399 │
│ terraform  │      166000.0 │         3476 │
│ mongo      │      158000.0 │          282 │
│ kubernetes │      155000.0 │         4470 │
│ django     │      155000.0 │          277 │
│ bitbucket  │      155000.0 │          497 │
│ sheets     │      152500.0 │          136 │
│ typescript │      150500.0 │          437 │
│ ruby       │      150000.0 │          762 │
│ airflow    │      150000.0 │        10608 │
│ css        │      150000.0 │          273 │
│ node       │      150000.0 │          209 │
│ fastapi    │      150000.0 │          248 │
│ redis      │      149500.0 │          648 │
│ ansible    │      148798.0 │          516 │
│ vmware     │      147597.0 │          154 │
│ golang     │      147500.0 │          923 │
│ react      │      145750.0 │          525 │
│ kafka      │      145000.0 │         6852 │
│ jupyter    │      143750.0 │          415 │
└────────────┴───────────────┴──────────────┘
  25 rows                         3 columns
*/