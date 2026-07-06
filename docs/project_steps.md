# Project Steps: Azure Retail Data Engineering Pipeline

## 1. Project Objective

Build an end-to-end Azure Data Engineering pipeline that ingests retail CSV files from AWS S3, lands raw data into Azure Data Lake Storage Gen2, validates and transforms sales records using Azure Data Factory, writes valid records as Parquet, separates invalid records into an error zone, loads clean data into Azure SQL Database, and records pipeline execution in an ETL audit log.

## 2. Tools and Services Used

| Category | Tools / Services |
|---|---|
| Source Storage | AWS S3 |
| Orchestration | Azure Data Factory |
| Data Lake | Azure Data Lake Storage Gen2 |
| Transformation | ADF Mapping Data Flow |
| Serving Layer | Azure SQL Database |
| Monitoring | ADF Monitor, Log Analytics Workspace, ETL audit table |
| Security / Access | Azure Key Vault, Managed Identity, RBAC |
| Version Control | GitHub |

## 3. Architecture Flow

```text
AWS S3
  -> Azure Data Factory copy pipeline
  -> ADLS Gen2 raw zone
  -> Mapping Data Flow validation and transformation
  -> ADLS Gen2 processed zone for valid Parquet records
  -> ADLS Gen2 error zone for rejected records
  -> Azure SQL Database FactSales table
  -> ETL audit log table
  -> ADF Monitor and Log Analytics
```

## 4. Step-by-Step Implementation

### Step 1: Prepare Source Files in AWS S3

Source files used by the project:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

The files represent a typical retail analytics use case with sales transactions, customer attributes, and product attributes.

### Step 2: Create Azure Resource Group

A dedicated Azure resource group was used to organize project resources such as Data Factory, Storage Account, SQL Database, Key Vault, and Log Analytics Workspace.

### Step 3: Create ADLS Gen2 Storage Zones

The data lake was organized into zones to separate raw, processed, error, curated, and archive data.

```text
raw/
processed/
error/
curated/
archive/
```

This structure improves maintainability and makes the pipeline easier to explain in interviews.

### Step 4: Configure Azure Data Factory Linked Services

ADF linked services were configured for:

- AWS S3 source connection
- ADLS Gen2 destination connection
- Azure SQL Database connection
- Azure Key Vault reference where applicable

### Step 5: Build Raw Ingestion Pipeline

Pipeline name:

```text
PL_S3_To_ADLS
```

Purpose:

- Validate source file metadata
- Copy CSV files from AWS S3 into ADLS Gen2 raw zone
- Stop pipeline execution if the expected file is missing or empty

Key ADF activities:

- Get Metadata
- If Condition
- Copy Data
- Fail

### Step 6: Build Sales Transformation Pipeline

Pipeline name:

```text
PL_Sales_Transformation
```

Purpose:

- Read raw sales data
- Clean and standardize fields
- Cast data types
- Calculate derived columns
- Remove duplicate records
- Separate valid and invalid records
- Write valid records as Parquet
- Write rejected records to the error zone

Important transformations:

- Trim string columns
- Standardize country values
- Calculate TotalAmount
- Add LoadDate
- Create CustomerCategory
- Create RejectReason
- Remove duplicate OrderID records

### Step 7: Build SQL Load Pipeline

Pipeline name:

```text
PL_Parquet_To_SQL
```

Purpose:

- Load processed Parquet output into Azure SQL Database
- Populate final structured table: dbo.FactSales
- Support validation and reporting queries

### Step 8: Build Master Orchestration Pipeline

Pipeline name:

```text
PL_Master_Retail_ETL
```

Purpose:

- Execute ingestion, transformation, SQL load, and audit logging in the correct order
- Centralize the full workflow into one master pipeline
- Make operational monitoring easier

### Step 9: Create Azure SQL Tables

Core SQL objects:

```text
dbo.FactSales
dbo.ETLAuditLog
```

`FactSales` stores clean sales records. `ETLAuditLog` stores operational metadata such as pipeline name, activity name, run ID, status, row count, start time, end time, and error message.

### Step 10: Add Audit Logging

ADF calls a stored procedure after major pipeline steps to record execution results in `dbo.ETLAuditLog`.

Audit logging helps answer production-style questions:

- Did the pipeline run successfully?
- Which activity failed?
- How many rows were loaded?
- When did the pipeline start and end?
- What error message was captured?

### Step 11: Configure Monitoring

Monitoring was implemented through:

- ADF Monitor
- Pipeline run history
- Activity run history
- Trigger run history
- Log Analytics diagnostic logs
- SQL audit table

Example KQL pattern:

```kql
ADFActivityRun
| where TimeGenerated > ago(24h)
| where Status == "Succeeded"
| order by TimeGenerated desc
| project TimeGenerated, PipelineName, ActivityName, ActivityType, Status
```

### Step 12: Validate Final Output

Validation checks included:

- FactSales row count
- Duplicate OrderID check
- Valid record load verification
- Invalid record rejection check
- Audit log verification

Example SQL checks:

```sql
SELECT COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;

SELECT OrderID, COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;

SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;
```

## 5. Screenshots Needed

For a recruiter-ready project, the following screenshots should be included in the `screenshots/` folder:

- Azure resource group
- ADLS Gen2 containers or folders
- ADF linked services
- ADF raw ingestion pipeline
- Get Metadata and If Condition validation
- Mapping Data Flow transformation
- Valid and invalid output folders
- Azure SQL FactSales table
- ETLAuditLog table output
- ADF Monitor successful run
- Log Analytics query result

## 6. GitHub Commit Guidance

Use professional commit messages such as:

```text
Document Azure retail pipeline implementation steps
Add data quality rules for retail ETL pipeline
Add SQL validation queries for FactSales output
Update README with architecture and monitoring details
Add screenshots for ADF pipeline execution evidence
```

Avoid weak commit messages such as:

```text
update
done
final
changes
project files
```

## 7. Final Documentation Checklist

Before presenting this repo to recruiters, confirm that it includes:

- README.md with clear architecture and business problem
- docs/project_overview.md
- docs/project_steps.md
- docs/data_quality_rules.md
- docs/interview_defense.md
- sql folder with table creation and validation scripts
- screenshots folder with real implementation evidence
- clean commit history
- no exposed credentials or environment-specific secrets
