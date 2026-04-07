SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[FeeAmendmentsValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@JobGuid UNIQUEIDENTIFIER
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
			@EntityPropertyGuid UNIQUEIDENTIFIER

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


	RETURN;
END;

GO