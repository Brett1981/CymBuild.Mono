SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[CriticalProjectNotesUpsert]')
GO

CREATE PROCEDURE [SSop].[CriticalProjectNotesUpsert]
	(
		@Guid						UNIQUEIDENTIFIER,
		@Note						NVARCHAR(MAX),
		@CreatedByGuid				UNIQUEIDENTIFIER,
		@ParentGuid					UNIQUEIDENTIFIER
	)
AS
	BEGIN
	
		
		DECLARE @ProjectId			INT,
				@ParentEntityTypeId INT,
				@CreatedById		INT;


		DECLARE 
				@EnquiryEntityType	INT = 83,
				@QuoteEntityType	INT = 55,
				@JobEntityType		INT = 9;


		--Get user ID.
		SELECT @CreatedById = ID
		FROM SCore.Identities 
		WHERE Guid = @CreatedByGuid

		
		--Get the entity type.
		SELECT @ParentEntityTypeId = EntityTypeId
		FROM SCore.DataObjects
		WHERE Guid = @ParentGuid

		--Enquiry
		IF(@ParentEntityTypeId = @EnquiryEntityType)
			BEGIN

				SELECT @ProjectId = root_hobt.ProjectId
				FROM SSop.Enquiries root_hobt
				WHERE root_hobt.Guid = @ParentGuid;

			END;
		--Quote
		ELSE IF(@ParentEntityTypeId = @QuoteEntityType)
			BEGIN

				SELECT @ProjectId = root_hobt.ProjectId
				FROM SSop.Quotes root_hobt
				WHERE root_hobt.Guid = @ParentGuid;

			END;
		--Job
		ELSE IF(@ParentEntityTypeId = @JobEntityType)
			BEGIN

				SELECT @ProjectId = root_hobt.ProjectId
				FROM SJob.Jobs root_hobt
				WHERE root_hobt.Guid = @ParentGuid;
			END;



	
		DECLARE @IsInsert BIT
		EXEC SCore.UpsertDataObject
			@Guid		= @Guid,					
			@SchemeName = N'SSop',						
			@ObjectName = N'CriticalProjectNotes',				
			@IsInsert   = @IsInsert OUTPUT	-- bit



		IF (@IsInsert = 1)
			BEGIN
				INSERT SSop.CriticalProjectNotes
						(
							RowStatus,
							Guid,
							Note,
							CreatedBy,
							ParentGuid,
							ProjectId
						)
				VALUES
						(
							1,	-- RowStatus - tinyint
							@Guid,	-- Guid - uniqueidentifier
							@Note,
							@CreatedById,
							@ParentGuid,
							@ProjectId
						)
			END
		ELSE
			BEGIN
				UPDATE SSop.CriticalProjectNotes
				SET		
					Note = @Note
				WHERE
					([Guid] = @Guid)
			END
	END
GO