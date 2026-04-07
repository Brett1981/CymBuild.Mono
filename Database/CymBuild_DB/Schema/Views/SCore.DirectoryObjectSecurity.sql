SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[DirectoryObjectSecurity]
               --WITH SCHEMABINDING
AS
SELECT	os.ObjectGuid, 
		COALESCE(i.EmailAddress, g.DirectoryId, N'') AS DirectoryId,
		CASE	WHEN os.CanWrite = 1 THEN N'write'
				WHEN os.CanWrite = 0 AND os.CanRead = 1 THEN N'read'
				ELSE N''
		END AS [role]
FROM	SCore.ObjectSecurity os 
LEFT JOIN	SCore.Identities i ON (i.ID = os.UserId)
LEFT JOIN	SCore.Groups g ON (g.ID = os.GroupId)
WHERE	(os.RowStatus = 1)
GO