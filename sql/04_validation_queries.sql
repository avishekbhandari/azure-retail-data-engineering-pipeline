/*
Purpose:
    Validation queries for the Azure Retail Data Engineering Pipeline.

Run these checks after the processed data has been loaded into dbo.FactSales.
The goal is to verify row counts, duplicates, required fields, revenue values,
and audit records.
*/

-- 1. Total loaded row count
SELECT COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;
GO

-- 2. Duplicate transaction check
SELECT
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;
GO

-- 3. Required field null check
SELECT *
FROM dbo.FactSales
WHERE OrderID IS NULL
   OR CustomerID IS NULL
   OR ProductID IS NULL
   OR OrderDate IS NULL;
GO

-- 4. Invalid quantity or price check
SELECT *
FROM dbo.FactSales
WHERE Quantity <= 0
   OR UnitPrice <= 0
   OR TotalAmount <= 0;
GO

-- 5. Revenue reconciliation check
SELECT
    COUNT(*) AS TotalOrders,
    SUM(Quantity) AS TotalQuantity,
    SUM(TotalAmount) AS TotalRevenue
FROM dbo.FactSales;
GO

-- 6. Recent audit records
SELECT TOP 10
    AuditID,
    PipelineName,
    ActivityName,
    RunID,
    RunStatus,
    RowsLoaded,
    StartTime,
    EndTime,
    CreatedAt
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;
GO

-- 7. Audit status summary
SELECT
    RunStatus,
    COUNT(*) AS RunCount
FROM dbo.ETLAuditLog
GROUP BY RunStatus;
GO
