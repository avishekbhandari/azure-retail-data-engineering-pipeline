# Data Quality Rules: Azure Retail Data Engineering Pipeline

## 1. Definition

Data quality rules are validation checks used to decide whether incoming records are safe to process, load, and expose for analytics. In this project, data quality is handled at two levels:

```text
File-level validation -> Is the source file available and usable?
Row-level validation  -> Is each record complete, valid, and business-ready?
```

## 2. Why It Matters

Without data quality checks, a pipeline can silently load bad data into reporting tables. That causes incorrect dashboards, broken reconciliation, duplicate transactions, and low trust from business users.

For a Data Engineer, data quality is not optional. It is part of production pipeline ownership.

## 3. File-Level Validation Rules

ADF validates source files before processing.

| Rule | Description | Failure Action |
|---|---|---|
| File exists | Confirm the expected source file is available in AWS S3 | Stop pipeline with Fail activity |
| File size greater than zero | Confirm the file is not empty | Stop pipeline with Fail activity |
| Expected file format | Confirm the source file follows the expected CSV format | Reject or stop processing |
| Expected landing path | Confirm files land in the correct ADLS Gen2 raw folder | Stop downstream processing |

## 4. Row-Level Validation Rules

The Mapping Data Flow validates each record before writing output.

| Rule | Valid Condition | Reject Reason |
|---|---|---|
| Order ID is present | OrderID is not null or blank | Missing OrderID |
| Customer ID is present | CustomerID is not null or blank | Missing CustomerID |
| Product ID is present | ProductID is not null or blank | Missing ProductID |
| Quantity is valid | Quantity > 0 | Invalid Quantity |
| Unit price is valid | UnitPrice > 0 | Invalid UnitPrice |
| Order date is valid | OrderDate can be parsed as a date | Invalid OrderDate |
| Country is valid | Country is not null after trimming | Invalid Country |
| Duplicate order removed | Keep one record per OrderID | Duplicate OrderID |

## 5. Derived Columns

The transformation logic creates additional columns used for analytics and pipeline traceability.

| Column | Logic | Purpose |
|---|---|---|
| TotalAmount | Quantity * UnitPrice | Sales revenue calculation |
| LoadDate | Current pipeline load date | Data lineage and audit tracking |
| CustomerCategory | Business classification based on customer attributes | Reporting segmentation |
| RejectReason | Reason why a record failed validation | Error analysis and troubleshooting |

## 6. Valid and Invalid Record Handling

### Valid Records

Valid records are written to the processed zone as Parquet:

```text
processed/sales/
```

These records are later loaded into Azure SQL Database table:

```text
dbo.FactSales
```

### Invalid Records

Invalid records are written separately to the error zone:

```text
error/sales/
```

Invalid records should not be deleted immediately. They should be preserved for troubleshooting, reconciliation, and source-system correction.

## 7. Deduplication Strategy

Duplicate sales records are handled using OrderID as the business key.

Expected behavior:

```text
If multiple records have the same OrderID, keep the most reliable/latest record and reject or remove duplicates from the final output.
```

Interview explanation:

> Deduplication prevents the same transaction from being counted multiple times in the final reporting table. In this project, OrderID is treated as the transaction-level business key.

## 8. SQL Validation Queries

After loading data into Azure SQL Database, run validation queries.

### Row Count Check

```sql
SELECT COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;
```

### Duplicate Check

```sql
SELECT
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;
```

### Invalid Null Check

```sql
SELECT *
FROM dbo.FactSales
WHERE OrderID IS NULL
   OR CustomerID IS NULL
   OR ProductID IS NULL;
```

### Revenue Check

```sql
SELECT
    SUM(TotalAmount) AS TotalRevenue
FROM dbo.FactSales;
```

### Audit Verification

```sql
SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;
```

## 9. Monitoring and Alerting Considerations

A production-style pipeline should monitor:

- Pipeline run status
- Failed activities
- Source file missing or empty conditions
- Row count changes
- Unexpected spike in rejected records
- SQL load failures
- Audit log insert failures

## 10. Interview-Ready Explanation

This project applies both file-level and row-level data quality checks. ADF validates whether the source file exists and is not empty before processing. During transformation, Mapping Data Flow validates required fields, checks quantity and price values, derives TotalAmount, removes duplicate OrderID records, and splits invalid records into an error zone with a RejectReason. After loading valid records into Azure SQL Database, SQL validation checks confirm row counts, duplicates, nulls, revenue totals, and audit log entries.

## 11. Common Mistakes and Warnings

- Do not load all records blindly into the final table.
- Do not discard invalid records without storing rejection details.
- Do not rely only on row counts; also validate duplicates, nulls, and business-rule violations.
- Do not treat data quality as a one-time check. It should be part of every pipeline run.
- Do not claim production-grade quality unless monitoring and alerting are also implemented.
