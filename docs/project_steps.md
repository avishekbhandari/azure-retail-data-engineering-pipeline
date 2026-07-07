# Project Steps: Azure Retail Data Engineering Pipeline

## 1. Project Purpose

This project implements an end-to-end Azure Data Engineering pipeline for retail sales data.

The pipeline ingests CSV files from AWS S3, lands them in Azure Data Lake Storage Gen2, validates source files, transforms sales data using Azure Data Factory Mapping Data Flow, writes valid records as Parquet, routes invalid records to an error folder, loads processed sales data into Azure SQL Database, and records execution details in an ETL audit table.

---

## 2. Architecture Flow

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

---

## 3. Azure Resources Created

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

---

## 4. ADLS Gen2 Container Setup

The ADLS Gen2 storage account was organized into separate containers:

```text
raw/
processed/
curated/
error/
archive/
$logs/
```

| Container   | Purpose                                       |
| ----------- | --------------------------------------------- |
| `raw`       | Stores original CSV files copied from AWS S3  |
| `processed` | Stores cleaned valid sales records as Parquet |
| `error`     | Stores invalid/rejected sales records         |
| `curated`   | Reserved for future business-ready outputs    |
| `archive`   | Reserved for future archive files             |
| `$logs`     | Storage logging container                     |

The SQL load in this project uses processed sales data from:

```text
processed/sales/
```

---

## 5. AWS S3 Source Setup

The source files were stored in AWS S3.

```text
Bucket: azure-retail
Folder: source/
```

Source files:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

All three files were copied into the ADLS raw zone. The main transformation and SQL loading implementation focused on the sales dataset.

---

## 6. Security Setup

Azure Key Vault was used to store credentials securely.

Key Vault secrets:

```text
aws-access-key
aws-secret-key
sql-admin-password
```

ADF accessed these secrets through Key Vault instead of hardcoding credentials directly in pipelines.

Main access controls used:

| Access Setup                  | Purpose                                            |
| ----------------------------- | -------------------------------------------------- |
| ADF managed identity          | Allows ADF to access Azure resources securely      |
| Storage Blob Data Contributor | Allows ADF to read/write ADLS files                |
| Key Vault Secrets User        | Allows ADF to read Key Vault secrets               |
| Key Vault Secrets Officer     | Allows secret creation and management during setup |

---

## 7. ADF Linked Services

The following linked services were created in Azure Data Factory:

| Linked Service       | Purpose                            |
| -------------------- | ---------------------------------- |
| `LS_KeyVault_Retail` | Connects ADF to Azure Key Vault    |
| `LS_ADLS_Retail`     | Connects ADF to ADLS Gen2          |
| `LS_AWS_S3_Retail`   | Connects ADF to AWS S3             |
| `LS_AzureSQL_Retail` | Connects ADF to Azure SQL Database |

---

## 8. ADF Datasets

The project used datasets for S3 source files, ADLS raw files, Parquet outputs, and Azure SQL.

### S3 Source Datasets

```text
DS_S3_Sales_CSV
DS_S3_Customer_CSV
DS_S3_Product_CSV
```

### ADLS Raw Datasets

```text
DS_ADLS_Raw_Sales_CSV
DS_ADLS_Raw_Customer_CSV
DS_ADLS_Raw_Product_CSV
```

### Parquet Output Datasets

```text
DS_ADLS_Processed_Sales_Parquet
DS_ADLS_Error_Sales_Parquet
```

### Azure SQL Dataset

```text
DS_AzureSQL_FactSales
```

---

## 9. S3 to ADLS Ingestion Pipeline

Pipeline name:

```text
PL_S3_To_ADLS
```

This pipeline copies source CSV files from AWS S3 into ADLS raw storage.

Files copied:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

Raw output paths:

```text
raw/sales/sales_data.csv
raw/customer/customer_data.csv
raw/product/product_data.csv
```

The pipeline uses the following pattern for each source file:

```text
Get Metadata
  ↓
If Condition
  ├── True: Copy file from AWS S3 to ADLS
  └── False: Fail pipeline
```

This prevents missing or empty files from being processed downstream.

---

## 10. Metadata Validation

The ingestion pipeline checks whether each source file:

1. Exists
2. Has file size greater than zero

Example validation expression:

```text
@and(
    equals(activity('Get_Metadata_Sales').output.exists, true),
    greater(activity('Get_Metadata_Sales').output.size, 0)
)
```

This validation was applied to sales, customer, and product files before copying them to ADLS.

---

## 11. Sales Cleansing Data Flow

Data flow name:

```text
DF_Sales_Cleansing
```

This Mapping Data Flow reads raw sales data from ADLS and creates two outputs:

```text
processed/sales/   → valid sales records
error/sales/       → invalid sales records
```

The data flow source is:

```text
DS_ADLS_Raw_Sales_CSV
```

The output datasets are:

```text
DS_ADLS_Processed_Sales_Parquet
DS_ADLS_Error_Sales_Parquet
```

---

## 12. Sales Data Transformation Logic

The data flow performs the following transformations:

| Step                    | Transformation                                               |
| ----------------------- | ------------------------------------------------------------ |
| Standardize columns     | Convert quantity, unit price, order date, and country values |
| Create validation flags | Create `RejectReason` for invalid records                    |
| Split records           | Separate valid and invalid records                           |
| Deduplicate records     | Keep the first valid record per `OrderID`                    |
| Add business column     | Create `CustomerCategory`                                    |
| Select final columns    | Keep only the final processed sales columns                  |

Final processed columns:

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

---

## 13. Data Quality Rules

The data flow creates a `RejectReason` column for invalid records.

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

Invalid records are written to:

```text
error/sales/
```

Duplicate records are handled separately using a Window transformation and filter logic. They are deduplicated before SQL loading, not documented as error-folder records.

---

## 14. Processed and Error Outputs

After the sales transformation pipeline runs successfully, ADF writes:

```text
processed/sales/
error/sales/
```

Both outputs are written in Parquet format with Snappy compression.

The processed output contains clean sales records ready for SQL loading.
The error output contains rejected records for review and troubleshooting.

---

## 15. Azure SQL Database Setup

Azure SQL Database was used as the structured serving layer.

Database:

```text
RetailDW
```

Final table:

```text
dbo.FactSales
```

Audit table:

```text
dbo.ETLAuditLog
```

Stored procedure:

```text
dbo.usp_InsertETLAuditLog
```

SQL scripts are stored in:

```text
sql/
```

---

## 16. FactSales Table

The final processed sales records are loaded into:

```text
dbo.FactSales
```

Script:

```text
sql/01_create_fact_sales_table.sql
```

The table includes:

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

`FactSalesID` is generated by SQL Server and is not mapped from the Parquet source.

---

## 17. Parquet to SQL Load Pipeline

Pipeline name:

```text
PL_Parquet_To_SQL
```

Main activity:

```text
Copy_Processed_Sales_To_FactSales
```

Source:

```text
processed/sales/*.parquet
```

Sink:

```text
dbo.FactSales
```

The SQL sink uses this pre-copy script:

```sql
TRUNCATE TABLE dbo.FactSales;
```

This supports full-refresh loading and prevents duplicate rows during repeated test runs.

---

## 18. SQL Column Mapping

The Parquet-to-SQL pipeline maps the processed sales columns into `dbo.FactSales`.

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

The identity column `FactSalesID` is not mapped.

---

## 19. Audit Logging

Audit logging was implemented using:

```text
dbo.ETLAuditLog
dbo.usp_InsertETLAuditLog
```

The audit table stores:

```text
PipelineName
ActivityName
RunID
Status
RowsLoaded
LoadStartTime
LoadEndTime
ErrorMessage
CreatedAt
```

The stored procedure activity in ADF runs after the SQL copy activity succeeds.

Audit activity:

```text
Audit_Parquet_To_SQL_Load
```

This captures SQL load execution details such as pipeline name, run ID, status, rows loaded, and timestamps.

---

## 20. Master Pipeline

Pipeline name:

```text
PL_Master_Retail_ETL
```

The master pipeline orchestrates the full workflow.

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

The delete activities remove old processed and error Parquet outputs before generating new outputs.

The SQL load pipeline truncates `dbo.FactSales` before insert, so repeated test runs do not duplicate rows in the final table.

---

## 21. Trigger Configuration

Trigger name:

```text
TRG_Daily_Retail_ETL
```

Trigger type:

```text
ScheduleTrigger
```

Related pipeline:

```text
PL_Master_Retail_ETL
```

The trigger was configured for daily execution and kept stopped during learning/testing to avoid unnecessary recurring cost. It can be started when scheduled automation is required.

---

## 22. Monitoring

Monitoring was implemented using:

```text
ADF Monitor
Log Analytics Workspace
SQL audit table
```

ADF diagnostic logs were sent to Log Analytics for:

```text
Pipeline runs
Activity runs
Trigger runs
```

Example KQL query used for verification:

```kusto
ADFActivityRun
| where TimeGenerated > ago(24h)
| where PipelineName == "PL_S3_To_ADLS" and Status == "Succeeded"
| order by TimeGenerated desc
| project TimeGenerated, PipelineName, ActivityName, ActivityType, Status
```

---

## 23. Final Validation

The project was validated using ADF pipeline runs, ADLS output files, SQL queries, audit log records, Log Analytics, and screenshots.

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

SQL validation script:

```text
sql/04_validation_queries.sql
```

---

## 24. Repository Evidence

The repository includes:

| Folder          | Purpose                                             |
| --------------- | --------------------------------------------------- |
| `adf/`          | Azure Data Factory JSON artifacts                   |
| `docs/`         | Project documentation                               |
| `sql/`          | SQL table, audit, procedure, and validation scripts |
| `screenshots/`  | Evidence screenshots                                |
| `data/`         | Sample source data                                  |
| `architecture/` | Architecture documentation                          |

Screenshots are stored in:

```text
screenshots/
```

They provide evidence for resource creation, linked services, datasets, pipelines, data flow, SQL validation, audit logging, master pipeline, trigger configuration, and monitoring.

---

## 25. Final Outcome

This project demonstrates:

* Cross-cloud ingestion from AWS S3 to Azure
* ADLS Gen2 data lake organization
* Secure credential handling with Azure Key Vault
* ADF linked services and datasets
* Metadata-based file validation
* ADF Mapping Data Flow transformation
* Row-level validation and error handling
* Deduplication of sales records
* Parquet output generation
* Azure SQL Database loading
* Full-refresh SQL load control
* ETL audit logging
* ADF Monitor and Log Analytics monitoring
* Master pipeline orchestration
* Schedule trigger configuration
* GitHub documentation with screenshots and SQL scripts
