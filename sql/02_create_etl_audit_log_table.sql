/*
Purpose:
    Create the audit table used to track Azure Data Factory pipeline execution.

This table records pipeline name, activity name, run id, run status, row count,
start time, end time, and diagnostic notes for each ETL run.
*/

IF OBJECT_ID('dbo.ETLAuditLog', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.ETLAuditLog;
END;
GO

CREATE TABLE dbo.ETLAuditLog
(
    AuditID        INT IDENTITY(1,1) PRIMARY KEY,
    PipelineName   VARCHAR(200) NOT NULL,
    ActivityName   VARCHAR(200) NULL,
    RunID          VARCHAR(200) NULL,
    RunStatus      VARCHAR(50)  NOT NULL,
    RowsLoaded     INT          NULL,
    StartTime      DATETIME2(0) NULL,
    EndTime        DATETIME2(0) NULL,
    DiagnosticNote VARCHAR(MAX) NULL,
    CreatedAt      DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_ETLAuditLog_PipelineName_CreatedAt
ON dbo.ETLAuditLog (PipelineName, CreatedAt DESC);
GO

CREATE INDEX IX_ETLAuditLog_RunStatus
ON dbo.ETLAuditLog (RunStatus);
GO
