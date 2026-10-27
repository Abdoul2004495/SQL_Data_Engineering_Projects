SELECT
    job_id,
    job_title_short,
    job_location,
    job_posted_date AS job_posted_date_utc,
    job_posted_date AT TIME ZONE 'UTC' AT TIME ZONE 'HST' AS job_date_hst_10,
    job_posted_date AT TIME ZONE 'UTC' AT TIME ZONE 'PST' AS job_date_pst_08,
    job_posted_date AT TIME ZONE 'UTC' AT TIME ZONE 'MST' AS job_date_mst_07,
    job_posted_date AT TIME ZONE 'UTC' AT TIME ZONE 'CST' AS job_date_cst_06,
    job_posted_date AT TIME ZONE 'UTC' AT TIME ZONE 'EST' AS job_date_est_05,
    job_posted_date AT TIME ZONE 'UTC' AT TIME ZONE 'GMT' AS job_date_gmt_00
FROM job_postings_fact
WHERE job_country = 'United States';