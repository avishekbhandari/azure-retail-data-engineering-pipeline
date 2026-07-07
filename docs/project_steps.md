# Azure Retail Data Engineering Pipeline — Project Steps

## 1. Project Overview

This project implements an end-to-end Azure Data Engineering pipeline for retail sales data. The pipeline migrates CSV files from AWS S3 into Azure Data Lake Storage Gen2, validates source files, cleans and transforms sales data using Azure Data Factory Mapping Data Flow, stores valid records as Parquet, routes invalid records to an error folder, loads curated data into Azure SQL Database, and records pipeline execution details in an audit table.

The project was built as a hands-on data engineering solution and published to GitHub with Azure Data Factory Git integration.

## 2. Business Problem

Retail sales data is received as CSV files from an external source system hosted in AWS S3. The goal is to build a reliable data pipeline that can:

* Ingest raw sales, customer, and product files from AWS S3
* Store raw files in Azure Data Lake Storage Gen2
* Validate file existence before processing
* Clean and transform sales data
* Separate valid and invalid records
* Store processed records in Parquet format
* Load clean sales records into Azure SQL Database
* Track ETL execution using audit logging
* Monitor pipeline execution using ADF Monitor and Log Analytics
* Automate execution using an ADF schedule trigger

## 3. High-Level Architecture

The project follows this architecture:

```text
AWS S3
  ↓
Azure Data Factory
  ↓
Azure Data Lake Storage Gen2 - Raw Zone
  ↓
ADF Mapping Data Flow
  ├── Valid records → Processed Zone as Parquet
  └── Invalid records → Error Zone as Parquet
  ↓
Azure SQL Database - FactSales
  ↓
ETLAuditLog
  ↓
ADF Monitor + Log Analytics
```

## 4. Tools and Services Used

| Service / Tool               | Purpose                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------ |
| AWS S3                       | Source storage for retail CSV files                                            |
| Azure Data Factory           | Pipeline orchestration, ingestion, transformation, and loading                 |
| Azure Data Lake Storage Gen2 | Data lake for raw, processed, curated, error, and archive zones                |
| Azure SQL Database           | Final serving layer for cleaned sales data                                     |
| Azure Key Vault              | Secure storage for credentials and secrets                                     |
| Log Analytics Workspace      | Centralized monitoring for ADF diagnostic logs                                 |
| ADF Mapping Data Flow        | Data cleansing, validation, deduplication, and transformation                  |
| GitHub                       | Version control for ADF artifacts, SQL scripts, screenshots, and documentation |

## 5. Azure Resource Setup

The following Azure resources were created for the project:

* Resource Group: `RG-Retail-DataEngineering-Dev`
* Storage Account / ADLS Gen2: `stretaildev001avishek`
* Azure Data Factory: `ADF-Retail-DEV-avi`
* Azure SQL Database: `RetailDW`
* Azure Key Vault: `KV-Retail-Dev-avi`
* Log Analytics Workspace: `LAW-Retail-Dev`

The ADLS Gen2 storage account was configured with hierarchical namespace enabled.

## 6. ADLS Container Structure

The following containers were created in ADLS Gen2:

```text
raw/
processed/
curated/
error/
archive/
$logs/
```

Purpose of each container:

| Container   | Purpose                                              |
| ----------- | ---------------------------------------------------- |
| `raw`       | Stores source files copied from AWS S3               |
| `processed` | Stores cleaned and transformed sales data as Parquet |
| `curated`   | Reserved for future business-ready datasets          |
| `error`     | Stores rejected/invalid records                      |
| `archive`   | Reserved for archived files                          |
| `$logs`     | Storage logging container                            |

## 7. Source Data Setup in AWS S3

The source CSV files were uploaded to AWS S3.

AWS S3 bucket:

```text
azure-retail
```

Source folder:

```text
source/
```

Files uploaded:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

These files were used as the source for the Azure Data Factory ingestion pipeline.

## 8. Security and Access Setup

Security was implemented using Azure Key Vault, managed identity, and RBAC.

### Key Vault Secrets

The following secrets were stored in Azure Key Vault:

```text
aws-access-key
aws-secret-key
sql-admin-password
```

Secrets were not hardcoded inside ADF linked services. Instead, ADF accessed them securely through Key Vault.

### Role Assignments

The Azure Data Factory managed identity was granted access to required resources:

| Role                          | Scope           | Purpose                                   |
| ----------------------------- | --------------- | ----------------------------------------- |
| Storage Blob Data Contributor | Storage Account | Allows ADF to read/write files in ADLS    |
| Key Vault Secrets User        | Key Vault       | Allows ADF to read secrets from Key Vault |
| Key Vault Secrets Officer     | Key Vault       | Allows user to create/manage secrets      |

This setup follows the principle of avoiding hardcoded credentials and using managed identity where possible.

## 9. Azure Data Factory Linked Services

Linked services were created in Azure Data Factory to connect ADF with external and Azure resources.

The following linked services were created:

| Linked Service       | Connected Resource | Purpose                                   |
| -------------------- | ------------------ | ----------------------------------------- |
| `LS_KeyVault_Retail` | Azure Key Vault    | Reads secrets securely from Key Vault     |
| `LS_ADLS_Retail`     | ADLS Gen2          | Reads and writes files in Azure Data Lake |
| `LS_AzureSQL_Retail` | Azure SQL Database | Loads processed data into SQL tables      |
| `LS_AWS_S3_Retail`   | AWS S3             | Reads source CSV files from AWS S3        |

### Why Linked Services Are Needed

A linked service in Azure Data Factory works like a connection definition. It tells ADF where the data source or destination is located and how to authenticate to it.

For example:

* `LS_AWS_S3_Retail` connects ADF to the AWS S3 source bucket.
* `LS_ADLS_Retail` connects ADF to Azure Data Lake Storage.
* `LS_AzureSQL_Retail` connects ADF to Azure SQL Database.
* `LS_KeyVault_Retail` allows ADF to retrieve secrets securely instead of storing passwords directly inside pipelines.

This design keeps the pipeline secure and reusable.

## 10. ADF Dataset Creation

Datasets were created on top of the linked services. A dataset represents the actual file, folder, table, or object that ADF reads from or writes to.

### Source Datasets

The following AWS S3 source datasets were created:

```text
DS_S3_Sales_CSV
DS_S3_Customer_CSV
DS_S3_Product_CSV
```

These datasets point to the source CSV files stored in AWS S3.

### Raw ADLS Datasets

The following ADLS raw datasets were created:

```text
DS_ADLS_Raw_Sales_CSV
DS_ADLS_Raw_Customer_CSV
DS_ADLS_Raw_Product_CSV
```

These datasets represent the raw landing locations in ADLS Gen2.

### Processed and Error Datasets

The following Parquet datasets were created for transformed sales data:

```text
DS_ADLS_Processed_Sales_Parquet
DS_ADLS_Error_Sales_Parquet
```

The processed dataset stores valid transformed records, while the error dataset stores rejected records.

### SQL Dataset

The following Azure SQL dataset was created:

```text
DS_AzureSQL_FactSales
```

This dataset points to the final `dbo.FactSales` table in Azure SQL Database.

## 11. S3 to ADLS Ingestion Pipeline

The ingestion pipeline was created to copy source CSV files from AWS S3 into the raw zone of ADLS Gen2.

Pipeline name:

```text
PL_S3_To_ADLS
```

The pipeline copies three files:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

from AWS S3 into ADLS raw containers/folders.

### Pipeline Design

The final pipeline uses the following pattern for each source file:

```text
Get Metadata
  ↓
If Condition
  ├── True: Copy file from AWS S3 to ADLS
  └── False: Fail activity
```

This pattern was created for:

* Sales file
* Customer file
* Product file

### Activities Used

| Activity     | Purpose                                            |
| ------------ | -------------------------------------------------- |
| Get Metadata | Checks whether the source file exists and has data |
| If Condition | Validates file existence and file size             |
| Copy Data    | Copies the file from AWS S3 to ADLS                |
| Fail         | Stops the pipeline if the file is missing or empty |

## 12. Metadata Validation Logic

Before copying each file, the pipeline checks:

1. Does the file exist?
2. Is the file size greater than zero?

Example validation expression:

```text
@and(
    equals(activity('Get_Metadata_Sales').output.exists, true),
    greater(activity('Get_Metadata_Sales').output.size, 0)
)
```

This means:

```text
If the sales file exists AND the file size is greater than 0,
then copy the file.
Otherwise, fail the pipeline.
```

The same validation pattern was applied to customer and product files.

### Why Metadata Validation Was Added

Metadata validation prevents the pipeline from processing missing or empty source files.

Without this validation, the pipeline could:

* Copy empty files
* Fail later during transformation
* Load incomplete data
* Produce misleading downstream results

By validating files at the beginning, the pipeline becomes more reliable and production-ready.

## 13. Raw Data Landing in ADLS

After successful execution of the ingestion pipeline, the source files were copied into ADLS raw storage.

Raw output paths:

```text
raw/sales/sales_data.csv
raw/customer/customer_data.csv
raw/product/product_data.csv
```

The raw zone stores the source data in its original format. This is useful because the original files remain available for debugging, reprocessing, and auditing.

## 14. S3 to ADLS Pipeline Result

The final ingestion pipeline completed successfully. All metadata validation activities, condition checks, and copy activities succeeded.

The completed pipeline proved that:

* ADF could securely connect to AWS S3.
* ADF could securely write files to ADLS Gen2.
* Source files were validated before ingestion.
* Raw sales, customer, and product files were successfully landed in ADLS.

## 15. Sales Cleansing Data Flow

After the raw sales file was copied into ADLS, a Mapping Data Flow was created to clean, validate, and transform the sales data.

Data flow name:

```text
DF_Sales_Cleansing
```

This data flow reads raw sales CSV data from ADLS and produces two outputs:

```text
processed/sales/   → valid cleaned records
error/sales/       → invalid rejected records
```

## 16. Data Flow Source

The data flow source was configured using the raw sales dataset:

```text
DS_ADLS_Raw_Sales_CSV
```

The source reads the raw file from:

```text
raw/sales/sales_data.csv
```

This source represents the unprocessed sales data copied from AWS S3.

## 17. Standardizing Sales Columns

A Derived Column transformation was used to standardize and convert raw string values into proper data types.

Transformation name:

```text
DerivedSalesStandardizedColumns
```

Examples of standardization logic:

```text
Quantity      → converted to integer
UnitPrice     → converted to decimal
OrderDate     → converted to date
Country       → trimmed and converted to uppercase
TotalAmount   → calculated using Quantity × UnitPrice
LoadDate      → added to capture processing timestamp
```

This step is important because CSV files usually store values as text. Before loading data into SQL or Parquet, the data must be converted into clean and reliable data types.

## 18. Sales Validation Flags

A second Derived Column transformation was created to identify invalid records.

Transformation name:

```text
DerivedSalesValidationFlags
```

A `RejectReason` column was created to mark records that failed business validation rules.

Validation checks included:

| Validation Rule                | Purpose                                     |
| ------------------------------ | ------------------------------------------- |
| Null or empty customer ID      | Reject records without customer information |
| Invalid or negative quantity   | Reject incorrect sales quantities           |
| Invalid country value          | Reject records with invalid country data    |
| Invalid amount or price values | Prevent bad financial records               |
| Invalid date values            | Prevent incorrect time-based reporting      |

The `RejectReason` column helps explain why a record was rejected.

Example logic concept:

```text
If CustomerID is null → RejectReason = "Missing CustomerID"
If Quantity is negative → RejectReason = "Invalid Quantity"
If Country is invalid → RejectReason = "Invalid Country"
Otherwise → RejectReason = ""
```

## 19. Splitting Valid and Invalid Records

A Conditional Split transformation was used to separate clean records from bad records.

Transformation name:

```text
SplitValidInvalidSales
```

Two streams were created:

| Stream             | Condition            | Destination              |
| ------------------ | -------------------- | ------------------------ |
| `ValidSalesRows`   | `RejectReason == ''` | Processed Parquet output |
| `InvalidSalesRows` | `RejectReason != ''` | Error Parquet output     |

This design is useful because the pipeline does not completely fail when some records are bad. Instead, valid records continue processing, and invalid records are stored separately for review.

## 20. Error Records Output

Invalid records were written to the error container in ADLS.

Error sink name:

```text
SinkErrorSalesParquet
```

Error output path:

```text
error/sales/
```

The error folder stores rejected records in Parquet format. These records can be reviewed later to understand data quality issues.

Examples of rejected records included:

```text
records with null customer ID
records with invalid or negative quantity
records with invalid business values
```

This satisfies the error handling requirement of the project.

## 21. Deduplication Logic

For valid sales records, a Window transformation was used to identify duplicate orders.

Transformation name:

```text
WindowOrderDeduplication
```

The data flow assigned a row number to records grouped by order information. Then a Filter transformation kept only the first record.

Filter transformation name:

```text
FilterFirstOrderRecord
```

This step prevents duplicate sales records from being loaded into the final SQL table.

Deduplication is important because duplicate sales records can cause:

* Incorrect revenue totals
* Incorrect sales counts
* Wrong reporting results
* Poor data warehouse quality

## 22. Customer Category Derivation

A Derived Column transformation was added to classify customers based on sales amount.

Transformation name:

```text
DerivedCustomerCategory
```

Example business logic:

```text
If TotalAmount >= 1000 → CustomerCategory = "Premium"
Otherwise → CustomerCategory = "Standard"
```

This creates a useful analytical column that can be used later for reporting and segmentation.

## 23. Final Column Selection

A Select transformation was used to keep only the final columns needed for the processed output.

Transformation name:

```text
SelectFinalProcessedSales
```

Final selected columns:

```text
OrderID
CustomerID
ProductID
Quantity
UnitPrice
OrderDate
Country
SalesChannel
TotalAmount
LoadDate
CustomerCategory
```

This step removes unnecessary technical columns and keeps the processed dataset clean.

## 24. Processed Sales Output

Valid transformed records were written to the processed container in Parquet format.

Processed sink name:

```text
SinkProcessedSalesParquet
```

Processed output path:

```text
processed/sales/
```

Output format:

```text
Parquet with Snappy compression
```

Parquet was used because it is efficient for analytics workloads. It supports columnar storage, compression, and faster query performance compared to CSV.

## 25. Data Flow Pipeline

The Mapping Data Flow was executed using an ADF pipeline.

Pipeline name:

```text
PL_Sales_Transformation
```

The pipeline contains a Data Flow activity that runs:

```text
DF_Sales_Cleansing
```

The pipeline completed successfully and produced:

```text
processed/sales/   → cleaned valid sales records
error/sales/       → rejected invalid sales records
```

## 26. Data Transformation Result

After the transformation pipeline executed successfully, the following outputs were created in ADLS:

```text
processed/sales/_SUCCESS
processed/sales/part-....snappy.parquet

error/sales/_SUCCESS
error/sales/part-....snappy.parquet
```

This confirms that the data flow successfully separated valid and invalid records and wrote both outputs to the correct ADLS locations.

## 27. Azure SQL Database Setup

Azure SQL Database was used as the final serving layer for the cleaned sales data.

SQL Server:

```text
sql-retail-dev-avi01.database.windows.net
```

Database:

```text
RetailDW
```

The processed sales data from ADLS was loaded into a SQL table called:

```text
dbo.FactSales
```

Azure SQL Database was used because it provides a structured relational layer where cleaned data can be queried using SQL for reporting, analytics, and validation.

## 28. FactSales Table

The `FactSales` table was created to store the final cleaned sales records.

SQL script location:

```text
sql/01_create_fact_sales_table.sql
```

Table name:

```text
dbo.FactSales
```

The table includes the following columns:

| Column             | Purpose                                 |
| ------------------ | --------------------------------------- |
| `FactSalesID`      | Surrogate primary key generated by SQL  |
| `OrderID`          | Original sales order ID                 |
| `CustomerID`       | Customer identifier                     |
| `ProductID`        | Product identifier                      |
| `Quantity`         | Number of products sold                 |
| `UnitPrice`        | Price per unit                          |
| `OrderDate`        | Sales order date                        |
| `Country`          | Country of sale                         |
| `SalesChannel`     | Sales channel information               |
| `TotalAmount`      | Calculated sales amount                 |
| `CustomerCategory` | Derived customer classification         |
| `LoadDate`         | Timestamp when the record was processed |

The `FactSalesID` column was created as an identity column so SQL Server can automatically generate a unique primary key for each inserted row.

## 29. Parquet to SQL Pipeline

After the sales data was cleaned and written as Parquet, another ADF pipeline was created to load the processed data into Azure SQL Database.

Pipeline name:

```text
PL_Parquet_To_SQL
```

Main activity:

```text
Copy_Processed_Sales_To_FactSales
```

Source dataset:

```text
DS_ADLS_Processed_Sales_Parquet
```

Sink dataset:

```text
DS_AzureSQL_FactSales
```

The pipeline reads Parquet files from:

```text
processed/sales/
```

and loads the records into:

```text
dbo.FactSales
```

## 30. Parquet Source Configuration

The source of the copy activity was configured to read Parquet files from the processed sales folder.

Source configuration:

```text
Container: processed
Folder path: sales
Wildcard file name: *.parquet
Recursive: enabled
```

Using wildcard file path allows ADF to read the generated Parquet part file even when the exact file name changes after each data flow execution.

## 31. SQL Sink Configuration

The sink of the copy activity was configured to insert rows into the existing SQL table.

Sink table:

```text
dbo.FactSales
```

Write behavior:

```text
Insert
```

The pipeline used column mapping to map processed Parquet columns to the SQL table columns.

The identity column `FactSalesID` was not mapped because SQL Server generates it automatically.

## 32. Column Mapping

The following source columns were mapped to the SQL table:

| Source Column      | SQL Column         |
| ------------------ | ------------------ |
| `OrderID`          | `OrderID`          |
| `CustomerID`       | `CustomerID`       |
| `ProductID`        | `ProductID`        |
| `Quantity`         | `Quantity`         |
| `UnitPrice`        | `UnitPrice`        |
| `OrderDate`        | `OrderDate`        |
| `Country`          | `Country`          |
| `SalesChannel`     | `SalesChannel`     |
| `TotalAmount`      | `TotalAmount`      |
| `CustomerCategory` | `CustomerCategory` |
| `LoadDate`         | `LoadDate`         |

The `FactSalesID` column was intentionally excluded from mapping.

## 33. SQL Load Result

After the `PL_Parquet_To_SQL` pipeline executed successfully, the cleaned sales records were inserted into `dbo.FactSales`.

The SQL table was validated using row count and sample record queries.

Example validation:

```sql
SELECT COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;
```

The result confirmed that the cleaned valid sales records were loaded into Azure SQL Database.

## 34. ETL Audit Log Table

An audit table was created to track SQL load execution details.

SQL script location:

```text
sql/02_create_etl_audit_log_table.sql
```

Audit table:

```text
dbo.ETLAuditLog
```

The audit table stores execution details such as:

| Column          | Purpose                             |
| --------------- | ----------------------------------- |
| `AuditID`       | Unique audit record ID              |
| `PipelineName`  | Name of the ADF pipeline            |
| `ActivityName`  | Name of the pipeline activity       |
| `RunID`         | Unique ADF pipeline run ID          |
| `Status`        | Execution status                    |
| `RowsLoaded`    | Number of rows loaded               |
| `LoadStartTime` | Pipeline load start time            |
| `LoadEndTime`   | Pipeline load end time              |
| `ErrorMessage`  | Error message if applicable         |
| `CreatedAt`     | SQL audit record creation timestamp |

Audit logging is useful because it allows tracking of historical ETL executions directly inside the database.

## 35. Audit Stored Procedure

A stored procedure was created to insert audit records into `dbo.ETLAuditLog`.

SQL script location:

```text
sql/03_create_audit_stored_procedure.sql
```

Stored procedure name:

```text
dbo.usp_InsertETLAuditLog
```

The stored procedure receives pipeline execution values from ADF and inserts them into the audit table.

The procedure tracks:

```text
Pipeline name
Activity name
Run ID
Status
Rows loaded
Start time
End time
Error message
```

## 36. Audit Logging Activity in ADF

A Stored Procedure activity was added to the `PL_Parquet_To_SQL` pipeline after the SQL copy activity.

Activity name:

```text
Audit_Parquet_To_SQL_Load
```

This activity calls:

```text
dbo.usp_InsertETLAuditLog
```

The activity runs after `Copy_Processed_Sales_To_FactSales` succeeds.

ADF passes pipeline values such as:

```text
@pipeline().Pipeline
@pipeline().RunId
@pipeline().TriggerTime
@utcNow()
```

It also passes the copied row count from the copy activity output.

## 37. Audit Log Validation

The audit table was validated using this SQL query:

```sql
SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;
```

The result confirmed that ADF successfully inserted audit records after the SQL load pipeline completed.

This proves that the pipeline not only loads data but also tracks execution details for monitoring and debugging.

## 38. SQL Validation Queries

Validation queries were stored in:

```text
sql/04_validation_queries.sql
```

The validation script checks:

```text
FactSales row count
Loaded sales records
Duplicate OrderID values
Rejected invalid records
Valid record load verification
ETL audit log records
```

Important validations included:

```sql
SELECT COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;
```

```sql
SELECT 
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;
```

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID = '1004';
```

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID = '1003';
```

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID = '1005';
```

These queries proved that valid records were loaded, invalid records were rejected, and duplicate records were removed.

## 39. Master Pipeline Orchestration

A master pipeline was created to orchestrate the full end-to-end ETL process.

Pipeline name:

```text
PL_Master_Retail_ETL
```

The master pipeline controls the execution order of the project pipelines.

Execution flow:

```text
PL_S3_To_ADLS
  ↓
Delete_Processed_Sales_Output
  ↓
Delete_Error_Sales_Output
  ↓
PL_Sales_Transformation
  ↓
PL_Parquet_To_SQL
```

## 40. Master Pipeline Activities

The master pipeline contains the following activities:

| Activity                        | Purpose                                                                |
| ------------------------------- | ---------------------------------------------------------------------- |
| `Run_S3_To_ADLS_Ingestion`      | Executes the pipeline that copies files from AWS S3 to ADLS raw zone   |
| `Delete_Processed_Sales_Output` | Deletes old processed sales output before generating new Parquet files |
| `Delete_Error_Sales_Output`     | Deletes old error sales output before generating new rejected records  |
| `Run_Sales_Transformation`      | Executes the sales cleansing Mapping Data Flow                         |
| `Run_Parquet_To_SQL_Load`       | Executes the pipeline that loads processed Parquet data into Azure SQL |

The delete activities were added to prevent old Parquet output files from remaining in the processed and error folders during repeated testing.

## 41. Why a Master Pipeline Was Created

The master pipeline was created to manage the full ETL workflow from one place.

Instead of manually running each pipeline separately, the master pipeline executes the full process in the correct order:

1. Ingest source files
2. Clean previous output folders
3. Transform sales data
4. Write processed and error Parquet files
5. Load processed data into Azure SQL
6. Insert audit log records

This design is closer to how real production data pipelines are orchestrated.

## 42. Master Pipeline Execution Result

The master pipeline was executed successfully.

The following child pipelines and activities completed successfully:

```text
PL_S3_To_ADLS
PL_Sales_Transformation
PL_Parquet_To_SQL
```

The successful master pipeline run confirmed that the full end-to-end ETL workflow worked from source ingestion to SQL load.

## 43. Trigger Configuration

A schedule trigger was created to automate the master pipeline.

Trigger name:

```text
TRG_Daily_Retail_ETL
```

Trigger type:

```text
Schedule Trigger
```

Related pipeline:

```text
PL_Master_Retail_ETL
```

The trigger was configured to run the master ETL pipeline on a daily schedule.

## 44. Trigger Design Decision

The assignment mentioned a file-arrival style trigger. However, the project source system is AWS S3.

Azure Data Factory storage event triggers are designed mainly for Azure Storage events, not direct AWS S3 object-created events.

Because of this, a schedule trigger was used for this implementation.

In a production design, true AWS S3 file-arrival automation could be implemented using:

```text
AWS S3 Event
  ↓
AWS Lambda or EventBridge
  ↓
ADF REST API / Webhook / Logic App
  ↓
PL_Master_Retail_ETL
```

For this project, the schedule trigger demonstrates automation while keeping the implementation simple and reliable.

## 45. Monitoring Setup

Monitoring was implemented using Azure Data Factory Monitor and Log Analytics.

A diagnostic setting was created for Azure Data Factory.

Diagnostic setting name:

```text
diag-adf-retail-law
```

Destination:

```text
LAW-Retail-Dev
```

The following ADF log categories were sent to Log Analytics:

```text
Pipeline runs log
Pipeline activity runs log
Trigger runs log
```

## 46. Log Analytics Validation

ADF activity logs were verified using Log Analytics.

Example KQL query:

```kusto
ADFActivityRun
| where TimeGenerated > ago(24h)
| where PipelineName == "PL_S3_To_ADLS" and Status == "Succeeded"
| order by TimeGenerated desc
| project TimeGenerated, PipelineName, ActivityName, ActivityType, Status
```

The query returned successful activity runs for the ingestion pipeline, including:

```text
Get_Metadata_Sales
Get_Metadata_Customer
Get_Metadata_Product
If_Sales_File_Valid
If_Customer_File_Valid
If_Product_File_Valid
Copy_Sales_S3_To_ADLS
Copy_Customer_S3_To_ADLS
Copy_Product_S3_To_ADLS
```

This confirmed that ADF logs were successfully captured in Log Analytics.

## 47. Monitoring Requirements Covered

The project covered the main monitoring requirements as follows:

| Monitoring Requirement | How It Was Covered                                        |
| ---------------------- | --------------------------------------------------------- |
| Pipeline success rate  | ADF Monitor and Log Analytics pipeline status             |
| Pipeline failures      | ADF Monitor failed runs and Log Analytics failure queries |
| Execution duration     | ADF Monitor duration and activity run logs                |
| Rows processed         | Copy activity output and SQL audit log `RowsLoaded`       |
| Rows rejected          | Invalid records written to `error/sales/`                 |
| Storage output         | ADLS processed and error folders verified                 |
| SQL load performance   | SQL load pipeline execution and audit log records         |

## 48. Error Handling

Error handling was implemented at multiple levels.

### File-Level Error Handling

The `PL_S3_To_ADLS` pipeline checks whether each source file exists and has data before copying.

Validation pattern:

```text
Get Metadata
  ↓
If Condition
  ├── True: Copy file
  └── False: Fail pipeline
```

This prevents missing or empty files from being processed.

### Row-Level Error Handling

The sales cleansing data flow creates a `RejectReason` column and separates records into valid and invalid streams.

Valid records are written to:

```text
processed/sales/
```

Invalid records are written to:

```text
error/sales/
```

This allows the pipeline to continue processing good records while preserving bad records for review.

### Audit-Level Tracking

The SQL load pipeline inserts execution information into:

```text
dbo.ETLAuditLog
```

This makes it possible to track pipeline runs, status, rows loaded, and execution timestamps.

## 49. Final Validation Results

The final project was validated using Azure SQL queries.

Validation checks included:

```text
FactSales row count
Loaded sales records
Duplicate OrderID check
Invalid quantity rejection
Null customer rejection
Valid record load verification
Audit log verification
```

The validation confirmed that:

* Clean sales records were loaded into `dbo.FactSales`
* Invalid records were rejected from the SQL table
* Duplicate order records were removed
* Audit log records were inserted successfully
* The master pipeline completed successfully

## 50. GitHub Version Control

The project was connected to GitHub using Azure Data Factory Git integration.

Repository:

```text
azure-retail-data-engineering-pipeline
```

The repository includes:

```text
adf/
architecture/
data/
docs/
screenshots/
sql/
README.md
.gitignore
```

ADF artifacts were stored under the `adf/` folder, including:

```text
dataflow/
dataset/
factory/
linkedService/
pipeline/
trigger/
publish_config.json
```

SQL scripts were stored under the `sql/` folder.

Screenshots were stored under the `screenshots/` folder.

Project documentation was stored under the `docs/` folder.

## 51. Final Project Outcome

This project demonstrates an end-to-end cloud data engineering pipeline using Azure and AWS services.

The completed solution includes:

* AWS S3 source ingestion
* Azure Data Lake raw, processed, and error zones
* Secure credential management with Azure Key Vault
* ADF linked services and datasets
* Metadata-based file validation
* Mapping Data Flow transformation
* Data quality validation and rejected record handling
* Parquet output with Snappy compression
* Azure SQL Database loading
* ETL audit logging
* Master pipeline orchestration
* Schedule trigger automation
* ADF monitoring with Log Analytics
* GitHub version control and documentation

## 52. Interview Explanation

This project can be explained in an interview as:

```text
I built an end-to-end Azure Data Engineering pipeline for retail sales data. 
The source files were stored in AWS S3, and I used Azure Data Factory to ingest them into Azure Data Lake Storage Gen2. 
Before copying the files, I added metadata validation to check file existence and file size. 
Then I used ADF Mapping Data Flow to clean the sales data, convert data types, calculate total amount, classify customers, remove duplicates, and separate invalid records into an error folder. 
Valid records were stored as Parquet files with Snappy compression and then loaded into Azure SQL Database. 
I also created an ETL audit log table and stored procedure to track pipeline execution details such as run ID, status, rows loaded, and timestamps. 
Finally, I created a master pipeline, schedule trigger, Log Analytics monitoring, SQL validation queries, screenshots, and GitHub documentation.
```

## 53. Future Enhancements

Possible future improvements include:

* Implementing incremental load using a watermark table
* Adding SQL merge/upsert logic instead of full batch insert
* Creating SCD Type 2 customer and product dimensions
* Adding email notification on pipeline failure
* Creating Azure Monitor alert rules
* Building Power BI reports on top of `FactSales`
* Moving rejected records into a formal data quality reporting table
