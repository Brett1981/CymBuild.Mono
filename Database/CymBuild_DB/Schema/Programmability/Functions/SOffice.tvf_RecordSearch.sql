SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SOffice].[tvf_RecordSearch]
	(
		@UserId INT,
		@SearchString NVARCHAR(500),
		@EntityTypeGuid UNIQUEIDENTIFIER,
		@ToAddressesCSV NVARCHAR(4000),
		@FromAddress NVARCHAR(500),
		@Subject NVARCHAR(2000)
	)
RETURNS TABLE
AS
RETURN
	 (
		 WITH GroupedResults AS 
		 (
			 SELECT		sms.ID,
						ROW_NUMBER() OVER (PARTITION BY et.Name ORDER BY CASE
							WHEN
							   (
								   (sms.Number = SUBSTRING (   @SearchString,
															   2,
															   LEN (@SearchString) - 2
														   )
								   )
							   AND	(@SearchString LIKE N'"%"')
							   ) THEN 11
							WHEN (ConversationMatch.IsMatch = 1)
							 AND (@SearchString = sms.Number) THEN 10
							WHEN (ConversationMatch.IsMatch = 1) THEN 9
							WHEN (ToMatch.IsMatch = 1)
							 AND (@SearchString = sms.Number) THEN 8
							WHEN (@SearchString = sms.Number) THEN 7
							WHEN (ToMatch.IsMatch = 1)
							 AND (RecordMatch.IsMatch = 1) THEN 6
							WHEN (FromMatch.IsMatch = 1)
							 AND (RecordMatch.IsMatch = 1) THEN 5
							WHEN (RecordMatch.IsMatch = 1) THEN 6
							WHEN (ToMatch.IsMatch = 1)
							 AND (@SearchString = N'') THEN 3
							WHEN (ToMatch.IsMatch = 1) THEN 2
							WHEN (FromMatch.IsMatch = 1) THEN 1
							ELSE 0
						END		 DESC) AS RowNum,
						sms.Guid,
						et.Name AS EntityTypeName,
						sms.Name,
						CASE
							WHEN
							   (
								   (sms.Number = SUBSTRING (   @SearchString,
															   2,
															   LEN (@SearchString) - 2
														   )
								   )
							   AND	(@SearchString LIKE N'"%"')
							   ) THEN 11
							WHEN (ConversationMatch.IsMatch = 1)
							 AND (@SearchString = sms.Number) THEN 10
							WHEN (ConversationMatch.IsMatch = 1) THEN 9
							WHEN (ToMatch.IsMatch = 1)
							 AND (@SearchString = sms.Number) THEN 8
							WHEN (@SearchString = sms.Number) THEN 7
							WHEN (ToMatch.IsMatch = 1)
							 AND (RecordMatch.IsMatch = 1) THEN 6
							WHEN (FromMatch.IsMatch = 1)
							 AND (RecordMatch.IsMatch = 1) THEN 5
							WHEN (RecordMatch.IsMatch = 1) THEN 6
							WHEN (ToMatch.IsMatch = 1)
							 AND (@SearchString = N'') THEN 3
							WHEN (ToMatch.IsMatch = 1) THEN 2
							WHEN (FromMatch.IsMatch = 1) THEN 1
							ELSE 0
						END						  AS SearchRank,
						CONVERT(BIT, ISNULL(ConversationMatch.IsMatch, 0)) AS ConversationMatch,
						CONVERT(BIT, ISNULL(ToMatch.IsMatch	, 0))		  AS ToMatch,
						CONVERT(BIT, ISNULL(FromMatch.IsMatch, 0))		  AS FromMatch,
						CONVERT(BIT, ISNULL(RecordMatch.IsMatch	, 0))	  AS RecordMatch
			 FROM		SOffice.TargetObjects sms
			 JOIN		SOffice.EntityTypes et ON (et.ID = sms.EntityTypeId)
			 OUTER APPLY
						(
							SELECT	1 AS IsMatch
							FROM	SOffice.OutlookEmails AS oe
							JOIN	SOffice.TargetObjects AS t ON (t.ID = oe.TargetObjectID)
							WHERE	(et.ID = t.EntityTypeId)
								AND (sms.ID		= oe.TargetObjectID)
								AND (oe.SearchSubject		= REPLACE (	  @Subject,
																	  N'RE: ',
																	  N''
																  )
									)
								AND
								  (
									  (@ToAddressesCSV	= oe.ToAddresses)
								   OR (CONTAINS(oe.ToAddresses, @FromAddress))
								  )
								AND (oe.IsFiled			= 1)
								AND (@ToAddressesCSV	<> N'')
								AND (@Subject			<> N'')
								AND (@FromAddress		<> N'no-reply@socotec.co.uk')
								AND (@SearchString NOT LIKE N'"%"')
						) AS ConversationMatch
			 OUTER APPLY
						(
							SELECT	1 AS IsMatch
							FROM	SOffice.OutlookEmails AS oe
							JOIN	SOffice.TargetObjects AS t ON (t.ID = oe.TargetObjectID)
							WHERE	(et.ID = t.EntityTypeId)
								AND (sms.ID		= oe.TargetObjectID)
								AND (oe.ToAddresses		= @ToAddressesCSV)
								AND
								  (
									  (ISNULL (	  CHARINDEX (	N'@',
																LEN (REPLACE (	 @ToAddressesCSV,
																				 N'@socotec.co.uk',
																				 N''
																			 )
																	)
															),
												  0
											  )			> 0
									  )
								   OR (@ToAddressesCSV NOT LIKE N'%@socotec.co.uk%')
								  )
								AND (oe.IsFiled			= 1)
								AND (@ToAddressesCSV	<> N'')
								AND (@FromAddress		<> N'no-reply@socotec.co.uk')
								AND (@SearchString NOT LIKE N'"%"')
						) AS ToMatch
			 OUTER APPLY
						(
							SELECT	1 AS IsMatch
							FROM	SOffice.OutlookEmails AS oe
							JOIN	SOffice.OutlookEmailFromAddresses fa ON (fa.ID = oe.OutlookEmailFromAddressID)
							JOIN	SOffice.TargetObjects AS t ON (t.ID = oe.TargetObjectID)
							WHERE	(et.ID = t.EntityTypeId)
								AND (sms.ID		= oe.TargetObjectID)
								AND	(fa.RowStatus NOT IN (0, 254))
								AND
								  (
									  (fa.Address	= @FromAddress)
								   OR (CONTAINS(oe.ToAddresses, @FromAddress))
								  )
								AND (@FromAddress NOT LIKE N'%@soctec.co.uk%')
								AND (@FromAddress NOT LIKE N'%@Soctec.co.uk')
								AND (oe.IsFiled			= 1)
								AND (@FromAddress		<> N'')
								AND (@SearchString NOT LIKE N'"%"')
						) AS FromMatch
			 OUTER APPLY
						(
							SELECT	1 AS IsMatch
							WHERE	
								  (
									  (sms.Name			= @SearchString)
								   OR (sms.Name LIKE N'%' + @SearchString + N'%')
								  )
								AND (@SearchString		<> N'')
								AND (@SearchString NOT LIKE N'"%"')
						) AS RecordMatch
			 WHERE		(
							(@EntityTypeGuid		 = '00000000-0000-0000-0000-000000000000')
						 OR (et.Guid	 = @EntityTypeGuid)
						)
					AND
					  (
						  (
							  (sms.Number			 = SUBSTRING (	 @SearchString,
																	 2,
																	 LEN (@SearchString) - 2
																 )
						  )
					  AND (@SearchString LIKE N'"%"')
					  )
					   OR (ConversationMatch.IsMatch = 1)
					   OR (ToMatch.IsMatch			 = 1)
					   OR (FromMatch.IsMatch		 = 1)
					   OR (RecordMatch.IsMatch			 = 1)
					  )
			 GROUP BY	sms.ID,
						sms.Guid,
						et.Name,
						sms.Name,
						CASE
							WHEN
							   (
								   (sms.Number = SUBSTRING (   @SearchString,
															   2,
															   LEN (@SearchString) - 2
														   )
								   )
							   AND	(@SearchString LIKE N'"%"')
							   ) THEN 11
							WHEN (ConversationMatch.IsMatch = 1)
							 AND (@SearchString = sms.Number) THEN 10
							WHEN (ConversationMatch.IsMatch = 1) THEN 9
							WHEN (ToMatch.IsMatch = 1)
							 AND (@SearchString = sms.Number) THEN 8
							WHEN (@SearchString = sms.Number) THEN 7
							WHEN (ToMatch.IsMatch = 1)
							 AND (RecordMatch.IsMatch = 1) THEN 6
							WHEN (FromMatch.IsMatch = 1)
							 AND (RecordMatch.IsMatch = 1) THEN 5
							WHEN (RecordMatch.IsMatch = 1) THEN 6
							WHEN (ToMatch.IsMatch = 1)
							 AND (@SearchString = N'') THEN 3
							WHEN (ToMatch.IsMatch = 1) THEN 2
							WHEN (FromMatch.IsMatch = 1) THEN 1
							ELSE 0
						END,
						ConversationMatch.IsMatch,
						ToMatch.IsMatch,
						FromMatch.IsMatch,
						RecordMatch.IsMatch
		 )
		 SELECT ID, Guid, EntityTypeName, Name, SearchRank, ConversationMatch, ToMatch, FromMatch, RecordMatch
		 FROM  GroupedResults
		 WHERE RowNum <= 5
	 );
GO