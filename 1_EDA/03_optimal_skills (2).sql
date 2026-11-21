/*
Question: What are the most optimal skills for data engineers—balancing both demand and salary?
- Create a ranking column that combines demand count and median salary to identify the most valuable skills.
- Focus only on remote Data Engineer positions with specified annual salaries.
- Why?
    - This approach highlights skills that balance market demand and financial reward. It weights core skills appropriately instead of letting rare, outlier skills distort the results.
    - The natural log transformation ensures that both high-salary and widely in-demand skills surface as the most practical and valuable to learn for data engineering careers.
*/

SELECT 
    sd.skills,
    ROUND(MEDIAN(jpf.salary_year_avg), 1) AS median_salary,
    COUNT(jpf.*) AS demand_count,
    ROUND(LN(COUNT(jpf.*)), 1) AS ln_demand_count,
    ROUND((LN(COUNT(jpf.*)) * MEDIAN(jpf.salary_year_avg))/1_000_000, 2) AS optimal_score
FROM job_postings_fact jpf
INNER JOIN skills_job_dim sjd ON jpf.job_id = sjd.job_id
INNER JOIN skills_dim sd ON sjd.skill_id = sd.skill_id
WHERE
    jpf.job_title_short = 'Data Engineer'
    AND jpf.salary_year_avg IS NOT NULL
    AND jpf.job_work_from_home = True 
GROUP BY
    sd.skills
HAVING 
    COUNT(sjd.job_id) >= 100
ORDER BY
    optimal_score DESC
LIMIT 25;

/*
Here's a breakdown of the most optimal skills for Data Engineers, based on both high demand and high salaries:

Top Skills by Optimal Score:
- Python now leads the list with a $135K median salary and 1,330 postings, resulting in the highest overall "optimal score".
- SQL follows closely with 1,349 postings (the highest demand on the list) and a $128.5K median salary.
- Airflow (468 postings, $150K median) and AWS (937 postings, $135K median) round out the top tier, both showing strong growth in demand.
- Terraform remains a standout, now with a $166K median salary and 222 postings — a jump in both pay and demand.
- Spark (588 postings, $140K median) continues to be a major big data technology with a strong optimal score.

DevOps & Engineering Tools:
- Kafka offers high compensation ($145K median) and growing demand (340 postings).
- Kubernetes ($155K median) and Snowflake ($135K/525 postings) show strong momentum, with Kubernetes' median salary climbing further.
- Git ($139K/234 postings) and Docker ($135K/167 postings) maintain broad utility and competitive compensation.

Noteworthy Languages:
- Java (342 postings, $135K median) and Scala (281 postings, $137.5K median) remain strong choices for well-paid data engineering roles.
- Go ($138.75K/138 postings) continues to deliver excellent compensation relative to its demand.
- Pandas makes a notable appearance ($140K/111 postings), reflecting growing demand for Python-based data tooling.

Databases & Cloud:
- Redshift ($130K/321 postings), GCP ($135K/234 postings), Hadoop ($133.85K/218 postings), NoSQL ($131.75K/220 postings), and MongoDB ($135K/158 postings) add to a well-rounded data engineering skill set.
- R and BigQuery each deliver competitive salaries and meet the threshold for demand, though BigQuery's median salary has softened slightly to $126K.

Summary:
Skills that consistently appear near the top balance a strong combination of market demand (job security) and financial benefit. Python, SQL, AWS, Airflow, Terraform, and Spark are particularly strategic for both immediate opportunities and longer-term career growth in data engineering.

┌────────────┬───────────────┬──────────────┬─────────────────┬───────────────┐
│   skills   │ median_salary │ demand_count │ ln_demand_count │ optimal_score │
│  varchar   │    double     │    int64     │     double      │    double     │
├────────────┼───────────────┼──────────────┼─────────────────┼───────────────┤
│ python     │      135000.0 │         1330 │             7.2 │          0.97 │
│ sql        │      128500.0 │         1349 │             7.2 │          0.93 │
│ airflow    │      150000.0 │          468 │             6.1 │          0.92 │
│ aws        │      135000.0 │          937 │             6.8 │          0.92 │
│ terraform  │      166000.0 │          222 │             5.4 │           0.9 │
│ spark      │      140000.0 │          588 │             6.4 │          0.89 │
│ kafka      │      145000.0 │          340 │             5.8 │          0.85 │
│ snowflake  │      135000.0 │          525 │             6.3 │          0.85 │
│ kubernetes │      155000.0 │          181 │             5.2 │          0.81 │
│ azure      │      125000.0 │          581 │             6.4 │           0.8 │
│ java       │      135000.0 │          342 │             5.8 │          0.79 │
│ scala      │      137500.0 │          281 │             5.6 │          0.78 │
│ databricks │      130000.0 │          365 │             5.9 │          0.77 │
│ git        │      139000.0 │          234 │             5.5 │          0.76 │
│ redshift   │      130000.0 │          321 │             5.8 │          0.75 │
│ gcp        │      135000.0 │          234 │             5.5 │          0.74 │
│ pyspark    │      139000.0 │          212 │             5.4 │          0.74 │
│ hadoop     │      133853.3 │          218 │             5.4 │          0.72 │
│ nosql      │      131750.0 │          220 │             5.4 │          0.71 │
│ docker     │      135000.0 │          167 │             5.1 │          0.69 │
│ go         │      138750.0 │          138 │             4.9 │          0.68 │
│ mongodb    │      135000.0 │          158 │             5.1 │          0.68 │
│ pandas     │      140000.0 │          111 │             4.7 │          0.66 │
│ r          │      133637.5 │          142 │             5.0 │          0.66 │
│ bigquery   │      126000.0 │          164 │             5.1 │          0.64 │
└────────────┴───────────────┴──────────────┴─────────────────┴───────────────┘
  25 rows                                                           5 columns
*/