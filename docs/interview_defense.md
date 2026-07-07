# Interview Defense: Azure Retail Data Engineering Pipeline

## 1. Project Elevator Pitch

This project is an Azure batch data engineering pipeline that ingests retail CSV files from AWS S3 into Azure Data Lake Storage Gen2 using Azure Data Factory. It validates source files, transforms and cleans sales records using ADF Mapping Data Flow, writes valid records as Parquet, separates invalid records into an error zone, loads curated data into Azure SQL Database, and tracks pipeline execution using an ETL audit table and monitoring tools.

## 2. One-Minute Interview Explanation

I built this pipeline to simulate a real-world retail data integration workflow. The source files were stored in AWS S3, and Azure Data Factory was used to copy them into ADLS Gen2 raw storage. Before processing, the pipeline checks whether the files exist and are not empty. Then Mapping Data Flow applies cleaning, type casting, derived column logic, deduplication, and validation rules. Valid records are written as Parquet into the processed zone, invalid records are written into the error zone, and clean records are loaded into Azure SQL Database. I also added audit logging and monitoring so each pipeline run can be tracked by status, row count, timestamps, and errors.

## 3. Architecture Explanation

```text
AWS S3
  -> Azure Data Factory
  -> ADLS Gen2 raw zone
  -> ADF Mapping Data Flow
  -> ADLS Gen2 processed and error zones
  -> Azure SQL Database
  -> ETL audit log
  -> ADF Monitor and Log Analytics
```

The architecture separates ingestion, storage, transformation, serving, and monitoring responsibilities. That separation makes the pipeline easier to debug, scale, and explain.

## 4. Resume Bullet Defense

### Bullet 1: Built Azure Data Factory pipelines for ingestion

Defense:

- Used ADF as the orchestration layer.
- Created source and destination linked services.
- Used Copy activity to move files from AWS S3 to ADLS Gen2.
- Used Get Metadata and If Condition activities to validate file presence and size.

### Bullet 2: Implemented ADLS Gen2 storage zones

Defense:

- Raw zone stores original files.
- Processed zone stores cleaned valid records.
- Error zone stores rejected records.
- Curated zone can support analytics-ready outputs.
- Archive zone can preserve historical processed files.

### Bullet 3: Applied data quality checks

Defense:

- File-level validation checks file existence and file size.
- Row-level validation checks required fields, valid quantity, valid price, valid dates, and duplicate orders.
- Invalid records are separated with a rejection reason instead of being silently dropped.

### Bullet 4: Loaded curated records into Azure SQL Database

Defense:

- Clean records are loaded into dbo.FactSales.
- SQL validation checks confirm row counts, duplicates, nulls, and audit log entries.
- Azure SQL acts as the serving layer for analytics queries.

### Bullet 5: Added audit logging and monitoring

Defense:

- dbo.ETLAuditLog captures pipeline name, activity name, run ID, status, row count, start time, end time, and error message.
- ADF Monitor tracks pipeline, activity, and trigger runs.
- Log Analytics supports operational queries for recent failures or successful runs.

## 5. Common Interview Questions and Strong Answers

### Q1. Why did you use Azure Data Factory?

Azure Data Factory is a managed orchestration and data integration service. I used it because the project needed scheduled ingestion, source-to-destination copy, validation activities, Mapping Data Flow transformations, pipeline monitoring, and integration with Azure services.

### Q2. Why did you use ADLS Gen2?

ADLS Gen2 is suitable for cloud data lake storage because it supports hierarchical namespace, scalable file storage, and analytics workloads. In this project, it stores raw, processed, error, curated, and archive zones.

### Q3. Why did you separate raw, processed, and error zones?

The zones separate data lifecycle stages. Raw keeps the original source files, processed stores valid transformed outputs, and error stores rejected records for troubleshooting. This prevents bad records from contaminating the final serving table.

### Q4. Why Parquet instead of CSV?

Parquet is columnar, compressed, and more efficient for analytics workloads than CSV. It reduces storage size and improves query performance when downstream systems read selected columns.

### Q5. What data quality checks did you implement?

I implemented file-level checks for file existence and file size. At the row level, I validated required IDs, quantity, unit price, order date, country, and duplicate OrderID records. Invalid records were routed to the error zone with a rejection reason.

### Q6. How did you handle duplicate records?

The pipeline treats OrderID as the transaction business key. Duplicate OrderID records are removed or rejected so the final FactSales table does not double-count the same transaction.

### Q7. What is the purpose of ETLAuditLog?

ETLAuditLog provides operational visibility. It captures which pipeline or activity ran, the run ID, status, row counts, start and end timestamps, and error details. This helps with troubleshooting and production support.

### Q8. What happens if the source file is missing?

The Get Metadata activity checks file availability. If the file is missing or empty, the If Condition routes execution to a Fail activity so downstream transformation and loading do not run on invalid input.

### Q9. How would you improve this pipeline for production?

I would add parameterized datasets, environment-specific deployment, CI/CD, stronger alerting, retry policies, incremental load handling, schema drift handling, unit tests for SQL logic, and cost monitoring.

### Q10. What is the biggest engineering value of this project?

The biggest value is that it demonstrates an end-to-end data pipeline with ingestion, validation, transformation, loading, audit logging, and monitoring. It is not only moving files; it is building a controlled and observable data workflow.

## 6. Follow-Up Questions You Must Be Ready For

- How does ADF Mapping Data Flow differ from Copy activity?
- What is a linked service in ADF?
- What is a dataset in ADF?
- How do triggers work in ADF?
- What is the difference between raw, processed, and curated zones?
- How do you handle schema changes in source files?
- How do you rerun a failed pipeline without duplicating records?
- How would you design incremental loading?
- How would you secure access between ADF, ADLS, and Azure SQL?
- How would you monitor failed activities?
- How would you calculate rejected record percentage?
- How would this design change if the data volume increased significantly?

## 7. Weak Answers to Avoid

Do not say:

```text
I just copied data from S3 to Azure.
I used ADF because it was required.
I do not know why Parquet was used.
I did not handle bad records.
I only followed the assignment instructions.
```

Say:

```text
I designed the pipeline around ingestion, validation, transformation, serving, and observability. ADF handled orchestration, ADLS Gen2 stored raw and transformed outputs, Mapping Data Flow applied business rules and validation, Azure SQL served curated records, and audit logging made the pipeline traceable.
```

## 8. Final Interview Story

The project gave me hands-on practice with a realistic Azure Data Engineering workflow. I worked with cross-cloud ingestion from AWS S3 to Azure, organized the data lake into zones, used ADF activities for validation and orchestration, applied transformation logic with Mapping Data Flow, separated invalid records, loaded final records into Azure SQL Database, and implemented audit logging and monitoring to make the pipeline easier to troubleshoot and operate.
