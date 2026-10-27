/*
Question: What are the most in-demand skills for data engineers?
- Identify the 10 in-demand skill for dat engineers
- Focus on remote job postings
- Why??
    Retrieves the top 10 skills with the highest demand in the 
    remote job market, providing insights into the most valueble 
    skills for data engineers seeking remote work
*/

SELECT
    sd.skills,
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
ORDER BY
    demand_count DESC
LIMIT 10;

/*
Here's the breakdown of the most demanded skills for data engineers:
SQL and Python are by far the most in-demand skills, with around 31,000 job postings each - nearly double the next closest skill.
Cloud platforms round out the top skills, with AWS leading at ~19,000 postings, followed by Azure at ~15,000.
Apache Spark completes the top 5 with nearly 13,000 postings, highlighting the importance of big data processing skills.

Key takeaways:
- SQL and Python remain the foundational skills for data engineers
- Cloud platforms (AWS, Azure) are critical for modern data engineering
- Big data tools like Spark continue to be highly valued
- Data pipeline tools (Airflow, Snowflake, Databricks) show growing demand
- Java and GCP round out the top 10 most requested skills
┌────────────┬──────────────┐
│   skills   │ demand_count │
│  varchar   │    int64     │
├────────────┼──────────────┤
│ sql        │        31142 │
│ python     │        30641 │
│ aws        │        18996 │
│ azure      │        15228 │
│ spark      │        13420 │
│ airflow    │        10608 │
│ snowflake  │         9439 │
│ databricks │         8880 │
│ java       │         7537 │
│ gcp        │         7077 │
└────────────┴──────────────┘
  10 rows         2 columns

*/