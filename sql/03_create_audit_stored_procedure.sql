/*
Purpose:
    Create a stored procedure that inserts one audit record for an Azure Data
    Factory pipeline or activity run.

Usage:
    ADF can call this procedure after important pipeline steps to record the
    run id, status, row count, timestamps, and diagnostic note.
*/

CREATE OR ALTER PROCEDURE dbo.usp_InsertETLAuditLog
    @PipelineName   VARCHAR(200),
    @ActivityName   VARCHAR(200) = NULL,
    @RunID          VARCHAR(200) = NULL,
    @RunStatus      VARCHAR(50),
    @RowsLoaded     INT = NULL,
    @StartTime      DATETIME2(0) = NULL,
    @EndTime        DATETIME2(0) = NULL,
    @DiagnosticNote VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ETLAuditLog
    (
        PipelineName,
        ActivityName,
        RunID,
        RunStatus,
        RowsLoaded,
        StartTime,
        EndTime,
        DiagnosticNote
    )
    VALUES
    (
        @PipelineName,
        @ActivityName,
        @RunID,
        @RunStatus,
        @RowsLoaded,
        @StartTime,
        @EndTime,
        @DiagnosticNote
    );
END;
GO
