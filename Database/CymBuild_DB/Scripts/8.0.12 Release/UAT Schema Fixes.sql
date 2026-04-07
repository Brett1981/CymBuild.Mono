SET CONCAT_NULL_YIELDS_NULL, ANSI_NULLS, ANSI_PADDING, QUOTED_IDENTIFIER, ANSI_WARNINGS, ARITHABORT, XACT_ABORT ON
SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF
GO


--
-- Set transaction isolation level
--
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO

--
-- Start Transaction
--
BEGIN TRANSACTION
GO

--
-- Create or alter function [SUserInterface].[tvf_WidgetDashBoardDefinitions]
--
GO

CREATE OR ALTER FUNCTION [SUserInterface].[tvf_WidgetDashBoardDefinitions] (@UserId INT)
RETURNS TABLE
	--WITH SCHEMABINDING
AS
RETURN
(
    -- Select Widget Grid Definitions
    SELECT 
        N'WIDGETGRIDS' AS Type,
        olfu.LabelPlural AS Name,
        gvd.ID,
        gvd.Guid,
        gvd.ROWVERSION,
        gvd.Code,
        gd.Code AS GridCode,
        gvd.GridDefinitionId,
        gvd.SqlQuery,
        gvd.DetailPageUri,
        gvd.DefaultSortColumnName,
        gvd.DisplayGroupName,
        gvd.DisplayOrder,
        gvd.MetricSqlQuery,
        gvd.ShowMetric,
        gvd.IsDetailWindowed,
        i.Name AS DrawerIconCss,
        gvd.IsDefaultSortDescending,
        gvd.AllowNew,
        gvd.AllowExcelExport,
        gvd.AllowPdfExport,
        gvd.AllowCsvExport,
        et.Guid AS EntityTypeGuid,
        gvt.Guid AS GridViewTypeGuid,
        gvd.GridViewTypeId,
        gvd.AllowBulkChange,
        '' AS WidgetDisplayGroupName,
        0 AS WidgetDisplayOrder,
        0 AS [Min], 
        0 AS [Max],
        0 AS [MinorUnit],
        0 AS [MajorUnit],
        0 AS [StartAngle],
        0 AS [EndAngle],
        0 AS [Reverse],
        0 AS Range1MinValue,
        0 AS Range1MaxValue,
        '' AS Range1ColourHex,
        0 AS Range2MinValue,
        0 AS Range2MaxValue,
        '' AS Range2ColourHex,
        '' AS MetricTypeName,
        '00000000-0000-0000-0000-000000000000' AS MetricGuid,
        '' AS GaugeMetricSqlQuery,
        '' AS PageUri
    FROM 
        SUserInterface.GridViewDefinitions gvd
    JOIN 
        SUserInterface.GridDefinitions gd ON gd.ID = gvd.GridDefinitionId
    JOIN 
        SUserInterface.Icons i ON gvd.DrawerIconId = i.ID
    JOIN 
        SUserInterface.GridViewTypes gvt ON gvt.ID = gvd.GridViewTypeId
    JOIN 
        SCore.EntityTypes et ON gvd.EntityTypeID = et.ID
    OUTER APPLY 
        SCore.ObjectLabelForUser(gvd.LanguageLabelID, @UserId) olfu
    WHERE 
        EXISTS (
            SELECT 1 
            FROM SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId) 
        )

        AND (
				(
					gvd.DisplayOrder <= 1
					AND (
							(gd.Code IN (N'CRM', N'ENQUIRIES', N'FINANCE', N'JOBS', N'MYPROJECTS', N'PROJECTS', N'PROPERTIES', N'QUOTES'))
							
					
						)
				)
			OR (gd.Code = N'MYPROJECTS')
			OR (gd.Code = N'SETTINGS' AND gvd.Code = 'USERS')
			)

    UNION ALL

    -- Select Widget Gauges
    SELECT 
        N'WIDGETGAUGES' AS Type,
        olfu.LabelPlural,
        0 AS ID,
        '00000000-0000-0000-0000-000000000000' AS Guid,
        0 AS ROWVERSION,
        gvd.Code AS Code,
        gd.Code AS GridCode,
        '' AS GridDefinitionId,
        '' AS SqlQuery,
        '' AS DetailPageUri,
        '' AS DefaultSortColumnName,
        '' AS DisplayGroupName,
        0 AS DisplayOrder,
        0 AS MetricSqlQuery,
        0 AS ShowMetric,
        0 AS IsDetailWindowed,
        '' AS DrawerIconCss,
        0 AS IsDefaultSortDescending,
        0 AS AllowNew,
        0 AS AllowExcelExport,
        0 AS AllowPdfExport,
        0 AS AllowCsvExport,
        '00000000-0000-0000-0000-000000000000' AS EntityTypeGuid,
        '00000000-0000-0000-0000-000000000000' AS GridViewTypeGuid,
        0 AS GridViewTypeId,
        0 AS AllowBulkChange,
        gvd.DisplayGroupName,
        gvd.DisplayOrder,
        gvd.MetricMin,
        gvd.MetricMax,
        gvd.MetricMinorUnit,
        gvd.MetricMajorUnit,
        gvd.MetricStartAngle,
        gvd.MetricEndAngle,
        gvd.MetricReversed,
        gvd.MetricRange1Min,
        gvd.MetricRange1Max,
        gvd.MetricRange1ColourHex,
        gvd.MetricRange2Min,
        gvd.MetricRange2Max,
        gvd.MetricRange2ColourHex,
        mt.Name AS MetricTypeName,
        gvd.Guid AS MetricGuid,
        gvd.MetricSqlQuery,
        gd.PageUri
    FROM 
        SUserInterface.GridViewDefinitions gvd
    JOIN 
        SUserInterface.GridDefinitions gd ON gd.ID = gvd.GridDefinitionId
    JOIN 
        SUserInterface.MetricTypes mt ON mt.ID = gvd.MetricTypeID
    OUTER APPLY 
        SCore.ObjectLabelForUser(gvd.LanguageLabelId, @UserId) olfu
    WHERE 
        gvd.ShowMetric = 1
        AND gvd.RowStatus NOT IN (0, 254)
        AND gd.RowStatus NOT IN (0, 254)
        AND mt.RowStatus NOT IN (0, 254)
        AND EXISTS (
            SELECT 1 
            FROM SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId)
        )

    UNION ALL

    -- Select Widget Layout
    SELECT 
        N'WIDGETLAYOUT' AS Type,
        WidgetLayout,
        0 AS ID,
        '00000000-0000-0000-0000-000000000000' AS Guid,
        0 AS ROWVERSION,
        '' AS Code,
        '' AS GridCode,
        '' AS GridDefinitionId,
        '' AS SqlQuery,
        '' AS DetailPageUri,
        '' AS DefaultSortColumnName,
        '' AS DisplayGroupName,
        0 AS DisplayOrder,
        0 AS MetricSqlQuery,
        0 AS ShowMetric,
        0 AS IsDetailWindowed,
        '' AS DrawerIconCss,
        0 AS IsDefaultSortDescending,
        0 AS AllowNew,
        0 AS AllowExcelExport,
        0 AS AllowPdfExport,
        0 AS AllowCsvExport,
        '00000000-0000-0000-0000-000000000000' AS EntityTypeGuid,
        '00000000-0000-0000-0000-000000000000' AS GridViewTypeGuid,
        0 AS GridViewTypeId,
        0 AS AllowBulkChange,
        '' AS WidgetDisplayGroupName,
        0 AS WidgetDisplayOrder,
        0 AS Min,
        0 AS Max,
        0 AS MinorUnit,
        0 AS MajorUnit,
        0 AS StartAngle,
        0 AS EndAngle,
        0 AS Reverse,
        0 AS Range1MinValue,
        0 AS Range1MaxValue,
        '' AS Range1ColourHex,
        0 AS Range2MinValue,
        0 AS Range2MaxValue,
        '' AS Range2ColourHex,
        '' AS MetricTypeName,
        '00000000-0000-0000-0000-000000000000' AS MetricGuid,
        '' AS GaugeMetricSqlQuery,
        '' AS PageUri
    FROM 
        SCore.UserPreferences
    WHERE 
        ID = @UserId
)


GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Drop function [SFin].[tvf_InvoiceRequests]
--
DROP FUNCTION [SFin].[tvf_InvoiceRequests]
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create or alter function [SFin].[tvf_InvoiceRequests]
--
GO



CREATE OR ALTER FUNCTION [SFin].[tvf_InvoiceRequests] 
(
    @UserId INT
)
RETURNS TABLE
      WITH SCHEMABINDING
AS
RETURN 
SELECT  ir.ID,
        ir.RowStatus,
        ir.RowVersion,
        ir.Guid,
        ir.Notes,
		ir.CreatedDateTimeUTC,
		i.Guid RequesterUserId,
		i.FullName SurveyorName,
		j.Guid JobId,
		j.Number 				
FROM    SFin.InvoiceRequests ir
JOIN	SJob.Jobs j ON (j.ID = ir.JobId)
JOIN	SCore.Identities i ON (i.ID = ir.RequesterUserId)
WHERE   (ir.RowStatus  NOT IN (0, 254))
	AND	(ir.Id > 0)
	AND (EXISTS
			(
				SELECT	1
				FROM	SFin.InvoiceRequestItems AS iri
				WHERE	(iri.RowStatus NOT IN (0, 254))
					AND	(iri.InvoiceRequestId = ir.ID)
			)
		)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) oscr
			)
		)
	AND	(NOT EXISTS
			(
	SELECT
			1
	FROM
			SFin.TransactionDetails td
	INNER JOIN
			SFin.InvoiceRequestItems iri on (iri.Id = td.InvoiceRequestItemId)
	WHERE	
			(iri.InvoiceRequestId = ir.ID) 
			)
		)
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Create or alter procedure [SFin].[InvoiceRequestCreateInvoice]
--
GO







CREATE OR ALTER PROCEDURE [SFin].[InvoiceRequestCreateInvoice]
	(
		@Guid UNIQUEIDENTIFIER
	)
AS
	BEGIN
		SET NOCOUNT ON 

		DECLARE	@AccountGuid UNIQUEIDENTIFIER, 
				@JobGuid UNIQUEIDENTIFIER,
				@TransactionTypeGuid UNIQUEIDENTIFIER,
				@Date DATE = GETUTCDATE(), 
				@PurchaseOrderNumber NVARCHAR(28),
				@OrganisationalUnitGuid UNIQUEIDENTIFIER,
				@CreatedByUserGuid UNIQUEIDENTIFIER,
				@SurveyorGuid UNIQUEIDENTIFIER,
				@CreditTermsGuid UNIQUEIDENTIFIER,
				@TransactionGuid UNIQUEIDENTIFIER = NEWID(),
				@InvoiceRequestId INT,
				@TransactionId INT,
				@Description NVARCHAR(MAX) = N'',
				@JobDescription NVARCHAR(MAX),
				@JobNumber NVARCHAR(30),
				@UprnFormattedAddressComma NVARCHAR(MAX),
				@JobType NVARCHAR(MAX)

		SELECT	@AccountGuid = fa.Guid,
				@InvoiceRequestId = ir.ID, 
				@JobGuid = j.Guid,
				@SurveyorGuid = r.Guid,
				@JobDescription = j.JobDescription,
				@JobNumber = j.Number,
				@JobType = jt.Name,
				@PurchaseOrderNumber = j.PurchaseOrderNumber,
				@OrganisationalUnitGuid = ou.Guid,
				@CreditTermsGuid = ct.Guid,
				@UprnFormattedAddressComma = uprn.FormattedAddressComma
		FROM	SFin.InvoiceRequests ir
		JOIN	SJob.Jobs j ON (j.ID = ir.JobId)
		JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
		JOIN	SJob.Properties uprn ON (uprn.ID = j.UprnID)
		JOIN	SCrm.Accounts fa ON (fa.ID = j.FinanceAccountID)
		JOIN	SCore.Identities r ON (r.ID = ir.RequesterUserId)
		JOIN	SCore.OrganisationalUnits ou ON (ou.Id = j.OrganisationalUnitID)
		JOIN	SFin.CreditTerms ct on (ct.ID = fa.DefaultCreditTermsId)
		WHERE ir.Guid = @Guid

		SELECT	@CreatedByUserGuid = SCore.GetCurrentUserGuid()

		SELECT	@TransactionTypeGuid = tt.Guid 
		FROM	SFin.TransactionTypes tt
		WHERE	(tt.Name = N'Invoice')

		-- Create the invoice header
		EXEC SFin.TransactionsUpsert @AccountGuid = @AccountGuid,				-- uniqueidentifier
									 @JobGuid = @JobGuid,					-- uniqueidentifier
									 @TransactionTypeGuid = @TransactionTypeGuid,		-- uniqueidentifier
									 @Date = @Date,				-- date
									 @PurchaseOrderNumber = @PurchaseOrderNumber,		-- nvarchar(28)
									 @SageTransactionReference = N'',	-- nvarchar(50)
									 @OrganisationalUnitGuid = @OrganisationalUnitGuid,	-- uniqueidentifier
									 @CreatedByUserGuid = @CreatedByUserGuid,			-- uniqueidentifier
									 @SurveyorGuid = @SurveyorGuid,				-- uniqueidentifier
									 @CreditTermsGuid = @CreditTermsGuid,			-- uniqueidentifier
									 @Guid = @TransactionGuid						-- uniqueidentifier

		SELECT	@TransactionId = ID
		FROM	SFin.Transactions t
		WHERE	(Guid = @TransactionGuid)

		SET @Description = @Description + N'	
Our project ref.: ' + @JobNumber + N'
Project description: ' + @JobDescription + N'
Property: ' + @UprnFormattedAddressComma + N'
Appointed role: ' + @JobType

		DECLARE	@DetailList SCore.TwoGuidUniqueList,
				@NewDetailRecords SCore.GuidUniqueList

		INSERT	@DetailList
			 (GuidValue, GuidValueTwo)
		SELECT	iri.Guid,
				NEWID()
		FROM	SFin.InvoiceRequestItems iri
		WHERE	(iri.InvoiceRequestId = @InvoiceRequestId)
			AND	(iri.RowStatus NOT IN (0, 254))


		INSERT	@NewDetailRecords (GuidValue)
		SELECT	GuidValueTwo
		FROM	@DetailList

		DECLARE	@IsInsert BIT 

		EXEC SCore.DataObjectBulkUpsert 
			@GuidList = @NewDetailRecords,
			@SchemeName = N'SFin',
			@ObjectName = N'TransactionDetails',
			@IncludeDefaultSecurity = 0,
			@IsInsert = @IsInsert OUT 

		INSERT	SFin.TransactionDetails
			 (RowStatus,
			  Guid,
			  TransactionID,
			  MilestoneID,
			  ActivityID,
			  Net,
			  Vat,
			  Gross,
			  VatRate,
			  Description,
			  LegacyId,
			  JobPaymentStageId,
			  InvoiceRequestItemId)
		SELECT	1,
				dl.GuidValueTwo,
				@TransactionId,
				iri.MilestoneId,
				iri.ActivityId,
				iri.Net,
				iri.Net * 0.2,
				iri.Net * 1.2,
				20,
				@Description, 
				NULL,
				-1,
				iri.Id
		FROM	@DetailList dl
		JOIN	SFin.InvoiceRequestItems iri ON (iri.Guid = dl.GuidValue)
		

	END;
GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Commit Transaction
--
IF @@TRANCOUNT>0 COMMIT TRANSACTION
GO

--
-- Set NOEXEC to off
--
SET NOEXEC OFF
GO