SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequestItemsUpsert]')
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
		  @UserId					INT
        , @InvoiceRequestID			INT
        , @MilestoneId				BIGINT = -1
        , @ActivityId				BIGINT = -1
        , @DataObjectWasInserted	BIT
		, @RIBAStageId				INT;

    -- Null safety
    SET @ShortDescription = ISNULL(@ShortDescription, N'');
    SET @Net = ISNULL(@Net, 0);

	SET @UserId = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

	--Get RIBA Stage
	SELECT @RIBAStageId = ID
    FROM SJob.RibaStages
    WHERE [Guid] = @RIBAStageGuid
      AND RowStatus NOT IN (0,254);

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

		DECLARE 
				@ActivityValue					DECIMAL(19,2),
				@ActivityQuantity				INT,
				@ActivityAssigneeGuid			UNIQUEIDENTIFIER,
				@InvoiceRequestAssignee			UNIQUEIDENTIFIER,
				
				@RIBASetOnActivityId			INT,
				@JobIdForActivity				INT;
				

        SELECT 
			@ActivityId				= root_hobt.ID,
			@ActivityValue			= InvoicingValue,
			@ActivityQuantity		= InvoicingQuantity,
			@ActivityAssigneeGuid	= I.Guid,
			@RIBASetOnActivityId	= root_hobt.RibaStageId,
			@JobIdForActivity		= root_hobt.JobID
        FROM SJob.Activities AS root_hobt
		JOIN SCore.Identities as I ON (I.ID = SurveyorID)
        WHERE root_hobt.Guid = @ActivityGuid
          AND root_hobt.RowStatus NOT IN (0,254);


		--Ensures we do not try to multiply by 0 (in case user error when inputing figures)
		IF(@ActivityValue > 0.0 AND @ActivityQuantity = 0)
		SET @ActivityQuantity = 1;

		--Assign the value of the activity here
		IF(@ActivityValue > 0.0)
			SET @Net = @ActivityValue * @ActivityQuantity;

		--Ensure that the consultant is the same as on the activity (CYB-291)
		SELECT @InvoiceRequestAssignee = I.Guid
		FROM SFin.InvoiceRequests AS root_hobt
		JOIN SCore.Identities AS I ON (I.ID = root_hobt.RequesterUserId)
		WHERE root_hobt.Guid = @InvoiceRequestGuid

		IF(@InvoiceRequestAssignee <> @ActivityAssigneeGuid)
		BEGIN
				
			DECLARE @ActivityAssigneeId INT;

			SELECT @ActivityAssigneeId = ID
			FROM SCore.Identities
			WHERE Guid = @ActivityAssigneeGuid;

			UPDATE SFin.InvoiceRequests
			SET RequesterUserId = @ActivityAssigneeId 
			WHERE Guid = @InvoiceRequestGuid;

		END;

		--Get the remaining fee for the RIBA stage (If set on the activity)
		IF(ISNULL(@RIBASetOnActivityId, -1) <> -1)
		BEGIN
			DECLARE 
					@JobGuidForActivity			UNIQUEIDENTIFIER,
					@RIBAStageLabel			NVARCHAR(100),
					@RemainingStageValue	DECIMAL(19,2);

			--Get the job GUID.
			SELECT 
					@JobGuidForActivity = root_hobt.Guid
			FROM SJob.Jobs AS root_hobt
			WHERE root_hobt.ID = @JobIdForActivity;

			

			--Get the RIBA stage label.
			SELECT 
				@RIBAStageLabel  = Description
			FROM SJob.RibaStages
			WHERE ID = @RIBASetOnActivityId;

			
			--Get the remaining value for the stage from SJob.tvf_JobFeeDrawdown.
			SELECT @RemainingStageValue = root_hobt.Remaining
			FROM SJob.Job_FeeDrawdown   AS root_hobt
			JOIN SJob.Jobs AS j ON (j.ID = root_hobt.JobId)
			WHERE 
					(j.Guid = @JobGuidForActivity)
				AND (root_hobt.StageLabel = @RIBAStageLabel)

			--DECLARE @M NVARCHAR(MAX)
			--SET @M = N'@Remaining => ' + CONVERT(NVARCHAR(50), @UserId);

			--THROW 60001, @M, 1;



			--Throw an error message.
			IF(ISNULL(@RemainingStageValue, 0) < @Net)
				BEGIN

					DECLARE @ErrorMessage1 NVARCHAR(4000);

					IF (ISNULL(@RemainingStageValue, 0) <= 0)
                    BEGIN
                        SET @ErrorMessage1 =
                            N'Cannot specify invoice item because there is no remaining fee available for RIBA stage "'
                            + ISNULL(@RIBAStageLabel, N'Unknown')
                            + N'". The invoice item is £'
                            + CONVERT(NVARCHAR(50), @Net)
                            + N'.';
                    END
                    ELSE
                    BEGIN
                        SET @ErrorMessage1 =
                            N'Cannot specify invoice item because only £'
                            + CONVERT(NVARCHAR(50), ISNULL(@RemainingStageValue, 0))
                            + N' remains for RIBA stage "'
                            + ISNULL(@RIBAStageLabel, N'Unknown')
                            + N'", but the invoice item is £'
                            + CONVERT(NVARCHAR(50), @Net)
                            + N'.';
                    END;

					THROW 51003, @ErrorMessage1, 1;
				END;		
		END;

        IF (@ActivityId IS NULL)
            THROW 60000, N'InvoiceRequestItemsUpsert: ActivityGuid not found.', 1;
    END


	 DECLARE
              @JobGuidForRequest     UNIQUEIDENTIFIER
            , @RIBAStageLabelDirect  NVARCHAR(100)
            , @RemainingStageValueDirect DECIMAL(19,2);


	/* Direct RIBA-stage validation.
   This covers Invoice Request Items where the user selects a RIBA stage
   without selecting an Activity. Existing activity behaviour remains unchanged. */
    IF (
           @RIBAStageGuid IS NOT NULL
       AND @RIBAStageGuid <> '00000000-0000-0000-0000-000000000000'
       AND (
               @ActivityGuid IS NULL
            OR @ActivityGuid = '00000000-0000-0000-0000-000000000000'
           )
    )
    BEGIN
       

        SELECT
            @JobGuidForRequest = j.Guid
        FROM SFin.InvoiceRequests AS ir
        INNER JOIN SJob.Jobs AS j
            ON j.ID = ir.JobId
           AND j.RowStatus NOT IN (0,254)
        WHERE ir.ID = @InvoiceRequestID
          AND ir.RowStatus NOT IN (0,254);

        IF (@JobGuidForRequest IS NULL)
            THROW 51001, N'Cannot validate RIBA stage fee because the Invoice Request job could not be resolved.', 1;

        SELECT
            @RIBAStageId = rs.ID,
            @RIBAStageLabelDirect = rs.Description
        FROM SJob.RibaStages AS rs
        WHERE rs.Guid = @RIBAStageGuid
          AND rs.RowStatus NOT IN (0,254);

        IF (@RIBAStageId IS NULL)
            THROW 51002, N'Cannot save Invoice Request Item because the selected RIBA stage could not be found.', 1;

        SELECT
            @RemainingStageValueDirect = fd.Remaining
        FROM SJob.Job_FeeDrawdown AS fd
        INNER JOIN SJob.Jobs AS j
            ON j.ID = fd.JobId
           AND j.RowStatus NOT IN (0,254)
        WHERE j.Guid = @JobGuidForRequest
          AND fd.StageLabel = @RIBAStageLabelDirect;

        SET @RemainingStageValueDirect = ISNULL(@RemainingStageValueDirect, 0);

        IF (@Net > @RemainingStageValueDirect)
        BEGIN
            DECLARE @ErrorMessageDirect NVARCHAR(4000);

            IF (ISNULL(@RemainingStageValueDirect, 0) <= 0)
            BEGIN
                SET @ErrorMessageDirect =
                    N'Cannot save this invoice item because there is no remaining fee available for RIBA stage "'
                    + ISNULL(@RIBAStageLabelDirect, N'Unknown')
                    + N'". The invoice item is £'
                    + CONVERT(NVARCHAR(50), @Net)
                    + N'.';
            END
            ELSE
            BEGIN
                SET @ErrorMessageDirect =
                    N'Cannot save this invoice item because only £'
                    + CONVERT(NVARCHAR(50), @RemainingStageValueDirect)
                    + N' remains for RIBA stage "'
                    + ISNULL(@RIBAStageLabelDirect, N'Unknown')
                    + N'", but the invoice item is £'
                    + CONVERT(NVARCHAR(50), @Net)
                    + N'.';
            END;

            THROW 51003, @ErrorMessageDirect, 1;
        END;
    END
	ELSE
		BEGIN

		SELECT
            @JobGuidForRequest = j.Guid
        FROM SFin.InvoiceRequests AS ir
        INNER JOIN SJob.Jobs AS j
            ON j.ID = ir.JobId
           AND j.RowStatus NOT IN (0,254)
        WHERE ir.ID = @InvoiceRequestID
          AND ir.RowStatus NOT IN (0,254);

		SELECT
            @RemainingStageValueDirect = fd.Remaining
        FROM SJob.Job_FeeDrawdown AS fd
        INNER JOIN SJob.Jobs AS j
            ON j.ID = fd.JobId
           AND j.RowStatus NOT IN (0,254)
        WHERE 
				(j.Guid = @JobGuidForRequest)
			AND (fd.StageLabel = N'Total (inc. Fee Cap)')
         

        SET @RemainingStageValueDirect = ISNULL(@RemainingStageValueDirect, 0);

		 IF (@Net > @RemainingStageValueDirect)
			BEGIN
           

                SET @ErrorMessageDirect =
                    N'Cannot save this invoice item because only the total of £'
                    + CONVERT(NVARCHAR(50), @RemainingStageValueDirect)
                    + N' remains'
                    + N',but the invoice item is £'
                    + CONVERT(NVARCHAR(50), @Net)
                    + N'.';

				THROW 51003, @ErrorMessageDirect, 1;
            END;

		END;

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