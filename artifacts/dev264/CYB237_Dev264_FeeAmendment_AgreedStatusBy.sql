/*
    CYB-237 (bugfix/SB_CYB-237-26.4-agreed-status-by): Agreed Status By is system-set and locked.
    - SJob.FeeAmendmentsUpsert: sets AgreedStatusByUserID to the saving user when the amendment is
      saved as Agreed, keeps it while it stays Agreed, clears it (-1) otherwise. (Dev264 == release/26.4
      source before this change.)
    - SJob.FeeAmendmentsValidate: AgreedStatusByUserId always read-only, no longer "Required".
      Built from the CURRENT Dev264 definition so Oliver's unmerged "legacy amendment" read-only block
      (feature/Oliver-CYB-336, 20dbff0b) is preserved.
    Run: sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev264 -E -C -b -i <this file>
*/
USE [CymBuild_Dev264];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [SJob].[FeeAmendmentsUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	@RibaStage0Change DECIMAL(9,2),
	@RibaStage1Change DECIMAL(9,2),
	@RibaStage2Change DECIMAL(9,2),
	@RibaStage3Change DECIMAL (9,2),
	@RibaStage4Change DECIMAL (9,2),
	@RibaStage5Change DECIMAL (9,2),
	@RibaStage6Change DECIMAL (9,2),
	@RibaStage7Change DECIMAL (9,2),

	 -- Visits
    @RibaStage0VisitChange DECIMAL(9,2),
	@RibaStage1VisitChange DECIMAL(9,2),
	@RibaStage2VisitChange DECIMAL(9,2),
	@RibaStage3VisitChange DECIMAL(9,2),
	@RibaStage4VisitChange DECIMAL(9,2),
	@RibaStage5VisitChange DECIMAL(9,2),
	@RibaStage6VisitChange DECIMAL(9,2),
	@RibaStage7VisitChange DECIMAL(9,2),

    -- Meetings
    @RibaStage0MeetingChange DECIMAL(9,2),
	@RibaStage1MeetingChange DECIMAL(9,2),
	@RibaStage2MeetingChange DECIMAL(9,2),
	@RibaStage3MeetingChange DECIMAL(9,2),
	@RibaStage4MeetingChange DECIMAL(9,2),
	@RibaStage5MeetingChange DECIMAL(9,2),
	@RibaStage6MeetingChange DECIMAL(9,2),
	@RibaStage7MeetingChange DECIMAL(9,2),

	@PreConstructionStageChange DECIMAL (9,2),
	@ConstructionStageChange DECIMAL (9,2),
	--Preconstruction + construction phases
	@PreConstructionStageMeetingChange DECIMAL(9,2),
	@PreConstructionStageVisitChange DECIMAL(9,2),
	@ConstructionStageMeetingChange DECIMAL(9,2),
	@ConstructionStageVisitChange DECIMAL(9,2),

	@FeeCapChange DECIMAL(9,2),
    @Guid UNIQUEIDENTIFIER,
	@Reason NVARCHAR(MAX),

	--[CYB-237]
	@DateReceivedRequest DATE,
	@DateAgreed				DATE,
	@OriginalAgreedFee		DECIMAL(9,2),
	@NewTotalAgreedFee		DECIMAL(9,2),
	@Comments				NVARCHAR(MAX),
	@RejectionReason		NVARCHAR(MAX),
	@FeeAmendmentStatusGuid UNIQUEIDENTIFIER,
	@SendToContactGuid		UNIQUEIDENTIFIER,
	@RequestedByUserGuid	UNIQUEIDENTIFIER,
	@AgreedStatusByUserGuid UNIQUEIDENTIFIER
)
AS 
BEGIN
    DECLARE @UserID INT,
            @JobID INT

    IF (@UserID IS NULL)
    BEGIN
        SELECT @UserID = CONVERT(INT, SESSION_CONTEXT(N'user_id'))
    END

    SELECT  @JobID = ID
    FROM    SJob.Jobs
    WHERE   ([Guid] = @JobGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,                    -- uniqueidentifier
                            @SchemeName = N'SJob',                -- nvarchar(255)
                            @ObjectName = N'FeeAmendment',                -- nvarchar(255)
                            @IsInsert = @IsInsert OUTPUT    -- bit


    DECLARE @FeeAmendmentStatusId    INT,
            @SendToContactId        INT,
            @RequestedByUserId        INT,
            @AgreedStatusByUserId    INT;


    SELECT @FeeAmendmentStatusId = ID
    FROM SJob.FeeAmendmentStatus
    WHERE Guid = @FeeAmendmentStatusGuid;

    SELECT @SendToContactId = ID
    FROM SCrm.AccountContacts
    WHERE Guid = @SendToContactGuid;

    SELECT @RequestedByUserId = ID
    FROM SCore.Identities
    WHERE Guid = @RequestedByUserGuid;

    SELECT @AgreedStatusByUserId = ID
    FROM SCore.Identities
    WHERE Guid = @AgreedStatusByUserGuid;

    --[CYB-237] New amendments must carry a real status. FeeAmendmentStatusID = -1 is reserved for
    --          amendments that pre-date this feature, which continue to count towards the agreed fee.
    IF (@FeeAmendmentStatusId IS NULL OR @FeeAmendmentStatusId = -1)
    BEGIN
        ;THROW 60000, N'A fee amendment status is required.', 1;
    END

    --[CYB-237] Agreed Status By is system-set and read-only in the UI: it records the user who saved
    --          the amendment as Agreed. It is kept while the amendment stays Agreed and cleared (-1)
    --          when the status moves away from Agreed; the value passed in is ignored.
    DECLARE @AgreedFeeAmendmentStatusGuid  UNIQUEIDENTIFIER = '215F258A-CF79-468F-9EB8-A84481F7F8AF',
            @ExistingStatusGuid            UNIQUEIDENTIFIER,
            @ExistingAgreedStatusByUserId  INT;

    SELECT  @ExistingStatusGuid           = fas.[Guid],
            @ExistingAgreedStatusByUserId = fa.AgreedStatusByUserID
    FROM    SJob.FeeAmendment AS fa
    JOIN    SJob.FeeAmendmentStatus AS fas ON (fas.ID = fa.FeeAmendmentStatusID)
    WHERE   (fa.[Guid] = @Guid);

    IF (@FeeAmendmentStatusGuid = @AgreedFeeAmendmentStatusGuid)
    BEGIN
        SET @AgreedStatusByUserId =
            CASE
                WHEN @ExistingStatusGuid = @AgreedFeeAmendmentStatusGuid
                     AND ISNULL(@ExistingAgreedStatusByUserId, -1) > 0 THEN @ExistingAgreedStatusByUserId
                ELSE ISNULL(@UserID, -1)
            END;
    END
    ELSE
    BEGIN
        SET @AgreedStatusByUserId = -1;
    END


    --[CYB-237] Calculate Original / New Total Agreed Fee server-side (ex. Fee Cap)
    DECLARE @FeeAmendmentID         BIGINT,
            @BaseAgreedFee          DECIMAL(19,2),
            @PriorAmendmentChange   DECIMAL(19,2),
            @ThisAmendmentChange    DECIMAL(19,2);

    -- NULL on insert: every existing amendment counts as "prior"
    SELECT  @FeeAmendmentID = fa.ID
    FROM    SJob.FeeAmendment AS fa
    WHERE   (fa.[Guid] = @Guid);

    -- Base fee: dynamic stage fees if present, otherwise legacy job columns (matches SJob.Job_FeeDrawdown)
    SELECT  @BaseAgreedFee =
            CASE
                WHEN dyn.DynamicTotal IS NOT NULL THEN dyn.DynamicTotal
                ELSE j.AgreedFee + j.PreConstructionStageFee + j.ConstructionStageFee
                   + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee
                   + j.RibaStage5Fee + j.RibaStage6Fee + j.RibaStage7Fee
            END
    FROM    SJob.Jobs AS j
    OUTER APPLY
    (
        SELECT  SUM(jrsf.AgreedFee) AS DynamicTotal
        FROM    SJob.JobRibaStageFees AS jrsf
        WHERE   (jrsf.JobID = j.ID)
            AND (jrsf.RowStatus NOT IN (0,254))
    ) AS dyn
    WHERE   (j.ID = @JobID);

    -- Changes from earlier active amendments that count towards the agreed fee
    -- (fixed columns + stage-keyed + custom). Counted statuses: -1 (pre-CYB-237 legacy, zero Guid) and Agreed.
    SELECT  @PriorAmendmentChange = SUM(x.FeeChange)
    FROM
    (
        SELECT  fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change
              + fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change
              + fa.PreConstructionStageChange + fa.ConstructionStageChange AS FeeChange
        FROM    SJob.FeeAmendment AS fa
        WHERE   (fa.JobID = @JobID)
            AND (fa.RowStatus NOT IN (0,254))
            AND (@FeeAmendmentID IS NULL OR fa.ID < @FeeAmendmentID)
            AND (fa.FeeAmendmentStatusID IN (SELECT fas.ID FROM SJob.FeeAmendmentStatus AS fas
                                             WHERE fas.[Guid] IN ('00000000-0000-0000-0000-000000000000',
                                                                  '215F258A-CF79-468F-9EB8-A84481F7F8AF')))

        UNION ALL

        SELECT  fars.FeeChange
        FROM    SJob.FeeAmendmentRibaStages AS fars
        WHERE   (fars.JobID = @JobID)
            AND (fars.RowStatus NOT IN (0,254))
            AND (@FeeAmendmentID IS NULL OR fars.FeeAmendmentID < @FeeAmendmentID)
            AND NOT EXISTS (SELECT 1
                            FROM   SJob.FeeAmendment AS pfa
                            WHERE  (pfa.ID = fars.FeeAmendmentID)
                               AND (pfa.FeeAmendmentStatusID NOT IN (SELECT fas.ID FROM SJob.FeeAmendmentStatus AS fas
                                                                     WHERE fas.[Guid] IN ('00000000-0000-0000-0000-000000000000',
                                                                                          '215F258A-CF79-468F-9EB8-A84481F7F8AF'))))

        UNION ALL

        SELECT  cfa.StageChange
        FROM    SJob.CustomFeeAmendment AS cfa
        WHERE   (cfa.JobID = @JobID)
            AND (cfa.RowStatus NOT IN (0,254))
            AND (@FeeAmendmentID IS NULL OR cfa.FeeAmendmentId < @FeeAmendmentID)
            AND NOT EXISTS (SELECT 1
                            FROM   SJob.FeeAmendment AS pfa
                            WHERE  (pfa.ID = cfa.FeeAmendmentId)
                               AND (pfa.FeeAmendmentStatusID NOT IN (SELECT fas.ID FROM SJob.FeeAmendmentStatus AS fas
                                                                     WHERE fas.[Guid] IN ('00000000-0000-0000-0000-000000000000',
                                                                                          '215F258A-CF79-468F-9EB8-A84481F7F8AF'))))
    ) AS x;

    -- This amendment's change: incoming parameters + its existing child rows (none on insert)
    SET @ThisAmendmentChange =
            @RibaStage0Change + @RibaStage1Change + @RibaStage2Change + @RibaStage3Change
          + @RibaStage4Change + @RibaStage5Change + @RibaStage6Change + @RibaStage7Change
          + @PreConstructionStageChange + @ConstructionStageChange
          + ISNULL((SELECT SUM(fars.FeeChange)
                    FROM   SJob.FeeAmendmentRibaStages AS fars
                    WHERE  (fars.FeeAmendmentID = @FeeAmendmentID)
                       AND (fars.RowStatus NOT IN (0,254))), 0)
          + ISNULL((SELECT SUM(cfa.StageChange)
                    FROM   SJob.CustomFeeAmendment AS cfa
                    WHERE  (cfa.FeeAmendmentId = @FeeAmendmentID)
                       AND (cfa.RowStatus NOT IN (0,254))), 0);

    SET @OriginalAgreedFee = ISNULL(@BaseAgreedFee, 0) + ISNULL(@PriorAmendmentChange, 0);
    SET @NewTotalAgreedFee = @OriginalAgreedFee + @ThisAmendmentChange;


    IF (@IsInsert = 1)
    BEGIN
        INSERT  SJob.FeeAmendment
        (
            RowStatus,
            [Guid],
            JobID,
            CreatedByUserID,
            CreatedDateTime,
            RibaStage0Change,
            RibaStage1Change,
            RibaStage2Change,
            RibaStage3Change,
            RibaStage4Change,
            RibaStage5Change,
            RibaStage6Change,
            RibaStage7Change,
            --VISITS
            RibaStage0VisitChange,
            RibaStage1VisitChange,
            RibaStage2VisitChange,
            RibaStage3VisitChange,
            RibaStage4VisitChange,
            RibaStage5VisitChange,
            RibaStage6VisitChange,
            RibaStage7VisitChange,
            --MEETINGS
            RibaStage0MeetingChange,
            RibaStage1MeetingChange,
            RibaStage2MeetingChange,
            RibaStage3MeetingChange,
            RibaStage4MeetingChange,
            RibaStage5MeetingChange,
            RibaStage6MeetingChange,
            RibaStage7MeetingChange,
            --PRECONSTRUCTIONS + CONSTRUCTIONS
            PreConstructionStageChange,
            ConstructionStageChange,
            PreConstructionStageMeetingChange,
            PreConstructionStageVisitChange,
            ConstructionStageMeetingChange,
            ConstructionStageVisitChange,
            FeeCapChange,
            Reason,
            DateReceivedRequest,
            DateAgreed,
            OriginalAgreedFee,
            NewTotalAgreedFee,
            Comments,
            RejectionReason,
            FeeAmendmentStatusID,
            SentToContactID,
            RequestedByUserID,
            AgreedStatusByUserID
        )
        VALUES
        (
            1,
            @Guid,
            @JobID,
            @UserID,
            GETUTCDATE(),
            @RibaStage0Change,
            @RibaStage1Change,
            @RibaStage2Change,
            @RibaStage3Change,
            @RibaStage4Change,
            @RibaStage5Change,
            @RibaStage6Change,
            @RibaStage7Change,
            --VISITS
            @RibaStage0VisitChange,
            @RibaStage1VisitChange,
            @RibaStage2VisitChange,
            @RibaStage3VisitChange,
            @RibaStage4VisitChange,
            @RibaStage5VisitChange,
            @RibaStage6VisitChange,
            @RibaStage7VisitChange,
            --MEETINGS
            @RibaStage0MeetingChange,
            @RibaStage1MeetingChange,
            @RibaStage2MeetingChange,
            @RibaStage3MeetingChange,
            @RibaStage4MeetingChange,
            @RibaStage5MeetingChange,
            @RibaStage6MeetingChange,
            @RibaStage7MeetingChange,

            @PreConstructionStageChange,
            @ConstructionStageChange,
            --Preconstruction + construction phases
            @PreConstructionStageMeetingChange,
            @PreConstructionStageVisitChange,
            @ConstructionStageMeetingChange,
            @ConstructionStageVisitChange,
            @FeeCapChange,
            @Reason,
            @DateReceivedRequest,
            @DateAgreed,
            @OriginalAgreedFee,
            @NewTotalAgreedFee,
            @Comments,
            @RejectionReason,
            @FeeAmendmentStatusID,
            @SendToContactId,
            @RequestedByUserID,
            @AgreedStatusByUserID

        )
    END
    ELSE
    BEGIN
        UPDATE  SJob.FeeAmendment
        SET     RowStatus                            = 1,
                JobID                                = @JobID,
                RibaStage0Change                    = @RibaStage0Change,
                RibaStage1Change                    = @RibaStage1Change,
                RibaStage2Change                    = @RibaStage2Change,
                RibaStage3Change                    = @RibaStage3Change,
                RibaStage4Change                    = @RibaStage4Change,
                RibaStage5Change                    = @RibaStage5Change,
                RibaStage6Change                    = @RibaStage6Change,
                RibaStage7Change                    = @RibaStage7Change,
                --VISIT
                RibaStage0VisitChange                = @RibaStage0VisitChange,
                RibaStage1VisitChange                = @RibaStage1VisitChange,
                RibaStage2VisitChange                = @RibaStage2VisitChange,
                RibaStage3VisitChange                = @RibaStage3VisitChange,
                RibaStage4VisitChange                = @RibaStage4VisitChange,
                RibaStage5VisitChange                = @RibaStage5VisitChange,
                RibaStage6VisitChange                = @RibaStage6VisitChange,
                RibaStage7VisitChange                = @RibaStage7VisitChange,
                --MEETINGS
                RibaStage0MeetingChange                = @RibaStage0MeetingChange,
                RibaStage1MeetingChange                = @RibaStage1MeetingChange,
                RibaStage2MeetingChange                = @RibaStage2MeetingChange,
                RibaStage3MeetingChange                = @RibaStage3MeetingChange,
                RibaStage4MeetingChange                = @RibaStage4MeetingChange,
                RibaStage5MeetingChange                = @RibaStage5MeetingChange,
                RibaStage6MeetingChange                = @RibaStage6MeetingChange,
                RibaStage7MeetingChange                = @RibaStage7MeetingChange,
                --Construction + preconstruction
                PreConstructionStageChange            = @PreConstructionStageChange,
                ConstructionStageChange                = @ConstructionStageChange,
                PreConstructionStageMeetingChange    = @PreConstructionStageMeetingChange,
                PreConstructionStageVisitChange        = @PreConstructionStageVisitChange,
                ConstructionStageMeetingChange        = @ConstructionStageMeetingChange,
                ConstructionStageVisitChange        = @ConstructionStageVisitChange,
                FeeCapChange = @FeeCapChange,
                Reason = @Reason,
                DateReceivedRequest                    = @DateReceivedRequest,
                DateAgreed                            = @DateAgreed,
                OriginalAgreedFee                    = @OriginalAgreedFee,
                NewTotalAgreedFee                    = @NewTotalAgreedFee,
                Comments                            = @Comments,
                RejectionReason                        = @RejectionReason,
                FeeAmendmentStatusID                = @FeeAmendmentStatusID,
                SentToContactID                        = @SendToContactId,
                RequestedByUserID                    = @RequestedByUserID,
                AgreedStatusByUserID                = @AgreedStatusByUserID
        WHERE   ([Guid] = @Guid)
    END
END
GO
CREATE OR ALTER FUNCTION [SJob].[FeeAmendmentsValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@JobGuid UNIQUEIDENTIFIER,
		@DateReceivedRequest DATE,
		@DateAgreed				DATE,
		@OriginalAgreedFee		DECIMAL(9,2),
		@NewTotalAgreedFee		DECIMAL(9,2),
		@Comments				NVARCHAR(MAX),
		@RejectionReason		NVARCHAR(MAX),
		@FeeAmendmentStatusGuid UNIQUEIDENTIFIER,
		@SendToContactGuid		UNIQUEIDENTIFIER,
		@RequestedByUserGuid	UNIQUEIDENTIFIER,
		@AgreedStatusByUserGuid UNIQUEIDENTIFIER
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN
	DECLARE @EntityHoBTGuid UNIQUEIDENTIFIER,
			@EntityPropertyGuid UNIQUEIDENTIFIER;




	--[CYB-237]
	--If rejected, require a reason.
	DECLARE @RejectedFeeAmendmentStatusGuid UNIQUEIDENTIFIER = '3D66CEDB-A2FB-48CF-BAA3-69B728F374DA';
	DECLARE @AcceptedFeeAmendmentStatusGuid UNIQUEIDENTIFIER = '215F258A-CF79-468F-9EB8-A84481F7F8AF';
	DECLARE @EmptyFeeAmendmentStatusGuid	UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';


	IF(@FeeAmendmentStatusGuid = @AcceptedFeeAmendmentStatusGuid)
		BEGIN

			IF(@DateAgreed IS NULL)
				BEGIN
			
					SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'DateAgreed')

					INSERT	@ValidationResult
						 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
					VALUES
						 (
							 @EntityPropertyGuid,
							 N'P',
							 0,
							 0,
							 1,
							 N'Required'
						 );
				END;

		END;

	--[CYB-237] Agreed Status By is system-set by SJob.FeeAmendmentsUpsert (the user who saves the
	--          amendment as Agreed), so it is never entered by hand and is not "Required" here.
	SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'AgreedStatusByUserId')

	INSERT	@ValidationResult
		 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
	VALUES
		 (
			 @EntityPropertyGuid,
			 N'P',
			 1,
			 0,
			 0,
			 N''
		 );


	IF(@FeeAmendmentStatusGuid = @RejectedFeeAmendmentStatusGuid)
		BEGIN
			SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RejectionReason')

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			VALUES
				 (
					 @EntityPropertyGuid,
					 N'P',
					 0,
					 0,
					 1,
					 N'Rejection reason required.'
				 );
		END;
	--Enfore a status selection
	ELSE IF(@FeeAmendmentStatusGuid = @EmptyFeeAmendmentStatusGuid )
		BEGIN
			SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'FeeAmendmentStatusId')

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			VALUES
				 (
					 @EntityPropertyGuid,
					 N'P',
					 0,
					 0,
					 1,
					 N'Status cannot be empty!'
				 );
		END;
	--If not rejected, disable rejection reason field.
	ELSE
		BEGIN
			SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RejectionReason')

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			VALUES
				 (
					 @EntityPropertyGuid,
					 N'P',
					 1,
					 0,
					 0,
					 N''
				 );
		END;




	IF (EXISTS 
			(
				SELECT	1
				FROM	SJob.Jobs 
				WHERE	(Guid = @JobGuid)
					AND	((PreConstructionStageFee <> 0) OR (ConstructionStageFee <> 0))
			)
		)
	BEGIN 
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage0Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage1Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage2Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage3Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage4Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage5Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage6Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage7Change')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		-- ========== RIBA STAGE MEETING  CHANGES =======
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage0MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage1MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage2MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage3MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage4MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage5MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage6MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage7MeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		-- ========== RIBA STAGE VISIT  CHANGES =======
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage0VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage1VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage2VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage3VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage4VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage5VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage6VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'RibaStage7VisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );


	END
	ELSE
	BEGIN 
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'PreConstructionStageChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'ConstructionStageChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

		-- ======== EXCLUDING RRE+CONSTRUCTION CHANGES
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'ConstructionStageMeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

			 
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'ConstructionStageVisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );


		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'PreConstructionStageMeetingChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

			 
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'FeeAmendment', N'PreConstructionStageVisitChange')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );

	END


		--Check if we are opening a legacy amendment 
	 IF (EXISTS
			  (
				  SELECT  1
				  FROM    SJob.FeeAmendment AS fa
				  WHERE   (fa.Guid = @Guid)
					  AND (fa.FeeAmendmentStatusID = -1)
			  )
		  )
	  BEGIN
		 INSERT @ValidationResult
						(
							TargetGuid,
							TargetType,
							IsReadOnly,
							IsHidden,
							IsInvalid,
							[Message]
						)
				SELECT
							epfvv.Guid,
							N'P',
							1,
							0,
							0,
							N''
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	([epfvv].[Schema] = N'SJob')
					AND	(epfvv.Hobt = N'FeeAmendment')
	  END;

	RETURN;
END;
GO
SELECT
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SJob.FeeAmendmentsUpsert')) LIKE N'%@AgreedFeeAmendmentStatusGuid%' THEN 'OK' ELSE 'CHECK' END AS UpsertUpdated,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SJob.FeeAmendmentsValidate')) LIKE N'%system-set by SJob.FeeAmendmentsUpsert%'
          AND OBJECT_DEFINITION(OBJECT_ID(N'SJob.FeeAmendmentsValidate')) LIKE N'%legacy amendment%' THEN 'OK' ELSE 'CHECK' END AS ValidateUpdatedAndLegacyBlockKept;
GO