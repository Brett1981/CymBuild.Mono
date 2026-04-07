SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_JobTypeGet]
	(
		@Guid NVARCHAR(100)
	)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN SELECT jt.[ID]
      ,jt.[RowStatus]
      ,jt.[RowVersion]
      ,jt.[Guid]
      ,jt.[Name]
      ,jt.[IsActive]
      ,jt.[SequenceID]
      ,jt.[UseTimeSheets]
      ,jt.[UsePlanChecks]
      ,ou.Guid AS [OrganisationalUnitGuid]
  FROM [SJob].[JobTypes] jt
  LEFT JOIN [SCore].OrganisationalUnits ou
	ON ou.ID = jt.OrganisationalUnitID
  where jt.Guid = @Guid
GO