SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SFin].[TransactionExportsToSageUpsert]
	(	@InclusiveToDate DATE,
		@OrganisationalUnitGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @ExportData NVARCHAR(MAX),
			@ExportId	BIGINT,
			@OrganisationalUnitId INT,
			@IsInsert bit;

	SELECT	@OrganisationalUnitId = ou.ID
	FROM	SCore.OrganisationalUnits AS ou
	WHERE	(ou.Guid = @OrganisationalUnitGuid)

	EXEC SCore.UpsertDataObject
		@Guid = @Guid,
		@SchemeName = N'SFin',
		@ObjectName = N'SageExports',
		@IncludeDefaultSecurity = 1,
		@IsInsert = @IsInsert OUT

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SFin.SageExports
			 (RowStatus, Guid, InclusiveToDate, ExportData, OrganisationalUnitId)
		VALUES
			 (
				 1,		-- RowStatus - tinyint
				 @Guid, -- Guid - uniqueidentifier
				 @InclusiveToDate,
				 N'', 
				 @OrganisationalUnitId
			 );

		SELECT	@ExportId = SCOPE_IDENTITY ();

		INSERT	SFin.SageExportTransactions
			 (RowStatus, Guid, SageExportID, TransactionID)
		SELECT	1,
				NEWID (),
				@ExportId,
				t.ID
		FROM	SFin.Transactions	  AS t
		JOIN	SFin.TransactionTypes AS tt ON (tt.ID = t.TransactionTypeID)
		WHERE	(t.Date	 <= @InclusiveToDate)
			AND (tt.Name = N'Invoice')
			AND (t.LegacyId IS NULL)
			AND	(t.OrganisationalUnitId = @OrganisationalUnitId)
			AND (NOT EXISTS
			(
				SELECT	1
				FROM	SFin.SageExportTransactions AS e
				WHERE	(e.TransactionID = t.ID)
					AND (e.RowStatus NOT IN (0, 254))
			)
				);


		SELECT	@ExportData = STUFF (
			 (
				 SELECT		CHAR (13) + N'"' + LTRIM(RTRIM(a.Code)) + N'",' + REPLACE (	CONVERT (	NVARCHAR(MAX),
																				t.Date,
																				103
																			),
																	N' ',
																	N'-'
																) + N',' + CONVERT (   NVARCHAR(MAX),
																					   t.Number
																				   ) + N','
							+ CASE
								  WHEN td.VatRate = 20 THEN N'10'
								  ELSE N'11'
							  END + N',INV,1,' + CONVERT (	NVARCHAR(MAX),
															td.Net
														) + N',31010,' + SUBSTRING(ou.CostCentreCode, 1, 3) + ',' + SUBSTRING(ou.CostCentreCode, 5, 3) + ',"' + td.Description + N'","'
							+ t.PurchaseOrderNumber + N'"'
				 FROM		SFin.Transactions			 AS t
				 JOIN		SFin.TransactionDetails		 AS td ON (td.TransactionID = t.ID)
				 JOIN		SCore.OrganisationalUnits AS ou ON (ou.ID = t.OrganisationalUnitId)
				 JOIN		SCrm.Accounts				 AS a ON (a.ID				= t.AccountID)
				 WHERE		(EXISTS
			 (
				 SELECT 1
				 FROM	SFin.SageExportTransactions AS e
				 WHERE	(e.TransactionID = t.ID)
					AND (e.SageExportID	 = @ExportId)
			 )
							)
				 ORDER BY	t.Number
				 FOR XML PATH (''), TYPE
			 ).value (	 'text()[1]',
						 'nvarchar(max)'
					 ),
			 1,
			 LEN (CHAR (13)),
			 ''
									);

		UPDATE	SFin.SageExports
		SET		ExportData = ISNULL (	@ExportData,
										N''
									)
		WHERE	(ID = @ExportId);



	END;

END;
GO