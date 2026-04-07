SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_GetWorkflowStatuses]
(
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS @WorkflowStatus TABLE
(
	Name NVARCHAR(50),
	Guid UNIQUEIDENTIFIER,
	RowStatus TINYINT
)
AS 
BEGIN

   
	DECLARE @EntityTypeGuid	UNIQUEIDENTIFIER;
	
	--Get the three main entity types.
	DECLARE @IsEnquiry UNIQUEIDENTIFIER = '3B4F2DF9-B6CF-4A49-9EED-2206473867A1';
	DECLARE @IsQuote   UNIQUEIDENTIFIER = '1C4794C1-F956-4C32-B886-5500AC778A56';
	DECLARE @IsJob     UNIQUEIDENTIFIER = '63542427-46AB-4078-ABD1-1D583C24315C';

	--Used for comparison.
	SELECT @IsEnquiry	= Guid FROM SCore.EntityTypes WHERE Name = N'Enquiries';
	SELECT @IsQuote		= Guid FROM SCore.EntityTypes WHERE Name = N'Quotes';
	SELECT @IsJob		= Guid FROM SCore.EntityTypes WHERE Name = N'Jobs';


	--Get the currently processed entity type.
	SELECT 
		@EntityTypeGuid = et.Guid
	FROM SCore.Workflow as root_hobt
	JOIN SCore.EntityTypes AS et ON (et.ID = root_hobt.EntityTypeID)
	WHERE root_hobt.Guid = @ParentGuid


	IF(@EntityTypeGuid = @IsEnquiry)
		INSERT INTO @WorkflowStatus
			SELECT 
				wfs.Name,
				wfs.Guid,
				wfs.RowStatus
			FROM SCore.WorkflowStatus AS wfs
			WHERE 
				(wfs.ShowInEnquiries = 1)

	ELSE IF (@EntityTypeGuid = @IsQuote)
		INSERT INTO @WorkflowStatus
			SELECT 
				wfs.Name,
				wfs.Guid,
				wfs.RowStatus
			FROM SCore.WorkflowStatus AS wfs
			WHERE (wfs.ShowInQuotes = 1)

	ELSE IF (@EntityTypeGuid = @IsJob)
		INSERT INTO @WorkflowStatus
			SELECT 
				wfs.Name,
				wfs.Guid,
				wfs.RowStatus
			FROM SCore.WorkflowStatus AS wfs
			WHERE (wfs.ShowInJobs = 1)
	
	
		RETURN;
END;

GO