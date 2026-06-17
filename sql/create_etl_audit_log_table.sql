CREATE TABLE dbo.ETLAuditLog (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    PipelineName VARCHAR(100),
    ActivityName VARCHAR(100),
    RunID VARCHAR(100),
    Status VARCHAR(50),
    RowsLoaded INT,
    LoadStartTime DATETIME2 NULL,
    LoadEndTime DATETIME2 NULL,
    ErrorMessage VARCHAR(4000) NULL,
    CreatedAt DATETIME2 DEFAULT SYSDATETIME()
);