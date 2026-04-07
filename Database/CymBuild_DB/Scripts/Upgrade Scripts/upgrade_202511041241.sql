

/*
		[INSERTING MISSING STATUS]
		This script is created to insert a missing status flagged by CDM. 
		The missing status in question is "Complete for Review".
	
		[REORDERING]
		Furthermore, the script also reorders the statuses into a logical order
		(this is just to make it easier to follow the statuses for the users).

		[SETTING THE ISFINAL WHERE REQUIRED]
		For two transitions, we also update IsFinal (one should be final while the other should not)
		This is to prevent the record being locked when it should not.

		Below is what it will look like in the end.

		[  FROM   ]					[   TO    ]			[  ORDER  ]
		N/A 					=>	Job Started				0
		Job Started				=>	Completed				1
		Job Started				=>	Dormant					2
		Job Started				=>	Cancelled				3
		Job Started				=>	Dead					4
		Job Started				=>	Complete for Review		5
		Complete for Review		=>	Reviewed				6
		Reviewed				=>	Completed				7
*/



--[Variables for targeting the default job workflow]
DECLARE @DefaultJobWorkflow UNIQUEIDENTIFIER = 'C78082F6-3335-4AB9-BBD8-B94E7912AA8C';
DECLARE @DefaultJobWorkflowID INT;


--[Missing Status Guid + Missing Status ID]
DECLARE @CompleteForReviewStatusGuid UNIQUEIDENTIFIER = '4BFDB215-3E27-4829-BB44-0468C92DAC82';
DECLARE @CompletedForReviewStatusID INT;


--[Get the missing status ID]
SELECT	@CompletedForReviewStatusID = ID 
FROM	SCore.WorkflowStatus
WHERE	Guid =  @CompleteForReviewStatusGuid;


-- [Existing transition we would like to update (toStatus should be "Complete For Review"]
DECLARE @WorkflowTransitionToChangeGuid UNIQUEIDENTIFIER = '5AFCCEE1-BD75-45B3-BA2A-69D0F16B7FBC';


-- [Get the ID for the default job workflow]
SELECT	@DefaultJobWorkflowID = ID 
FROM	SCore.Workflow 
WHERE	Guid = @DefaultJobWorkflow


-- [Update the existing transition (toStatus = "Complete For Review]
UPDATE SCore.WorkflowTransition
SET ToStatusID = @CompletedForReviewStatusID
WHERE Guid = @WorkflowTransitionToChangeGuid;


-- [Next, add the missing transition]
DECLARE @NewTransitionGuid UNIQUEIDENTIFIER = NEWID();
DECLARE @ReviewedStatusGuid UNIQUEIDENTIFIER = '90407454-9FED-4AAC-AB20-669C5821FE7A';

EXEC SCore.WorkflowTransitionUpsert @NewTransitionGuid, @DefaultJobWorkflow, @CompleteForReviewStatusGuid, @ReviewedStatusGuid, 0, 1, 6, N'' 



--========================================
--=[UPDATE THE SORT ORDER FOR THE USER]  =
--========================================
UPDATE SCore.WorkflowTransition
SET SortOrder = 3
WHERE Guid = 'A24C547D-E5D6-403A-B66E-54A5B3654385';

UPDATE SCore.WorkflowTransition
SET SortOrder = 4
WHERE Guid = '94B286D3-DFBA-4ED8-9837-3F3CA4D50A8B';

UPDATE SCore.WorkflowTransition
SET SortOrder = 5
WHERE Guid = '5AFCCEE1-BD75-45B3-BA2A-69D0F16B7FBC';

UPDATE SCore.WorkflowTransition
SET SortOrder = 7
WHERE Guid = 'DAE95C6F-F82E-4FB1-9037-FD1C1F8858CF';


--=========================================
--= SET ISFINAL TO 0/1 WHERE NEEDED       =
--=========================================
UPDATE SCore.WorkflowTransition
SET IsFinal = 0
WHERE Guid = '4E76122C-A996-4FF7-9229-11BF6116E03E';

UPDATE SCore.WorkflowTransition
SET IsFinal = 1
WHERE Guid = 'DAE95C6F-F82E-4FB1-9037-FD1C1F8858CF';



