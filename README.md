# Exploratory Data Analysis with SQL: Data Engineer Job Market Analysis

![SQL](https://img.shields.io/badge/SQL-Analytical-blue)
![DuckDB](https://img.shields.io/badge/DuckDB-Database-yellow)
![GitHub](https://img.shields.io/badge/Portfolio-Project-success)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen)

![Project Overview](/Images/1_1_Project1_EDA.png)

This project explores the **Data Engineer job market** using real-world job posting data collected **from 2023 to the present**. Through analytical SQL queries, I investigated current hiring trends, salary patterns, and the technologies that are most valuable for aspiring Data Engineers.

As the first project in my Data Engineering learning journey, this repository demonstrates my ability to write clean analytical SQL, work with relational databases, and transform raw data into meaningful business insights.

---

# Executive Summary

This project answers three essential questions about today's Data Engineering job market:

- Which technical skills are currently the most in demand?
- Which skills command the highest salaries?
- Which skills provide the best balance between demand and compensation?

To answer these questions, I built three SQL analyses using a relational data warehouse based on a star schema. The project showcases practical SQL techniques including joins, aggregations, filtering, grouping, and analytical calculations.

### Project Highlights

- Built **3 analytical SQL queries**
- Queried a **star-schema data warehouse**
- Joined multiple fact and dimension tables
- Applied business-oriented analytical techniques
- Produced actionable insights from real-world data

If you only have a minute, start here:

1. [`01_top_demanded_skills.sql`](01_top_demanded_skills.sql)
2. [`02_top_paying_skills.sql`](02_top_paying_skills.sql)
3. [`03_optimal_skills.sql`](03_optimal_skills.sql)

---

# Problem & Context

The demand for Data Engineers continues to grow as organizations increasingly rely on data-driven decision making.

Using a dataset of **Data Engineer job postings from 2023 to the present**, this project explores current market trends by answering three practical questions:

- Which skills appear most frequently in job postings?
- Which skills receive the highest salaries?
- Which combination of skills offers the greatest career value?

The analysis is performed on a relational data warehouse designed using a **star schema**, consisting of:

![Data Warehouse](/Images/1_2_Data_Warehouse.png)

### Database Structure

**Fact Table**

- `job_postings_fact`
  - Job titles
  - Salary information
  - Posting dates
  - Locations
  - Remote status

**Dimension Tables**

- `company_dim`
- `skills_dim`

**Bridge Table**

- `skills_job_dim`

This database structure enables efficient analytical queries across job postings, companies, and technical skills.

---

# Tech Stack

| Category | Technology |
|-----------|------------|
| Language | SQL |
| Database | DuckDB |
| Data Model | Star Schema |
| IDE | Visual Studio Code |
| Version Control | Git & GitHub |

---

# Analysis Overview

## 1. [Top Demanded Skills](01_top_demanded_skills.sql)

Identifies the 10 most frequently requested technical skills for remote Data Engineer positions.

---

## 2. [Top Paying Skills](02_top_paying_skills.sql)

Calculates the highest-paying technical skills using salary and demand metrics.

---

## 3. [Optimal Skills](03_optimal_skills.sql)

Combines demand and salary into a single score to identify technologies that offer the strongest career opportunities.

---

# Key Insights

After analyzing thousands of job postings, several trends emerge:

- SQL and Python remain the dominant programming languages.
- Cloud technologies such as AWS and Azure continue to be highly valued.
- Infrastructure tools like Docker, Kubernetes, and Terraform are associated with premium salaries.
- Apache Spark remains one of the most valuable Big Data technologies.

---

# SQL Skills Demonstrated

### Query Design

- Multi-table INNER JOINs
- Aggregations
- Filtering
- Sorting
- GROUP BY
- HAVING
- CASE statements
- Mathematical functions
- NULL handling

### Analytical Techniques

- Demand analysis
- Salary analysis
- Skill ranking
- Business-oriented data exploration
- Analytical reporting

---

# What I Learned

This project strengthened my ability to:

- Write clean and efficient SQL
- Analyze real-world business data
- Query normalized relational databases
- Build analytical workflows
- Present findings through technical documentation
- Organize projects using GitHub best practices

---

# Future Improvements

As I continue progressing through my Data Engineering roadmap, I plan to extend this project by:

- Performing the analysis with Python
- Loading the data into PostgreSQL
- Building ETL pipelines
- Creating interactive dashboards
- Exploring Apache Spark for large-scale analytics

---

# Conclusion

This project represents the first milestone in my Data Engineering portfolio.

Using SQL and real-world job market data, I explored hiring trends, salary patterns, and the technologies shaping today's Data Engineering landscape. Beyond the technical analysis, this project reflects my commitment to building practical, portfolio-ready projects while developing the skills required for a professional Data Engineering career.