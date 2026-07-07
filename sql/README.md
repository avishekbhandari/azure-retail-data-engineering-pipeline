# SQL Scripts

This folder contains the SQL scripts used for the Azure Retail Data Engineering Pipeline.

The SQL layer supports the final serving table, ETL audit logging, and validation checks after processed sales data is loaded from Azure Data Lake Storage Gen2 into Azure SQL Database.

## Files

| File                                   | Purpose                                                                                                                                                  |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `01_create_fact_sales_table.sql`       | Creates the final `dbo.FactSales` table used to store cleaned sales records loaded from processed Parquet files                                          |
| `02_create_etl_audit_log_table.sql`    | Creates the `dbo.ETLAuditLog` table used to track Azure Data Factory pipeline execution                                                                  |
| `03_create_audit_stored_procedure.sql` | Creates the stored procedure called by Azure Data Factory to insert audit log records                                                                    |
| `04_validation_queries.sql`            | Contains SQL queries used to validate row counts, loaded records, duplicate checks, invalid-record exclusion, valid-record loading, and audit log output |

## FactSales Table

The `dbo.FactSales` table is the final SQL serving layer for processed sales records.

It includes:

* `FactSalesID` as the SQL-generated surrogate primary key
* `OrderID`, `CustomerID`, and `ProductID`
* `Quantity` and `UnitPrice`
* `OrderDate`
* `Country`
* `SalesChannel`
* `TotalAmount`
* `CustomerCategory`
* `LoadDate`

The data loaded into this table comes from the processed Parquet output path:

```text
processed/sales/
```

## ETL Audit Logging

The `dbo.ETLAuditLog` table tracks execution details from Azure Data Factory.

It captures:

* Pipeline name
* Activity name
* Run ID
* Status
* Rows loaded
* Load start time
* Load end time
* Error message
* Created timestamp

This helps verify that the SQL load pipeline executed successfully and provides operational visibility for debugging and monitoring.

## Validation Queries

The validation queries check:

* Total rows loaded into `dbo.FactSales`
* Sample loaded records
* Duplicate `OrderID` values
* Known invalid records excluded from the SQL table
* Known valid records loaded correctly
* Audit records inserted into `dbo.ETLAuditLog`

The invalid-record checks verify that bad records such as null customer records and invalid quantity records were not loaded into the final SQL serving table.

The rejected records themselves are preserved separately in the ADLS error zone:

```text
error/sales/
```

These checks support the final project validation and help prove that the pipeline is not only running, but also producing correct data.
