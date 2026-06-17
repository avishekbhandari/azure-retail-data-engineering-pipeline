

-- 1. Verify total rows loaded into FactSales
SELECT 
    COUNT(*) AS FactSalesRowCount
FROM dbo.FactSales;


-- 2. View loaded FactSales records
SELECT TOP 10 *
FROM dbo.FactSales
ORDER BY OrderID;


-- 3. Check duplicate OrderID values

SELECT 
    OrderID,
    COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY OrderID
HAVING COUNT(*) > 1;


-- 4. Verify invalid quantity record was rejected
-- OrderID 1004 had invalid/negative quantity in the raw data

SELECT *
FROM dbo.FactSales
WHERE OrderID = '1004';


-- 5. Verify null customer record was rejected
-- OrderID 1003 had invalid/null customer information

SELECT *
FROM dbo.FactSales
WHERE OrderID = '1003';


-- 6. Verify valid sales record was loaded
-- OrderID 1005 is a valid record and should exist in FactSales

SELECT *
FROM dbo.FactSales
WHERE OrderID = '1005';


-- 7. Verify ETL audit log records
-- This confirms that the ADF pipeline inserted audit information
SELECT TOP 10 *
FROM dbo.ETLAuditLog
ORDER BY AuditID DESC;