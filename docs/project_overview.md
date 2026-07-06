# Project Overview: Azure Retail Data Engineering Pipeline

## 1. Definition

This project is a batch Azure Data Engineering pipeline that moves retail sales data from AWS S3 into Azure, stores the raw files in Azure Data Lake Storage Gen2, transforms the data with Azure Data Factory, writes curated Parquet outputs, loads clean records into Azure SQL Database, and records pipeline execution details in an ETL audit table.

```text
AWS S3 source files -> Azure Data Factory -> ADLS Gen2 -> Mapping Data Flow -> Azure SQL Database -> Audit and monitoring
```

## 2. Why It Matters

A professional data pipeline is not just a copy job. It must handle ingestion, validation, transformation, error handling, loading, monitoring, and documentation. This project demonstrates core cloud Data Engineering responsibilities:

- Cross-cloud ingestion from AWS to Azure
- Raw, processed, error, curated, and archive storage zones
- File-level validation before processing
- Row-level validation during transformation
- Deduplication and business-rule transformations
- Structured serving layer in Azure SQL Database
- Audit logging for operational visibility
- Monitoring through Azure Data Factory and Log Analytics

## 3. Architecture

```text
Retail CSV files in AWS S3
        ↓
Azure Data Factory linked service
        ↓
ADLS Gen2 raw zone
        ↓
ADF Mapping Data Flow
        ├── Valid records -> processed zone as Parquet
        └── Invalid records -> error zone as Parquet
        ↓
Azure SQL Database: dbo.FactSales
        ↓
ETL audit table: dbo.ETLAuditLog
        ↓
ADF Monitor and Log Analytics
```

## 4. Tools and Services Used

| Tool / Service | Role in the Project |
|---|---|
| AWS S3 | Source location for raw retail CSV files |
| Azure Data Factory | Orchestration, ingestion, validation, transformation, and scheduling |
| Azure Data Lake Storage Gen2 | Storage layer for raw, processed, error, curated, and archive data |
| ADF Mapping Data Flow | Cleansing, derived columns, validation, deduplication, and split logic |
| Azure SQL Database | Structured serving layer for analytics-ready sales records |
| Azure Key Vault | Centralized secure reference management for pipeline configuration |
| Managed Identity and RBAC | Controlled service-to-service access pattern |
| Log Analytics Workspace | Diagnostic log analysis for pipeline runs and activity runs |
| GitHub | Version control and project documentation |

## 5. Dataset Description

| File | Description |
|---|---|
| sales_data.csv | Sales transaction records such as order ID, product ID, customer ID, quantity, unit price, and order date |
| customer_data.csv | Customer reference data such as customer ID, customer name, country, and customer type |
| product_data.csv | Product reference data such as product ID, category, and product price |

## 6. Pipeline Flow

1. Azure Data Factory connects to AWS S3 and copies retail CSV files into the ADLS Gen2 raw zone.
2. ADF validates file existence and file size before downstream processing.
3. Mapping Data Flow standardizes data types, trims string values, calculates derived columns, separates invalid records, and removes duplicate orders.
4. Valid records are written as Parquet files to the processed zone.
5. Invalid records are written separately to the error zone with a rejection reason.
6. Processed records are loaded into Azure SQL Database table dbo.FactSales.
7. Pipeline execution metadata is inserted into dbo.ETLAuditLog for operational tracking.

## 7. Interview-Ready Explanation

This project demonstrates an Azure batch data engineering pattern. Retail CSV files are copied from AWS S3 into ADLS Gen2 using Azure Data Factory. The pipeline validates files before processing, transforms sales records using ADF Mapping Data Flow, separates valid and invalid records, writes clean data in Parquet format, loads curated records into Azure SQL Database, and tracks execution using an ETL audit table and ADF monitoring.

## 8. Common Mistakes and Warnings

- Do not describe this as only a file-copy project. The value is in validation, transformation, audit logging, and monitoring.
- Do not ignore invalid records. Rejected records need a clear error-zone path and rejection reason.
- Do not hard-code environment-specific configuration into project files.
- Do not claim production readiness unless retry handling, alerting, access control, cost controls, and deployment strategy are also explained.
