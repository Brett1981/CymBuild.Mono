SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[OrganisationalUnit_RetreeDescendants]
(
	@ParentID int,
	@NewParentOrgNode HIERARCHYID,
	@OldParentOrgNode HIERARCHYID 
)
AS
BEGIN 
	
	DECLARE	@Children TABLE (
		ID int, 
		OldOrgNode HIERARCHYID,
		NewOrgNode HIERARCHYID null 
	)

	INSERT	@Children (id, OldOrgNode)
	SELECT	ID, OrgNode
	FROM	OrganisationalUnits ou 
	WHERE	(ou.ParentID = @ParentID)

	UPDATE	ou
	SET		OrgNode =  OrgNode.GetReparentedValue ( @OldParentOrgNode, @NewParentOrgNode )
	From	SCore.OrganisationalUnits ou
	JOIN	@Children c on (c.Id = ou.Id)

	UPDATE	c
	SET		NewOrgNode = ou.OrgNode
	FROM 	@Children c
	JOIN	SCore.OrganisationalUnits ou on (ou.Id = C.ID)


	DECLARE	@MaxChildID int,
			@CurrentChildID int

	SELECT	@MaxChildID = MAX(ID),
			@CurrentChildID = -1
	FROM	@Children 


	WHILE @CurrentChildID < @MaxChildID
	BEGIN 
		SELECT	TOP (1) @CurrentChildID = ID,
				@NewParentOrgNode = NewOrgNode,
				@OldParentOrgNode = OldOrgNode
		FROM	@Children
		WHERE	(ID > @CurrentChildID)
		ORDER BY	ID 

		EXEC  SCore.OrganisationalUnit_RetreeDescendants @ParentID = @CurrentChildID, @NewParentOrgNode = @NewParentOrgNode, @OldParentOrgNode = @OldParentOrgNode
	END
END

GO