ELECT
  jpf.job_title_short,
  jpf.job_work_from_home,
  AVG(jpf.salary_year_avg)::INT AS annual_salary_avg,
  AVG(jpf.job_work_from_home::INT * ((jpf.salary_year_avg / 2080) * 260))::INT AS annual_commute_cost_savings,
  (AVG(jpf.salary_year_avg) + AVG(jpf.job_work_from_home::INT * ((jpf.salary_year_avg / 2080) * 260)))::INT AS adjusted_annual_salary_avg
FROM
  job_postings_fact AS jpf
WHERE
  jpf.job_country = 'United States'
  AND jpf.job_title_short LIKE '%Data%'
GROUP BY
  jpf.job_title_short,
  jpf.job_work_from_home
ORDER BY
  jpf.job_title_short DESC,
  jpf.job_work_from_home ASC;