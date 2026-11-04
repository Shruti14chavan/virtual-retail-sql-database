# Virtual Retail Management System — SQL Developer Internship Project

## Project overview
A learning project that models a virtual retail database and builds data modelling, ETL planning, SQL optimization, and dynamic reporting deliverables. SQL examples target MySQL 8.x.

## Technologies
- MySQL 8.x and MySQL Workbench
- SQL (DDL, joins, aggregation, CTEs, window functions, indexes)
- Microsoft Word for technical reports
- GitHub for version control and project documentation

## Repository structure
```text
virtual-retail-sql-database/
├── README.md
├── docs/
│   ├── ERD.png
│   ├── Week_1_Virtual_Retail_Data_Model_Architecture.docx
│   ├── Week_2_ETL_Planning_Report.docx
│   ├── Week_3_SQL_Query_Optimization_Report.docx
│   ├── Week_3_Benchmark_Evidence_Addendum.docx
│   ├── Week_4_Dynamic_Reporting_and_Data_Visualization_Report.docx
│   └── Week4_Dashboard_Concept.png
└── sql/
    ├── 01_create_tables.sql
    ├── 02_constraints_indexes.sql
    ├── 03_sample_queries.sql
    ├── 04_etl_staging_and_transform_examples.sql
    ├── 05_week3_query_optimization_and_benchmark.sql
    ├── 05_week3_benchmark_evidence.sql
    ├── 06_demo_sample_data.sql
    ├── 07_week2_etl_demo_rows.sql
    ├── 08_week4_dynamic_reporting_queries.sql
    └── 09_week4_monthly_trend_demo_seed.sql
```

## Weekly work
- **Week 1 — Data modelling:** relational schema, keys, relationships, normalization, indexing design and ERD.
- **Week 2 — ETL planning:** sources, extraction, staging, transformation, reject handling, loading and reconciliation.
- **Week 3 — Query optimization:** baseline and optimized SQL patterns, indexes, EXPLAIN ANALYZE and benchmark evidence capture.
- **Week 4 — Dynamic reporting:** sales, products, inventory, customer behaviour and payment reporting with visualization concepts.

## Setup and execution
1. Install MySQL Server 8.x and MySQL Workbench.
2. Run `01_create_tables.sql` to create the database and core tables.
3. Run `02_constraints_indexes.sql` once to create unique constraints and indexes.
4. On a clean database only, run `06_demo_sample_data.sql` once to insert synthetic sample records. Do not re-run without clearing the demo data.
5. Run `09_week4_monthly_trend_demo_seed.sql` once after the Week 1 seed data if you want a July–December 2026 trend demo.
6. Run reporting and ETL scripts section by section, following the comments in each file.
7. Use `EXPLAIN ANALYZE` and capture timings on your own machine for benchmark claims.

## Week 4 reporting period
The Week 4 SQL file defaults to July–December 2026: `@report_start = '2026-07-01'` and `@report_end = '2027-01-01'` (exclusive). Run the optional multi-month seed script once after the Week 1 demo seed. Change these values to report on another period.

## Week 3 feedback improvement
The benchmark addendum provides specific before/after SQL cases and blank evidence tables. Fill them with actual repeated timings and EXPLAIN ANALYZE output from your own MySQL environment before claiming measured performance improvements.

## Accuracy notes
- The Week 4 dashboard and report mock outputs are illustrative examples, not actual database query results. Replace them with real results after executing the SQL.
- The Week 1 Inventory table contains current stock only. Historical unit turnover requires daily `InventorySnapshots`; cost-based inventory turnover also requires COGS and average inventory value at cost.
- Week 3 benchmark evidence must contain observed timings and execution plans from the actual MySQL environment. Do not present example values as measured results.
- Use synthetic data only. Never commit database passwords, payment-card data, or unnecessary personal information.
