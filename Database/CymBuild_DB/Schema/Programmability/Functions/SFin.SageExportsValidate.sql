SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SFin].[SageExportsValidate]
	(
		@Guid UNIQUEIDENTIFIER
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
	DECLARE @EntityHoBTGuid UNIQUEIDENTIFIER

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SFin.SageExports	  AS s
		 WHERE	(s.Guid = @Guid)
			AND	(s.RowStatus <> 0)
	 )
	   )
	
	BEGIN
		SELECT	@EntityHoBTGuid = eh.Guid
		FROM	SCore.EntityHobtsV AS eh
		WHERE	(eh.SchemaName = N'SFin')
			AND (eh.ObjectName = N'SageExports');

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

	
	RETURN;
END;

GO