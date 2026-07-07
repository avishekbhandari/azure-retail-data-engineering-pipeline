# Project Overview: Azure Retail Data Engineering Pipeline

## 1. Project Definition

This project is an end-to-end Azure Data Engineering pipeline that ingests retail CSV files from AWS S3 into Azure Data Lake Storage Gen2 using Azure Data Factory.

The pipeline validates source files, lands raw files in ADLS Gen2, transforms sales data using ADF Mapping Data Flow, writes valid records as Parquet to the processed zone, routes invalid records to an error zone, loads processed sales data into Azure SQL Database, and records SQL load execution details in an ETL audit table.

```text
AWS S3
  ↓
Azure Data Factory
  ↓
ADLS Gen2 Raw Zone
  ↓
ADF Mapping Data Flow
  ├── Valid Sales Records → processed/sales/
  └── Invalid Sales Records → error/sales/
  ↓
Azure SQL Database: dbo.FactSales
  ↓
Audit Table: dbo.ETLAuditLog
  ↓
ADF Monitor + Log Analytics
```

## 2. Business Problem

Retail data often arrives from external systems as flat files. In this project, the source files were stored in AWS S3 and needed to be moved into Azure for processing, validation, transformation, and SQL-based analytics.

The goal was to build a reliable batch data pipeline that can:

* Ingest cross-cloud CSV files from AWS S3
* Store raw source files in Azure Data Lake Storage Gen2
* Validate source file existence and file size before processing
* Clean and transform sales records
* Separate valid and invalid records
* Store valid records as Parquet
* Store rejected records in an error folder
* Load processed sales data into Azure SQL Database
* Track pipeline execution using SQL audit logging
* Monitor pipeline runs using ADF Monitor and Log Analytics
* Maintain project artifacts in GitHub

## 3. Tools and Services Used

| Service / Tool               | Purpose                                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| AWS S3                       | Source location for retail CSV files                                                      |
| Azure Data Factory           | Pipeline orchestration, ingestion, transformation, SQL loading, and trigger configuration |
| Azure Data Lake Storage Gen2 | Data lake storage for raw, processed, error, curated, archive, and logging containers     |
| ADF Mapping Data Flow        | Sales data cleansing, validation, deduplication, and transformation                       |
| Azure SQL Database           | Final SQL serving layer for processed sales records                                       |
| Azure Key Vault              | Secure storage for AWS and SQL secrets                                                    |
| Managed Identity + RBAC      | Secure access between ADF, ADLS Gen2, and Key Vault                                       |
| Log Analytics Workspace      | Centralized monitoring for ADF diagnostic logs                                            |
| GitHub                       | Version control for ADF artifacts, SQL scripts, screenshots, and documentation            |

## 4. Azure Resources Created

The project used the following Azure resources:

| Resource                    | Name                                        |
| --------------------------- | ------------------------------------------- |
| Resource Group              | `RG-Retail-DataEngineering-Dev`             |
| Storage Account / ADLS Gen2 | `stretaildev001avishek`                     |
| Azure Data Factory          | `ADF-Retail-DEV-avi`                        |
| Azure SQL Database          | `RetailDW`                                  |
| SQL Server                  | `sql-retail-dev-avi01.database.windows.net` |
| Azure Key Vault             | `KV-Retail-Dev-avi`                         |
| Log Analytics Workspace     | `LAW-Retail-Dev`                            |

## 5. Data Lake Structure

ADLS Gen2 was organized into separate containers for different data lifecycle stages:

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
| `archive`   | Reserved for historical/archive files             |
| `$logs`     | Storage logging container                         |

Important note: the `curated` container was created for future extension, but the SQL load in this implementation uses processed sales data from:

```text
processed/sales/
```

## 6. Source Data

The source files were stored in AWS S3.

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

Customer and product files were ingested into the ADLS raw zone for future extension. The main transformation and SQL loading implementation focused on the sales dataset.

## 7. Main Pipelines Built

| Pipeline                  | Purpose                                                                       |
| ------------------------- | ----------------------------------------------------------------------------- |
| `PL_S3_To_ADLS`           | Copies sales, customer, and product CSV files from AWS S3 to ADLS raw storage |
| `PL_Sales_Transformation` | Runs the sales cleansing Mapping Data Flow                                    |
| `PL_Parquet_To_SQL`       | Loads processed sales Parquet data into Azure SQL Database                    |
| `PL_Master_Retail_ETL`    | Orchestrates the full end-to-end workflow                                     |

## 8. Data Flow Transformation

The main Mapping Data Flow was:

```text
DF_Sales_Cleansing
```

It performed the following logic:

* Read raw sales CSV data from ADLS
* Convert `Quantity` to integer
* Convert `UnitPrice` to decimal
* Convert `OrderDate` to date
* Trim and standardize `Country` values to uppercase
* Calculate `TotalAmount`
* Add `LoadDate`
* Create `RejectReason`
* Split valid and invalid records
* Deduplicate valid sales records by `OrderID`
* Add `CustomerCategory`
* Select final output columns
* Write valid records to `processed/sales/`
* Write invalid records to `error/sales/`

## 9. Data Quality Rules Implemented

The sales data flow created a `RejectReason` value for invalid records.

Implemented rejection rules included:

| Rule                                         | Reject Reason        |
| -------------------------------------------- | -------------------- |
| Missing or blank customer ID                 | `NULL_CUSTOMER`      |
| Missing, invalid, or non-positive quantity   | `INVALID_QUANTITY`   |
| Missing, invalid, or non-positive unit price | `INVALID_UNIT_PRICE` |
| Missing country value                        | `MISSING_COUNTRY`    |
| Country outside allowed values               | `INVALID_COUNTRY`    |

Allowed country values in the data flow were:

```text
USA
CANADA
UK
INDIA
```

Valid records had an empty `RejectReason` and continued to the processed output. Invalid records were routed to the error output.

Duplicate sales records were handled separately using a Window transformation and filter logic. The pipeline kept the first valid record per `OrderID` before loading data into SQL.

## 10. SQL Serving Layer

Processed sales records were loaded into:

```text
dbo.FactSales
```

The table includes:

* `FactSalesID`
* `OrderID`
* `CustomerID`
* `ProductID`
* `Quantity`
* `UnitPrice`
* `OrderDate`
* `Country`
* `SalesChannel`
* `TotalAmount`
* `CustomerCategory`
* `LoadDate`

The SQL scripts are stored in the `sql/` folder.

## 11. Audit Logging

The project includes SQL-based ETL audit logging using:

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

This makes the pipeline easier to monitor, validate, and troubleshoot.

## 12. Monitoring

Monitoring was implemented using:

* Azure Data Factory Monitor
* Log Analytics Workspace
* SQL audit table

ADF diagnostic logs were sent to Log Analytics for:

* Pipeline runs
* Activity runs
* Trigger runs

This supports tracking successful runs, failures, durations, and operational pipeline history.

## 13. Trigger Configuration

A daily schedule trigger was configured:

```text
TRG_Daily_Retail_ETL
```

The trigger is associated with:

```text
PL_Master_Retail_ETL
```

The trigger was configured for automation. During learning and testing, it can remain stopped when not actively needed to avoid unnecessary recurring cost.

## 14. Validation Performed

The project was validated using SQL queries, ADF Monitor, Log Analytics, and screenshots.

Validation checks included:

* `FactSales` row count
* Loaded sample sales records
* Duplicate `OrderID` check
* Invalid quantity record rejection
* Null customer record rejection
* Valid record load verification
* ETL audit log verification
* Master pipeline run verification

## 15. Design Decisions

Key design decisions in this project:

* Azure Data Factory was used as the orchestration service because it supports linked services, datasets, copy activities, Mapping Data Flow, triggers, and monitoring.
* Azure Data Lake Storage Gen2 was used to separate raw, processed, error, curated, archive, and log storage zones.
* Azure Key Vault was used to avoid hardcoding AWS and SQL credentials inside ADF.
* Metadata validation was added before copying files to prevent missing or empty files from being processed.
* Mapping Data Flow was used to clean, validate, deduplicate, and transform sales records.
* Invalid records were stored in the `error/sales/` path instead of being silently discarded.
* Processed sales records were stored as Parquet in `processed/sales/` before loading into Azure SQL Database.
* Azure SQL Database was used as the structured serving layer through the `dbo.FactSales` table.
* ETL audit logging was implemented using `dbo.ETLAuditLog` and `dbo.usp_InsertETLAuditLog`.
* Log Analytics was configured to capture ADF pipeline, activity, and trigger run logs.
* A daily schedule trigger was configured for automation, but it can remain stopped during learning/testing to control cost.

## 16. Project Outcome

This project demonstrates practical Data Engineering skills in:

* Azure Data Factory pipeline development
* Cross-cloud ingestion from AWS S3 to Azure
* ADLS Gen2 data lake organization
* Key Vault-secured credential management
* Managed identity and RBAC
* Mapping Data Flow transformation
* File-level validation
* Row-level data quality handling
* Error record separation
* Parquet output generation
* Azure SQL Database loading
* SQL audit logging
* Log Analytics monitoring
* Trigger-based automation
* GitHub-based project documentation
