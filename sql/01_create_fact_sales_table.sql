CREATE TABLE dbo.FactSales (
    FactSalesID BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderID VARCHAR(50) NOT NULL,
    CustomerID VARCHAR(50) NOT NULL,
    ProductID VARCHAR(50) NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    OrderDate DATE NOT NULL,
    Country VARCHAR(50),
    SalesChannel VARCHAR(50),
    TotalAmount DECIMAL(18,2),
    CustomerCategory VARCHAR(50),
    LoadDate DATETIME2
);