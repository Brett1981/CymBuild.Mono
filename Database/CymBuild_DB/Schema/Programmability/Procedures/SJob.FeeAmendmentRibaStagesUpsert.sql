SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[FeeAmendmentRibaStagesUpsert]')
GO
CREATE PROCEDURE [SJob].[FeeAmendmentRibaStagesUpsert]
(
    @FeeAmendmentGuid UNIQUEIDENTIFIER,
    @JobGuid UNIQUEIDENTIFIER,
    @RibaStageGuid UNIQUEIDENTIFIER,
    @FeeChange DECIMAL(19,2),
    @MeetingChange DECIMAL(19,2),
    @VisitChange DECIMAL(19,2),
    @Guid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsInsert BIT;
    DECLARE @FeeAmendmentID BIGINT;
    DECLARE @JobID INT;
    DECLARE @RibaStageID INT;

    SELECT @FeeAmendmentID = ID
    FROM SJob.FeeAmendment
    WHERE Guid = @FeeAmendmentGuid
      AND RowStatus NOT IN (0,254);

    SELECT @JobID = ID
    FROM SJob.Jobs
    WHERE Guid = @JobGuid
      AND RowStatus NOT IN (0,254);

    SELECT @RibaStageID = ID
    FROM SJob.RibaStages
    WHERE Guid = @RibaStageGuid
      AND RowStatus NOT IN (0,254);

    IF @FeeAmendmentID IS NULL OR @JobID IS NULL OR @RibaStageID IS NULL
        THROW 60000, N'Cannot save FeeAmendmentRibaStages because parent/job/stage could not be resolved.', 1;

    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SJob',
        @ObjectName = N'FeeAmendmentRibaStages',
        @IsInsert = @IsInsert OUTPUT;

    IF @IsInsert = 1
    BEGIN
        INSERT INTO SJob.FeeAmendmentRibaStages
        (
            RowStatus, Guid, FeeAmendmentID, JobID, RibaStageID,
            FeeChange, MeetingChange, VisitChange
        )
        VALUES
        (
            1, @Guid, @FeeAmendmentID, @JobID, @RibaStageID,
            @FeeChange, @MeetingChange, @VisitChange
        );
    END
    ELSE
    BEGIN
        UPDATE SJob.FeeAmendmentRibaStages
        SET
            RowStatus = 1,
            FeeAmendmentID = @FeeAmendmentID,
            JobID = @JobID,
            RibaStageID = @RibaStageID,
            FeeChange = @FeeChange,
            MeetingChange = @MeetingChange,
            VisitChange = @VisitChange
        WHERE Guid = @Guid;
    END
END;
GO