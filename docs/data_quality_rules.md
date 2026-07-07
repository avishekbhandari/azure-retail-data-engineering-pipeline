# Data Quality Rules: Azure Retail Data Engineering Pipeline

## 1. Purpose

This document describes the data quality rules implemented in the Azure Retail Data Engineering Pipeline.

The pipeline applies validation at two levels:

```text
File-level validation → validate source files before ingestion
Row-level validation  → validate sales records during transformation
```

The goal is to prevent missing files, empty files, invalid records, duplicate records, and bad business values from contaminating the final SQL serving table.

## 2. Scope

This document covers the data quality logic implemented for the sales dataset in:

```text
DF_Sales_Cleansing
```

The project ingests three source files from AWS S3:

```text
sales_data.csv
customer_data.csv
product_data.csv
```

Customer and product files are copied into the ADLS raw zone for future extension. The main transformation, validation, error handling, Parquet output, and SQL loading process in this implementation focuses on the sales dataset.

## 3. Data Quality Flow

The sales data quality flow is:

```text
Raw sales CSV
  ↓
Standardize columns and data types
  ↓
Create RejectReason
  ↓
Split records
  ├── Valid records   → processed/sales/
  └── Invalid records → error/sales/
  ↓
Deduplicate valid records
  ↓
Add CustomerCategory
  ↓
Select final columns
  ↓
Load processed records into dbo.FactSales
```

## 4. File-Level Validation

Before copying files from AWS S3 into ADLS Gen2, the ingestion pipeline validates source files.

Pipeline:

```text
PL_S3_To_ADLS
```

Validation pattern:

```text
Get Metadata
  ↓
If Condition
  ├── True: Copy file
  └── False: Fail pipeline
```

The pipeline checks:

| Validation                  | Purpose                                                  | Failure Handling                 |
| --------------------------- | -------------------------------------------------------- | -------------------------------- |
| File exists                 | Confirms the expected source file is available in AWS S3 | Fail activity stops the pipeline |
| File size greater than zero | Confirms the file is not empty                           | Fail activity stops the pipeline |

Example ADF expression pattern:

```text
@and(
    equals(activity('Get_Metadata_Sales').output.exists, true),
    greater(activity('Get_Metadata_Sales').output.size, 0)
)
```

This prevents missing or empty source files from being copied and processed downstream.

## 5. Column Standardization

The sales data flow standardizes raw CSV fields before validation.

Transformation:

```text
DerivedSalesStandardizedColumns
```

Standardization logic:

| Output Column       | Logic                          | Purpose                                          |
| ------------------- | ------------------------------ | ------------------------------------------------ |
| `Quantity_Int`      | Convert `Quantity` to integer  | Enables numeric validation and SQL loading       |
| `UnitPrice_Decimal` | Convert `UnitPrice` to decimal | Enables price validation and revenue calculation |
| `OrderDate_Clean`   | Convert `OrderDate` to date    | Enables date ordering and SQL loading            |
| `Country_Clean`     | Trim and uppercase `Country`   | Standardizes country values                      |
| `TotalAmount`       | `Quantity * UnitPrice`         | Calculates sales amount                          |
| `LoadDate`          | Current processing timestamp   | Tracks when the record was processed             |

## 6. Row-Level Validation Rules

The data flow creates a `RejectReason` column to identify invalid records.

Transformation:

```text
DerivedSalesValidationFlags
```

Implemented validation rules:

| Rule                   | Condition                                              | Reject Reason        |
| ---------------------- | ------------------------------------------------------ | -------------------- |
| Customer ID is missing | `CustomerID` is null or blank                          | `NULL_CUSTOMER`      |
| Quantity is invalid    | `Quantity_Int` is null or less than/equal to zero      | `INVALID_QUANTITY`   |
| Unit price is invalid  | `UnitPrice_Decimal` is null or less than/equal to zero | `INVALID_UNIT_PRICE` |
| Country is missing     | `Country_Clean` is null or blank                       | `MISSING_COUNTRY`    |
| Country is not allowed | `Country_Clean` is not in the allowed country list     | `INVALID_COUNTRY`    |

Allowed country values:

```text
USA
CANADA
UK
INDIA
```

Records with no validation issue receive an empty `RejectReason`.

## 7. Valid and Invalid Record Split

A Conditional Split transformation separates valid and invalid sales records.

Transformation:

```text
SplitValidInvalidSales
```

Split logic:

| Output Stream      | Condition            | Destination                                    |
| ------------------ | -------------------- | ---------------------------------------------- |
| `ValidSalesRows`   | `RejectReason == ''` | Continue to deduplication and processed output |
| `InvalidSalesRows` | `RejectReason != ''` | Write to error output                          |

Output paths:

```text
Valid records   → processed/sales/
Invalid records → error/sales/
```

This allows the pipeline to continue processing valid records while preserving invalid records for review.

## 8. Error Record Handling

Invalid records are written to:

```text
error/sales/
```

Output format:

```text
Parquet
```

The error output keeps records that failed validation rules. This is better than silently dropping bad records because rejected data can be reviewed later for troubleshooting, source-system correction, and reconciliation.

Examples of rejected records include:

* Records with missing customer ID
* Records with invalid or non-positive quantity
* Records with invalid or non-positive unit price
* Records with missing country
* Records with country values outside the allowed list

## 9. Deduplication Rule

Duplicate handling is applied only after records pass the validation split.

Transformation:

```text
WindowOrderDeduplication
```

The data flow applies a window over:

```text
OrderID
```

and orders records by:

```text
OrderDate_Clean
```

It creates:

```text
OrderRowNumber = rowNumber()
```

Then the filter keeps:

```text
OrderRowNumber == 1
```

Filter transformation:

```text
FilterFirstOrderRecord
```

This means the final processed output keeps the first valid record per `OrderID`.

Important note: duplicate records are handled through deduplication logic. They are not documented as error-folder records in this implementation.

## 10. Derived Business Column

After validation and deduplication, the data flow creates a customer classification column.

Transformation:

```text
DerivedCustomerCategory
```

Logic:

```text
If TotalAmount >= 1000 → CustomerCategory = Premium
Otherwise              → CustomerCategory = Standard
```

This adds a simple analytics-ready business attribute to the final sales output.

## 11. Final Processed Columns

The final selected sales columns are:

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

These columns are written to:

```text
processed/sales/
```

and later loaded into:

```text
dbo.FactSales
```

## 12. SQL Validation Checks

After the processed Parquet data is loaded into Azure SQL Database, validation queries are used to confirm that the final table contains the expected clean records.

SQL table:

```text
dbo.FactSales
```

Validation checks include:

| Check                            | Purpose                                                      |
| -------------------------------- | ------------------------------------------------------------ |
| Row count check                  | Confirms expected number of records loaded                   |
| Sample data check                | Confirms records were inserted correctly                     |
| Duplicate `OrderID` check        | Confirms deduplication worked                                |
| Invalid quantity rejection check | Confirms bad quantity records did not enter SQL              |
| Null customer rejection check    | Confirms null customer records did not enter SQL             |
| Valid record check               | Confirms known valid records were loaded                     |
| Audit log check                  | Confirms ADF inserted execution details into the audit table |

Example duplicate check:

```sql
SELECT 
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;
```

Example audit check:

```sql
SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;
```

The full validation script is stored in:

```text
sql/04_validation_queries.sql
```

## 13. Audit Logging Support

The SQL load pipeline writes execution details to:

```text
dbo.ETLAuditLog
```

using:

```text
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

This supports operational monitoring and helps verify that the SQL load completed successfully.

## 14. Limitations and Future Improvements

The current implementation handles core file-level and row-level validation, but the following improvements could be added later:

* Store rejected record counts in a SQL audit or data quality summary table
* Add alerting when rejected record count exceeds a threshold
* Add schema drift/schema mismatch handling as a separate validation step
* Add source-to-target reconciliation between raw, processed, and SQL layers
* Add incremental load logic using a watermark table
* Add merge/upsert logic instead of full refresh or insert-only behavior
* Build a Power BI report using `dbo.FactSales`

## 15. Summary

The data quality design in this project ensures that:

* Missing or empty source files are stopped before ingestion
* Invalid sales records are separated from valid records
* Rejected records are preserved in the ADLS error zone
* Duplicate valid sales records are deduplicated before SQL loading
* Processed sales records are loaded into `dbo.FactSales`
* SQL validation queries confirm row counts, duplicate handling, rejected records, valid records, and audit logging

This makes the pipeline more reliable, traceable, and easier to defend as a Data Engineering project.
