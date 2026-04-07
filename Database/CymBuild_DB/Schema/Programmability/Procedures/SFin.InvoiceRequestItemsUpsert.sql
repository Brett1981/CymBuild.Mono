SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SFin].[InvoiceRequestItemsUpsert]')
GO
CREATE PROCEDURE [SFin].[InvoiceRequestItemsUpsert]
(
      @InvoiceRequestGuid UNIQUEIDENTIFIER
    , @MilestoneGuid      UNIQUEIDENTIFIER
    , @ActivityGuid       UNIQUEIDENTIFIER
    , @Net                DECIMAL(19,2)
    , @Guid               UNIQUEIDENTIFIER
    , @ShortDescription   NVARCHAR(200)
	, @RIBAStageGuid	  UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
          @InvoiceRequestID INT
        , @MilestoneId      BIGINT = -1
        , @ActivityId       BIGINT = -1
        , @DataObjectWasInserted BIT
		, @RIBAStageId		INT;

    -- Null safety
    SET @ShortDescription = ISNULL(@ShortDescription, N'');
    SET @Net = ISNULL(@Net, 0);


	--Get RIBA Stage
	SELECT @RIBAStageId = ID
	FROM SJob.RibaStages 
	WHERE ([Guid] = @RIBAStageGuid);

    -- Resolve InvoiceRequest
    SELECT @InvoiceRequestID = ID
    FROM SFin.InvoiceRequests
    WHERE [Guid] = @InvoiceRequestGuid
      AND RowStatus NOT IN (0,254);

    IF (@InvoiceRequestID IS NULL)
        THROW 60000, N'InvoiceRequestItemsUpsert: InvoiceRequestGuid not found.', 1;

    -- Milestone only if supplied (and not empty-guid)
    IF (@MilestoneGuid IS NOT NULL AND @MilestoneGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        SELECT @MilestoneId = ID
        FROM SJob.Milestones
        WHERE [Guid] = @MilestoneGuid
          AND RowStatus NOT IN (0,254);

        IF (@MilestoneId IS NULL)
            THROW 60000, N'InvoiceRequestItemsUpsert: MilestoneGuid not found.', 1;
    END

    -- Activity only if supplied (and not empty-guid)
    IF (@ActivityGuid IS NOT NULL AND @ActivityGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        SELECT @ActivityId = ID
        FROM SJob.Activities
        WHERE [Guid] = @ActivityGuid
          AND RowStatus NOT IN (0,254);

        IF (@ActivityId IS NULL)
            THROW 60000, N'InvoiceRequestItemsUpsert: ActivityGuid not found.', 1;
    END

    -- Ensure DataObject exists
    EXEC SCore.UpsertDataObject
          @Guid = @Guid
        , @SchemeName = N'SFin'
        , @ObjectName = N'InvoiceRequestItems'
        , @IncludeDefaultSecurity = 0
        , @IsInsert = @DataObjectWasInserted OUTPUT;

    -- Decide insert/update based on SFin.InvoiceRequestItems
    IF NOT EXISTS (SELECT 1 FROM SFin.InvoiceRequestItems WITH (UPDLOCK, HOLDLOCK) WHERE [Guid] = @Guid)
    BEGIN
        INSERT SFin.InvoiceRequestItems
            (RowStatus, Guid, InvoiceRequestId, MilestoneId, ActivityId, Net, ShortDescription, RIBAStageId)
        VALUES
            (1, @Guid, @InvoiceRequestID, @MilestoneId, @ActivityId, @Net, @ShortDescription, @RIBAStageId);
    END
    ELSE
    BEGIN
        UPDATE iri
        SET
              iri.InvoiceRequestId  = @InvoiceRequestID
            , iri.MilestoneId      = @MilestoneId
            , iri.ActivityId       = @ActivityId
            , iri.Net              = @Net
            , iri.ShortDescription = @ShortDescription
			, iri.RIBAStageId	   = @RIBAStageId
        FROM SFin.InvoiceRequestItems iri
        WHERE iri.[Guid] = @Guid;
    END
END
GO