# Azure Retail Data Engineering Pipeline

## Project Overview

This project is an end-to-end Azure Data Engineering pipeline that ingests retail CSV files from **AWS S3** into **Azure Data Lake Storage Gen2** using **Azure Data Factory**.

The pipeline validates source files, stores raw data in ADLS Gen2, transforms sales records using **ADF Mapping Data Flow**, writes valid records as **Parquet**, routes invalid records to an error folder, loads processed sales data into **Azure SQL Database**, and records execution details in an **ETL audit table**.

---

## Architecture

```text
AWS S3
  ↓
Azure Data Factory
  ↓
ADLS Gen2 Raw Zone
  ↓
ADF Mapping Data Flow
  ├── Valid Sales Records   → processed/sales/
  └── Invalid Sales Records → error/sales/
  ↓
Azure SQL Database: dbo.FactSales
  ↓
Audit Table: dbo.ETLAuditLog
  ↓
ADF Monitor + Log Analytics
```

Detailed architecture documentation:

* [`architecture/architecture_diagram.md`](architecture/architecture_diagram.md)

---

## Tech Stack

| Category        | Tools / Services                                      |
| --------------- | ----------------------------------------------------- |
| Source Storage  | AWS S3                                                |
| Orchestration   | Azure Data Factory                                    |
| Data Lake       | Azure Data Lake Storage Gen2                          |
| Transformation  | ADF Mapping Data Flow                                 |
| Serving Layer   | Azure SQL Database                                    |
| Security        | Azure Key Vault, Managed Identity, RBAC               |
| Monitoring      | ADF Monitor, Log Analytics Workspace, SQL audit table |
| Version Control | GitHub                                                |

---

## Azure Resources Used

| Resource                    | Name                                        |
| --------------------------- | ------------------------------------------- |
| Resource Group              | `RG-Retail-DataEngineering-Dev`             |
| Storage Account / ADLS Gen2 | `stretaildev001avishek`                     |
| Azure Data Factory          | `ADF-Retail-DEV-avi`                        |
| Azure SQL Database          | `RetailDW`                                  |
| SQL Server                  | `sql-retail-dev-avi01.database.windows.net` |
| Azure Key Vault             | `KV-Retail-Dev-avi`                         |
| Log Analytics Workspace     | `LAW-Retail-Dev`                            |

---

## Data Sources

Source files were stored in AWS S3:

```text
Bucket: azure-retail
Folder: source/
```

Files:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

All three files were copied into the ADLS raw zone. The main transformation and SQL loading implementation focuses on the sales dataset. Customer and product files were ingested for future extension.

---

## Data Lake Structure

ADLS Gen2 was organized into separate containers:

```text
raw/
processed/
curated/
error/
archive/
$logs/
```

| Container   | Purpose                                           |
| ----------- | ------------------------------------------------- |
| `raw`       | Stores original CSV files copied from AWS S3      |
| `processed` | Stores valid transformed sales records as Parquet |
| `error`     | Stores invalid/rejected sales records             |
| `curated`   | Reserved for future business-ready outputs        |
| `archive`   | Reserved for future archive files                 |
| `$logs`     | Storage logging container                         |

The SQL load uses processed sales data from:

```text
processed/sales/
```

---

## Pipeline Flow

### 1. Ingestion: AWS S3 to ADLS Gen2

Pipeline:

```text
PL_S3_To_ADLS
```

This pipeline copies retail CSV files from AWS S3 into ADLS raw storage.

It uses:

* `Get Metadata`
* `If Condition`
* `Copy Data`
* `Fail`

Before copying files, the pipeline validates:

* File exists
* File size is greater than zero

Raw output paths:

```text
raw/sales/sales_data.csv
raw/customer/customer_data.csv
raw/product/product_data.csv
```

---

### 2. Sales Transformation

Data flow:

```text
DF_Sales_Cleansing
```

Transformation logic includes:

* Convert `Quantity` to integer
* Convert `UnitPrice` to decimal
* Convert `OrderDate` to date
* Standardize `Country`
* Calculate `TotalAmount`
* Add `LoadDate`
* Create `RejectReason`
* Split valid and invalid records
* Deduplicate valid sales records by `OrderID`
* Add `CustomerCategory`
* Select final processed sales columns

Valid sales records are written to:

```text
processed/sales/
```

Invalid sales records are written to:

```text
error/sales/
```

---

### 3. Parquet to Azure SQL Load

Pipeline:

```text
PL_Parquet_To_SQL
```

This pipeline loads processed Parquet files into Azure SQL Database.

Source:

```text
processed/sales/*.parquet
```

Sink:

```text
dbo.FactSales
```

The SQL load uses a pre-copy script:

```sql
TRUNCATE TABLE dbo.FactSales;
```

This supports full-refresh loading and prevents duplicate rows during repeated test runs.

---

### 4. Master Pipeline

Pipeline:

```text
PL_Master_Retail_ETL
```

Execution flow:

```text
Run_S3_To_ADLS_Ingestion
  ↓
Delete_Processed_Sales_Output
  ↓
Delete_Error_Sales_Output
  ↓
Run_Sales_Transformation
  ↓
Run_Parquet_To_SQL_Load
```

The master pipeline orchestrates ingestion, cleanup, transformation, SQL loading, and audit logging from one place.

---

## Data Quality and Error Handling

The pipeline includes file-level and row-level validation.

### File-Level Validation

The ingestion pipeline validates source files before copying them from AWS S3.

Checks:

* File exists
* File size is greater than zero

If validation fails, the pipeline stops through a `Fail` activity.

### Row-Level Validation

The sales data flow creates a `RejectReason` column.

Implemented reject reasons:

| Validation Rule                    | Reject Reason        |
| ---------------------------------- | -------------------- |
| Missing or blank customer ID       | `NULL_CUSTOMER`      |
| Invalid or non-positive quantity   | `INVALID_QUANTITY`   |
| Invalid or non-positive unit price | `INVALID_UNIT_PRICE` |
| Missing country                    | `MISSING_COUNTRY`    |
| Country outside allowed list       | `INVALID_COUNTRY`    |

Allowed country values:

```text
USA
CANADA
UK
INDIA
```

Invalid records are preserved in:

```text
error/sales/
```

Duplicate valid sales records are handled separately using Window and Filter logic before SQL loading.

---

## Azure SQL Database

The final processed sales records are loaded into:

```text
dbo.FactSales
```

Main columns:

```text
FactSalesID
OrderID
CustomerID
ProductID
Quantity
UnitPrice
OrderDate
Country
SalesChannel
TotalAmount
CustomerCategory
LoadDate
```

SQL scripts are stored in:

```text
sql/
```

---

## ETL Audit Logging

Audit logging was implemented using:

```text
dbo.ETLAuditLog
dbo.usp_InsertETLAuditLog
```

The audit log captures:

* Pipeline name
* Activity name
* Run ID
* Status
* Rows loaded
* Load start time
* Load end time
* Error message
* Created timestamp

This supports validation, monitoring, and troubleshooting of pipeline execution.

---

## Monitoring

Monitoring was implemented using:

* Azure Data Factory Monitor
* Log Analytics Workspace
* SQL audit table

ADF diagnostic logs were sent to Log Analytics for:

* Pipeline runs
* Activity runs
* Trigger runs

Example KQL query:

```kusto
ADFActivityRun
| where TimeGenerated > ago(24h)
| where PipelineName == "PL_S3_To_ADLS" and Status == "Succeeded"
| order by TimeGenerated desc
| project TimeGenerated, PipelineName, ActivityName, ActivityType, Status
```

---

## Trigger Configuration

Schedule trigger:

```text
TRG_Daily_Retail_ETL
```

Related pipeline:

```text
PL_Master_Retail_ETL
```

The trigger was configured for daily automation. During learning and testing, it can remain stopped to avoid unnecessary recurring cost and can be started when scheduled execution is required.

---

## Validation

The project was validated using:

* ADF pipeline runs
* ADLS output files
* SQL validation queries
* SQL audit records
* Log Analytics query results
* Screenshots

Validation checks included:

* Source files copied from AWS S3 to ADLS raw storage
* Metadata validation completed for source files
* Processed Parquet output created in `processed/sales/`
* Error Parquet output created in `error/sales/`
* `dbo.FactSales` loaded successfully
* Invalid records excluded from `dbo.FactSales`
* Duplicate orders deduplicated before SQL loading
* Audit records inserted into `dbo.ETLAuditLog`
* Master pipeline completed successfully
* Schedule trigger configured

---

## Repository Documentation

| File / Folder                                                                  | Purpose                                                 |
| ------------------------------------------------------------------------------ | ------------------------------------------------------- |
| [`docs/project_overview.md`](docs/project_overview.md)                         | High-level project overview                             |
| [`docs/project_steps.md`](docs/project_steps.md)                               | Step-by-step implementation summary                     |
| [`docs/data_quality_rules.md`](docs/data_quality_rules.md)                     | Data validation and error-handling rules                |
| [`architecture/architecture_diagram.md`](architecture/architecture_diagram.md) | Architecture diagram and flow                           |
| [`sql/`](sql/)                                                                 | SQL scripts for tables, audit procedure, and validation |
| [`screenshots/`](screenshots/)                                                 | Evidence screenshots from Azure, ADF, SQL, and GitHub   |

---

## Key Outcomes

This project demonstrates practical Data Engineering skills in:

* Cross-cloud ingestion from AWS S3 to Azure
* Azure Data Factory pipeline development
* ADLS Gen2 data lake organization
* Azure Key Vault-secured credential management
* Managed identity and RBAC usage
* Metadata-based file validation
* ADF Mapping Data Flow transformation
* Row-level data quality handling
* Error record separation
* Parquet output generation
* Azure SQL Database loading
* Full-refresh SQL load control
* SQL-based ETL audit logging
* ADF Monitor and Log Analytics monitoring
* Master pipeline orchestration
* Schedule trigger configuration
* GitHub-based project documentation
