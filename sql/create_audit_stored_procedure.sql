CREATE PROCEDURE dbo.usp_InsertETLAuditLog
    @PipelineName VARCHAR(100),
    @ActivityName VARCHAR(100),
    @RunID VARCHAR(100),
    @Status VARCHAR(50),
    @RowsLoaded INT,
    @LoadStartTime DATETIME2 = NULL,
    @LoadEndTime DATETIME2 = NULL,
    @ErrorMessage VARCHAR(4000) = NULL
AS
BEGIN
    INSERT INTO dbo.ETLAuditLog (
        PipelineName,
        ActivityName,
        RunID,
        Status,
        RowsLoaded,
        LoadStartTime,
        LoadEndTime,
        ErrorMessage
    )
    VALUES (
        @PipelineName,
        @ActivityName,
        @RunID,
        @Status,
        @RowsLoaded,
        @LoadStartTime,
        @LoadEndTime,
        @ErrorMessage
    );
END;