SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[Assistant_CreateDataObject]')
GO

/* =========================================================================================
       7. Helper procedures to create DataObjects-backed rows for SAi entities
          These are foundational and can be reused by later CRUD/upsert procedures.
    ========================================================================================= */
CREATE PROCEDURE [SAi].[Assistant_CreateDataObject] (
	@Guid UNIQUEIDENTIFIER
	,@EntityTypeId INT
	,@RowStatus TINYINT = 1
	)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @ExistingEntityTypeId INT;

	SELECT @ExistingEntityTypeId = d.EntityTypeId
	FROM SCore.DataObjects AS d
	WHERE d.Guid = @Guid;

	IF @ExistingEntityTypeId IS NOT NULL
	BEGIN
		IF @ExistingEntityTypeId <> @EntityTypeId
		BEGIN
				;

			THROW 60010
				,N'Existing SCore.DataObjects row has a different EntityTypeId.'
				,1;
		END;

		RETURN;
	END;

	INSERT INTO SCore.DataObjects (
		Guid
		,RowStatus
		,EntityTypeId
		)
	VALUES (
		@Guid
		,@RowStatus
		,@EntityTypeId
		);
END;
GO