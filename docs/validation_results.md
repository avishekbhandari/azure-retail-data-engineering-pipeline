# Validation Results: Azure Retail Data Engineering Pipeline

## 1. Purpose

This document summarizes the validation checks performed after running the Azure Retail Data Engineering Pipeline.

The purpose of this file is to show that the pipeline did not only run successfully, but also produced correct and validated output across ingestion, transformation, SQL loading, audit logging, and monitoring.

---

## 2. Validation Summary

| Validation Area | What Was Checked | Expected Result | Status |
|---|---|---|---|
| S3 to ADLS ingestion | Source files copied from AWS S3 to ADLS raw zone | Sales, customer, and product files available in ADLS raw storage | Passed |
| File metadata validation | File exists and file size is greater than zero | Pipeline continues only when source files are valid | Passed |
| Processed output | Valid sales records written to Parquet | Files created in `processed/sales/` | Passed |
| Error output | Invalid sales records written separately | Files created in `error/sales/` | Passed |
| SQL load | Processed sales records loaded into Azure SQL Database | Clean records available in `dbo.FactSales` | Passed |
| Duplicate check | Duplicate `OrderID` values checked | No duplicate `OrderID` values in final SQL table | Passed |
| Invalid quantity rejection | OrderID `1004` checked | Invalid quantity record not loaded into `dbo.FactSales` | Passed |
| Null customer rejection | OrderID `1003` checked | Null customer record not loaded into `dbo.FactSales` | Passed |
| Valid record check | OrderID `1005` checked | Valid record loaded into `dbo.FactSales` | Passed |
| Audit logging | ETL audit table checked | Audit record inserted into `dbo.ETLAuditLog` | Passed |
| Master pipeline | End-to-end orchestration checked | `PL_Master_Retail_ETL` completed successfully | Passed |
| Monitoring | ADF diagnostic logs checked in Log Analytics | Pipeline and activity run logs available | Passed |

---

## 3. SQL Validation Queries

The following SQL checks were used to validate the final SQL output.

### 3.1 FactSales Row Count

```sql
SELECT 
    COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;
```

### 3.2 Loaded Sales Records

```sql
SELECT TOP 10 *
FROM dbo.FactSales
ORDER BY OrderID;
```

### 3.3 Duplicate OrderID Check

```sql
SELECT 
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;
```

### 3.4 Invalid Quantity Rejection Check

OrderID `1004` had invalid quantity in the raw data and should not be loaded into the final SQL table.

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID = '1004';
```

### 3.5 Null Customer Rejection Check

OrderID `1003` had null or invalid customer information and should not be loaded into the final SQL table.

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID = '1003';
```

### 3.6 Valid Record Load Check

OrderID `1005` is a valid sales record and should exist in the final SQL table.

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID = '1005';
```

### 3.7 Audit Log Verification

```sql
SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;
```

The full SQL validation script is stored in:

```text
sql/04_validation_queries.sql
```

---

## 4. Actual Validation Results

| Check | Actual Result | Status |
|---|---|---|
| `dbo.FactSales` row count | `3` records loaded | Passed |
| Duplicate `OrderID` check | `0` duplicate records returned | Passed |
| OrderID `1004` invalid quantity check | `0` records returned | Passed |
| OrderID `1003` null customer check | `0` records returned | Passed |
| OrderID `1005` valid record check | `1` record returned | Passed |
| Audit log check | Audit record inserted with pipeline execution details | Passed |
| Rows loaded audit value | `RowsLoaded = 3` | Passed |
| Master pipeline run | Completed successfully | Passed |

These results confirm that:

- Valid sales records were loaded into `dbo.FactSales`
- Invalid sales records were excluded from the final SQL table
- Duplicate sales records were deduplicated before SQL loading
- Audit logging captured the SQL load execution
- The master pipeline completed the end-to-end workflow successfully

---

## 5. ADF and Log Analytics Validation

Azure Data Factory Monitor was used to verify pipeline and activity run status.

Log Analytics was used to verify that ADF diagnostic logs were captured for pipeline runs, activity runs, and trigger runs.

Example KQL query used for verification:

```kusto
ADFActivityRun
| where TimeGenerated > ago(24h)
| where PipelineName == "PL_S3_To_ADLS" and Status == "Succeeded"
| order by TimeGenerated desc
| project TimeGenerated, PipelineName, ActivityName, ActivityType, Status
```

This helped confirm that ADF activity execution details were available in Log Analytics.

---

## 6. Screenshot Evidence

Screenshots are stored in:

```text
screenshots/
```

Key validation screenshots:

| Evidence | Screenshot |
|---|---|
| FactSales row count verified | `screenshots/45a_sql_row_count_verified.png` |
| Duplicate check passed | `screenshots/45b_sql_duplicate_check_passed.png` |
| Invalid quantity rejected | `screenshots/45c_sql_invalid_quantity_rejected.png` |
| Null customer rejected | `screenshots/45d_sql_null_customer_rejected.png` |
| Duplicate order deduplicated | `screenshots/45e_sql_duplicate_order_deduplicated.png` |
| Audit log verified | `screenshots/50_sql_audit_log_verified.png` |
| Master pipeline debug success | `screenshots/54_pl_master_retail_etl_debug_success.png` |
| Master run FactSales count verified | `screenshots/55_master_pl_run_factsales_count_verified.png` |
| Master run audit log verified | `screenshots/56_master_pl_run_audit_log_verified.png` |
| Trigger-now master pipeline success | `screenshots/58_trigger_now_master_pipeline_success.png` |

---

## 7. Final Validation Conclusion

The validation results confirm that the Azure Retail Data Engineering Pipeline successfully performed the following:

- Copied source files from AWS S3 to ADLS raw storage
- Validated source file existence and file size before ingestion
- Transformed and validated sales records using ADF Mapping Data Flow
- Wrote valid sales records to `processed/sales/`
- Wrote invalid sales records to `error/sales/`
- Loaded processed sales records into `dbo.FactSales`
- Excluded invalid records from the final SQL table
- Deduplicated sales records before SQL loading
- Inserted pipeline execution details into `dbo.ETLAuditLog`
- Captured monitoring logs through ADF Monitor and Log Analytics
- Completed the end-to-end workflow through `PL_Master_Retail_ETL`

This confirms that the pipeline is functional, validated, and traceable from source ingestion through SQL serving and audit logging.
