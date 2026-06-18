# Azure Retail Data Engineering Pipeline

## Project Overview

This project is an end-to-end Azure Data Engineering pipeline that migrates retail sales data from **AWS S3** to **Azure Data Lake Storage Gen2**, transforms and validates the data using **Azure Data Factory**, stores cleaned records as **Parquet**, loads processed sales data into **Azure SQL Database**, and tracks execution using **ETL audit logging**.

The project demonstrates a real-world batch data engineering workflow with ingestion, validation, transformation, error handling, SQL loading, monitoring, scheduling, and GitHub version control.



## Architecture


AWS S3
  ↓
Azure Data Factory
  ↓
ADLS Gen2 Raw Zone
  ↓
ADF Mapping Data Flow
  ├── Valid Records → Processed Zone as Parquet
  └── Invalid Records → Error Zone as Parquet
  ↓
Azure SQL Database
  ↓
ETL Audit Log
  ↓
ADF Monitor + Log Analytics




## Tools and Services Used

| Service / Tool               | Purpose                                                        |
| ---------------------------- | -------------------------------------------------------------- |
| AWS S3                       | Source storage for retail CSV files                            |
| Azure Data Factory           | Pipeline orchestration, ingestion, transformation, and loading |
| Azure Data Lake Storage Gen2 | Raw, processed, error, curated, and archive storage zones      |
| Azure SQL Database           | Final structured serving layer                                 |
| Azure Key Vault              | Secure credential and secret management                        |
| Log Analytics Workspace      | ADF monitoring and diagnostic log analysis                     |
| ADF Mapping Data Flow        | Data cleansing, validation, deduplication, and transformation  |
| GitHub                       | Version control and project documentation                      |



## Project Features

* Ingests retail CSV files from AWS S3
* Stores raw files in ADLS Gen2
* Validates source file existence and file size before processing
* Cleans and transforms sales data using ADF Mapping Data Flow
* Converts CSV data into Parquet format with Snappy compression
* Separates valid and invalid records
* Stores rejected records in an error folder
* Removes duplicate sales records
* Adds derived columns such as `TotalAmount`, `LoadDate`, and `CustomerCategory`
* Loads processed data into Azure SQL Database
* Creates SQL audit logging using `ETLAuditLog`
* Uses stored procedure-based audit insertion from ADF
* Orchestrates the full workflow using a master pipeline
* Configures a daily schedule trigger
* Enables monitoring through ADF Monitor and Log Analytics
* Documents implementation with screenshots and SQL scripts



## Data Flow

### 1. Source Data

Retail source files were stored in AWS S3:


sales_data.csv
customer_data.csv
product_data.csv


### 2. Raw Data Ingestion

Azure Data Factory copies the source files from AWS S3 into ADLS Gen2 raw storage.

Raw paths:


raw/sales/sales_data.csv
raw/customer/customer_data.csv
raw/product/product_data.csv


### 3. File Validation

Before copying, ADF uses `Get Metadata` and `If Condition` activities to validate:

* File exists
* File size is greater than zero

If validation fails, the pipeline stops using a `Fail` activity.

### 4. Data Transformation

ADF Mapping Data Flow cleans and transforms sales data by:

* Converting data types
* Trimming and standardizing country values
* Calculating `TotalAmount`
* Adding `LoadDate`
* Creating `CustomerCategory`
* Creating validation flags
* Splitting valid and invalid records
* Removing duplicate orders

### 5. Processed and Error Output

Valid records are stored as Parquet:


processed/sales/


Invalid records are stored separately:


error/sales/


### 6. SQL Load

Processed Parquet data is loaded into Azure SQL Database table:


dbo.FactSales


### 7. Audit Logging

ADF inserts execution details into:


dbo.ETLAuditLog


The audit log tracks:

* Pipeline name
* Activity name
* Run ID
* Status
* Rows loaded
* Start time
* End time
* Error message



## Azure SQL Objects

The SQL folder contains scripts used in the project:

| Script                                 | Purpose                                                |
| -------------------------------------- | ------------------------------------------------------ |
| `01_create_fact_sales_table.sql`       | Creates the final `FactSales` table                    |
| `02_create_etl_audit_log_table.sql`    | Creates the ETL audit log table                        |
| `03_create_audit_stored_procedure.sql` | Creates the stored procedure used by ADF audit logging |
| `04_validation_queries.sql`            | Contains SQL validation queries                        |



## Pipelines Created

| Pipeline                  | Purpose                                              |
| ------------------------- | ---------------------------------------------------- |
| `PL_S3_To_ADLS`           | Copies CSV files from AWS S3 to ADLS raw zone        |
| `PL_Sales_Transformation` | Runs Mapping Data Flow to clean and split sales data |
| `PL_Parquet_To_SQL`       | Loads processed Parquet data into Azure SQL          |
| `PL_Master_Retail_ETL`    | Orchestrates the full end-to-end ETL workflow        |



## Data Quality and Error Handling

The pipeline includes both file-level and row-level error handling.

### File-Level Validation

ADF validates whether source files exist and are not empty before copying them.

### Row-Level Validation

The Mapping Data Flow creates a `RejectReason` column and separates records into valid and invalid streams.

Examples of rejected records:

* Null customer records
* Invalid quantity records
* Invalid country records


Invalid records are stored in:
error/sales/


## Monitoring

Monitoring was implemented using:

* Azure Data Factory Monitor
* Log Analytics Workspace
* SQL audit log table

ADF diagnostic logs were sent to Log Analytics for pipeline, activity, and trigger run tracking.

Example KQL query:


ADFActivityRun
| where TimeGenerated > ago(24h)
| where PipelineName == "PL_S3_To_ADLS" and Status == "Succeeded"
| order by TimeGenerated desc
| project TimeGenerated, PipelineName, ActivityName, ActivityType, Status


## Validation

The final pipeline output was validated using SQL queries.

Validation checks included:

* FactSales row count
* Loaded sales records
* Duplicate order check
* Invalid record rejection
* Valid record load verification
* Audit log verification

Example:


SELECT COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;



SELECT 
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;


SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;


## Documentation

Detailed project steps are available here:

docs/project_steps.md


Additional documentation:

docs/project_overview.md
docs/data_quality_rules.md
sql/README.md


Screenshots are stored in:

screenshots/

## Key Learning Outcomes

This project demonstrates practical experience with:

* Azure Data Factory pipeline development
* Cross-cloud ingestion from AWS S3 to Azure
* Azure Data Lake Storage Gen2
* Azure Key Vault integration
* Managed identity and RBAC
* ADF Mapping Data Flow
* Data validation and error handling
* Parquet file generation
* Azure SQL Database loading
* ETL audit logging
* Log Analytics monitoring
* Schedule trigger automation
* GitHub-based project version control






