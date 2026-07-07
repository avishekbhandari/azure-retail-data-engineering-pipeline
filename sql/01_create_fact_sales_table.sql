/*
Purpose:
    Create the final analytics-ready sales fact table used by the Azure Retail
    Data Engineering Pipeline.

Professional note:
    This table represents the serving layer after ADF has validated, cleaned,
    deduplicated, and transformed raw retail records. In a production system,
    this table would normally be loaded through a controlled ETL process and
    validated after each pipeline run.
*/

IF OBJECT_ID('dbo.FactSales', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.FactSales;
END;
GO

CREATE TABLE dbo.FactSales
(
    SalesKey        INT IDENTITY(1,1) PRIMARY KEY,
    OrderID         VARCHAR(50)  NOT NULL,
    CustomerID      VARCHAR(50)  NOT NULL,
    ProductID       VARCHAR(50)  NOT NULL,
    OrderDate       DATE         NOT NULL,
    Quantity        INT          NOT NULL,
    UnitPrice       DECIMAL(18,2) NOT NULL,
    TotalAmount     DECIMAL(18,2) NOT NULL,
    Country         VARCHAR(100) NULL,
    CustomerCategory VARCHAR(50) NULL,
    LoadDate        DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_FactSales_OrderID
ON dbo.FactSales (OrderID);
GO

CREATE INDEX IX_FactSales_OrderDate
ON dbo.FactSales (OrderDate);
GO
