SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[GetLastModificationUser]
(
	@ObjectGuid UNIQUEIDENTIFIER
)
RETURNS NVARCHAR(250)
AS
BEGIN
	DECLARE	@LastModificationUserID INT,
			@LastModificationUserName NVARCHAR(250)

	SELECT	TOP(1) @LastModificationUserId = rh.UserID,
			@LastModificationUserName = rh.SQLUser
	FROM	SCore.RecordHistory AS rh
	WHERE	(rh.RowGuid = @ObjectGuid)
	ORDER BY rh.Datetime DESC

	IF (@LastModificationUserID > 0)
	BEGIN 
		SELECT	@LastModificationUserName = i.FullName
		FROM	SCore.Identities AS i 
		WHERE	(i.ID = @LastModificationUserID)
	END

	RETURN @LastModificationUserName

END
GO