SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_PropertyGroupsForEntityType]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN SELECT		pg.RowStatus,
					pg.RowVersion,
					pg.Guid,
					pg.Name,
					e.Guid	 AS EntityTypeGuid,
					ll.Guid	 AS LanguageLabelGuid,
					pgl.Guid AS PropertyGroupLayoutGuid,
					pgl.Name AS PropertyGroupLayout,
					pg.IsHidden,
					pg.SortOrder,
					pg.IsCollapsable,
					pg.IsDefaultCollapsed,
					pg.IsDefaultCollapsed_Mobile,
					pg.ShowOnMobile,
					os.CanRead,
					os.CanWrite,
					ISNULL (   lt.Label,
							   N''
						   ) AS Label
	   FROM			SCore.EntityPropertyGroupsV	  AS pg
	   JOIN			SCore.LanguageLabelsV		  AS ll ON (ll.ID = pg.LanguageLabelID)
	   JOIN			SUserInterface.PropertyGroupLayouts pgl ON (pgl.ID = pg.PropertyGroupLayoutID)
	   LEFT JOIN	SCore.EntityTypesV			  AS e ON (pg.EntityTypeID = e.ID)
	   OUTER APPLY	SCore.ObjectSecurityForUser (	pg.Guid,
													@UserId
												) AS os
	   OUTER APPLY	SCore.ObjectLabelForUser (	 pg.LanguageLabelID,
												 @UserId
											 ) AS lt
	   WHERE		(ISNULL(e.Guid, '00000000-0000-0000-0000-000000000000') = @Guid)
				 OR (pg.ID	= -1);
GO