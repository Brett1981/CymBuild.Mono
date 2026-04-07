SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[ActivitiesValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@ActivityStatusGuid UNIQUEIDENTIFIER,
		@Start DATETIME2, 
		@End DATETIME2,
		@InvoicingValue decimal(19,2),
		@InvoicingQuantity decimal (19,2),
		@JobGuid	UNIQUEIDENTIFIER,
		@NewExpiryDate DATETIME2,
		@ActivityTypeGuid UNIQUEIDENTIFIER
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

	
	DECLARE @F10UpdatedActivityType UNIQUEIDENTIFIER;

	
	SELECT @F10UpdatedActivityType = Guid 
	FROM SJob.ActivityTypes
	WHERE Name = N'F10 Updated/Reissued'


	

	IF (@ActivityTypeGuid <> @F10UpdatedActivityType)
		BEGIN
			-- Hide only the "NewExpiryDate" field
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   1,
				   0,
				   0,
				   N''
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'Activities'
			  AND epfvv.Name     = N'NewExpiryDate';
		END

	 IF(@ActivityTypeGuid = @F10UpdatedActivityType AND @NewExpiryDate IS NULL)
		BEGIN
			 --Hide everything except the "NewExpiryDate" field
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   0,
				   0,
				   1,
				   N'Must specify new expiry date!'
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'Activities'
			  AND epfvv.Name     = N'NewExpiryDate';
		END
	 



	/*
		Make the activity read only if the activity of the job is complete. 
	*/
	IF((EXISTS 
			(
				SELECT	1
				FROM	SJob.Activities a
				WHERE	(EXISTS 
							(
								SELECT	1 
								FROM	SJob.Jobs AS j
								WHERE	(j.IsComplete = 1)
									AND	(j.ID = a.JobID)
							)
						)
					AND	(a.Guid = @Guid)
			)
		)
		--This block ensures that the record is only locked down once the user has saved it.
		OR EXISTS
			(
				SELECT 1 
				FROM SJob.Activities as a
				JOIN SJob.ActivityStatus AS acts ON (a.ActivityStatusID = acts.ID)
				WHERE 
					(a.Guid = @Guid)
					AND (
							(acts.Guid = 'C20DA283-05BE-4BC1-ABD1-D62126DC5F80')	-- Completed
							OR (acts.Guid = '70853C10-745D-4ABB-88D3-B4E9AB990CA0') -- Cancelled
						) 
			)
		)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SJob.Activities 
				WHERE	(guid = @Guid)
					AND	(RowStatus <> 0)
			)
		)
	BEGIN
		SELECT	@EntityHoBTGuid = eh.Guid
		FROM	SCore.EntityHobtsV AS eh
		WHERE	(eh.SchemaName = N'SJob')
			AND (eh.ObjectName = N'Activities');

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityHoBTGuid,
				 N'H',
				 1,
				 0,
				 0,
				 N''
			 );
	END;

	/*
		The End must be greater than the Start
	*/
	IF (@End < @Start)
	BEGIN 
		SELECT	@EntityPropertyGuid = ep.Guid
		FROM	SCore.EntityPropertiesV ep
		JOIN	SCore.EntityHobtsV eh ON (eh.ID = ep.EntityHoBTID)
		WHERE	(eh.SchemaName = N'SJob')
			AND (eh.ObjectName = N'Activities')
			AND	(ep.Name	 = N'Date')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 0,
				 1,
				 N'The Start Date/Time must be before the End Date/Time.'
			 );

		SELECT	@EntityPropertyGuid = ep.Guid
		FROM	SCore.EntityPropertiesV ep
		JOIN	SCore.EntityHobtsV eh ON (eh.ID = ep.EntityHoBTID)
		WHERE	(eh.SchemaName = N'SJob')
			AND (eh.ObjectName = N'Activities')
			AND	(ep.Name	 = N'EndDate')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 0,
				 1,
				 N'The End Date/Time must be after the Start Date/Time.'
			 );
	END

	IF (@InvoicingValue > 0) 
	BEGIN 
		SELECT
				@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'Activities', N'InvoicingQuantity')

		INSERT @ValidationResult
				(
					TargetGuid,
					TargetType,
					IsReadOnly,
					IsHidden,
					IsInvalid,
					Message
				)
		VALUES
				(
					@EntityPropertyGuid,
					N'P',
					1,
					0,
					0,
					N''
				);
	END

	IF (@InvoicingQuantity > 0)
 
	BEGIN 
		SELECT
				@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'Activities', N'InvoicingValue')

		INSERT @ValidationResult
				(
					TargetGuid,
					TargetType,
					IsReadOnly,
					IsHidden,
					IsInvalid,
					Message
				)
		VALUES
				(
					@EntityPropertyGuid,
					N'P',
					1,
					0,
					0,
					N''
				);
	END

	/*
		Hide timesheet items when UseTimeSheet is false
	*/
	IF (
		SELECT	jt.UseTimeSheets 
		FROM	SJob.JobTypes jt
		JOIN	SJob.Jobs j ON (j.JobTypeID = jt.ID)
		WHERE	(j.Guid = @JobGuid)
	) = 0
	BEGIN 
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'Activities', N'InvoicingQuantity')

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

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'Activities', N'InvoicingValue')

		INSERT @ValidationResult
				(
					TargetGuid,
					TargetType,
					IsReadOnly,
					IsHidden,
					IsInvalid,
					Message
				)
		VALUES
				(
					@EntityPropertyGuid,
					N'P',
					0,
					1,
					0,
					N''
				);

		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'Activities', N'IsAdditionalWork')

		INSERT @ValidationResult
				(
					TargetGuid,
					TargetType,
					IsReadOnly,
					IsHidden,
					IsInvalid,
					Message
				)
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