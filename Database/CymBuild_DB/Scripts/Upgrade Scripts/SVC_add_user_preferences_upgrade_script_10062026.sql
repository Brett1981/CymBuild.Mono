BEGIN TRANSACTION;

DECLARE @SVC_UserID INT;
DECLARE @SVC_UserGuid UNIQUEIDENTIFIER;

--Get the SVC ID + Guid
SELECT @SVC_UserID = ISNULL(I.ID, - 1)
	,@SVC_UserGuid = I.Guid
FROM SCore.Identities AS I
WHERE FullName LIKE N'%SVC%';

--Ensure that the UserId <> -1
IF (@SVC_UserID <> - 1)
BEGIN

	
	--If there is no user preference for the SVC user, create it. 
	IF (
			NOT EXISTS (
				SELECT 1
				FROM SCore.UserPreferences root_hobt
				WHERE (
						root_hobt.RowStatus NOT IN (
							0
							,254
							)
						)
					AND (root_hobt.ID = @SVC_UserID)
					AND (root_hobt.Guid = @SVC_UserGuid)
				)
			)
	BEGIN
		INSERT SCore.UserPreferences (
			ID
			,Guid
			,RowStatus
			,SystemLanguageID
			)
		VALUES (
			@SVC_UserID
			,-- ID - int
			@SVC_UserGuid
			,-- Guid - uniqueidentifier
			1
			,-- RowStatus - tinyint
			1 -- SystemLanguageID - int
			);

		--Next, reset any attempt that exceeded 10 published attempts due 
		--to the lack of user preferences.
		UPDATE SCore.IntegrationOutbox
		SET PublishAttempts = 0
		WHERE (EventType = N'SharePointStructureRepairRequested')
			AND (PublishAttempts = 10)
	END;
END;