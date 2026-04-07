SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_ActionMenuItemsForEntityType]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
AS
RETURN SELECT		ami.RowStatus,
					ami.RowVersion,
					ami.Guid,
					ISNULL(lt.Label, N'') Label,
					ami.IconCss,
					ami.Type,
					ami.SortOrder,
					e.Guid AS EntityTypeGuid,
					eq.Guid AS EntityQueryGuid,
					ami.RedirectToTargetGuid
	   FROM			SUserInterface.ActionMenuItems					AS ami
	   JOIN			SCore.EntityTypesV						AS e ON (ami.EntityTypeID = e.ID)
	   JOIN			SCore.EntityQueriesV						AS eq ON (ami.EntityQueryID = eq.ID)
	   OUTER APPLY	SCore.ObjectLabelForUser (	 ami.LanguageLabelId,
												 @UserId
											 ) AS lt
	   WHERE		(e.Guid = @Guid)
				AND	(ami.RowStatus NOT IN (0, 254))
				AND	(EXISTS
							(
									SELECT
											1
									FROM
											SCore.ObjectSecurityForUser_CanRead(ami.Guid, @UserId) oscr
							)
						)
GO