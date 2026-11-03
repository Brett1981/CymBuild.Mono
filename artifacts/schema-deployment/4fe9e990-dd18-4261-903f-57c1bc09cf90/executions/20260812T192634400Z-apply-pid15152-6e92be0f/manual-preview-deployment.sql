/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLBRE01\SQL2022
    Target database : Concursus
    Run Guid        : 4fe9e990-dd18-4261-903f-57c1bc09cf90
    Generated UTC   : 2026-08-12T19:26:34.5342408Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [Concursus];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 1, @read_only = 0;
GO
EXEC [SCore].[PreDeploymentScript];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;
GO

/* Deploy Function SCore.tvf_GetScheduledActivities using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SCore.tvf_GetScheduledActivities.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SCore].[tvf_GetScheduledActivities]')
GO
/*
	[*] Returns upcoming scheduled activities for a user.
	[*] Used in the "Scheduler" to popuate the calendar.
*/
CREATE OR ALTER FUNCTION [SCore].[tvf_GetScheduledActivities] 
(
	@UserId INT,
	@StartDate DATETIME,
	@EndDate DATETIME
)
RETURNS TABLE
AS
RETURN
(
   SELECT 
	root_hobt.SurveyorID AS UserId,
	root_hobt.Date AS StartDate,
	root_hobt.EndDate,
	root_hobt.Title,
	j.Number as JobNumber,
	root_hobt.Notes AS Note
FROM 
	SJob.Activities root_hobt
LEFT JOIN SJob.Jobs AS j ON j.ID = root_hobt.JobID
WHERE 
	(
		root_hobt.SurveyorID = @UserId AND 
		(root_hobt.Date >= @StartDate AND root_hobt.Date < @EndDate) AND
		EXISTS
		(
			--Get the Tentative status ID with an EXIST check
			SELECT 1 
			FROM SJob.ActivityStatus Acts
			WHERE 
				(
					Acts.ID = root_hobt.ActivityStatusID AND 
					--Acts.IsActive = 1 AND
					Acts.ID NOT IN (4, 6, 7)
				)
			
		)
		
	) 
);
GO
GO

/* Deploy Function SFin.tvf_AllTransactions using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SFin.tvf_AllTransactions.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter function [SFin].[tvf_AllTransactions]')
GO

/*
    CYB-445 / CYB-495 - Sage and payment status corrections for All Transactions.

    Authoritative evidence used:
      1. A receipt materialised by the Sage inbound process.
      2. Successful automated Sage submission.
      3. Active membership of a manual/legacy Sage Export.
      4. A non-empty SageTransactionReference.

    Behaviour preserved:
      - Inbound receipts display as Received from Sage, never Legacy.
      - Automated Succeeded remains Succeeded.
      - Existing automated non-success statuses remain unchanged where there
        is no manual-export evidence and no Sage reference.
      - Transactions with no automated status and no Sage evidence remain
        Not Sent.
      - JobNumber, JobDescription and Products remain part of the function contract.
      - Paid invoices are not overdue when Outstanding is zero.

    This deliberately does not infer Sage status from allocation alone.
*/

CREATE OR ALTER FUNCTION [SFin].[tvf_AllTransactions]
(
    @UserId INT
)
RETURNS TABLE
AS
RETURN
(
SELECT
      t.ID
    , t.RowStatus
    , t.RowVersion
    , t.Guid
    , t.Number
    , t.Date
    , a.Name AS Account
    , tt.Name AS TransactionType
    , tc.Net
    , tc.Vat
    , tc.Gross
    , tc.Outstanding
    , t.SageTransactionReference
    , t.PurchaseOrderNumber
    , i.FullName AS Surveyor
    , t.Batched
    , CASE
          WHEN t.TransactionTypeID = 1
           AND tc.Outstanding > 0
           AND DueDetails.DueDate <= GETUTCDATE()
              THEN N'Overdue'
          ELSE N''
      END AS IsOverdue
    , CASE
          WHEN SageInbound.IsSageInbound = 1
              THEN N'Received from Sage'
          WHEN s.StatusCode = N'Succeeded'
              THEN N'Succeeded'
          WHEN legacy.HasActiveManualSageExport = 1
            OR NULLIF
               (
                   LTRIM
                   (
                       RTRIM
                       (
                           ISNULL(t.SageTransactionReference, N'')
                       )
                   ),
                   N''
               ) IS NOT NULL
              THEN N'Legacy'
          WHEN s.StatusCode IS NULL
              THEN N'Not Sent'
          ELSE s.StatusCode
      END AS SageStatusCode
    , CASE
          WHEN NULLIF
               (
                   LTRIM
                   (
                       RTRIM
                       (
                           ISNULL(t.SageTransactionReference, N'')
                       )
                   ),
                   N''
               ) IS NOT NULL
              THEN 1
          ELSE 0
      END AS HasSageReference
    , OrgUnit.Name AS Department
    , OrgUnit2.Name AS OrgUnit
	,j.Number AS JobNumber,
	j.JobDescription,
	Prods.Products
FROM SFin.Transactions AS t
INNER JOIN SFin.TransactionCalculations AS tc
    ON tc.ID = t.ID
INNER JOIN SFin.TransactionTypes AS tt
    ON tt.ID = t.TransactionTypeID
   AND tt.RowStatus NOT IN (0, 254)
INNER JOIN SCrm.Accounts AS a
    ON a.ID = t.AccountID
   AND a.RowStatus NOT IN (0, 254)
INNER JOIN SCore.Identities AS i
    ON i.ID = t.SurveyorUserId
   AND i.RowStatus NOT IN (0, 254)
INNER JOIN SJob.Jobs AS j
    ON j.ID = t.JobID
   AND j.RowStatus NOT IN (0, 254)
INNER JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
   AND OrgUnit.RowStatus NOT IN (0, 254)
INNER JOIN SCore.OrganisationalUnits AS OrgUnit2
    ON OrgUnit.ParentID = OrgUnit2.ID
   AND OrgUnit2.RowStatus NOT IN (0, 254)
LEFT JOIN SFin.TransactionSageSubmissionStatus AS s
    ON s.TransactionGuid = t.Guid
   AND s.RowStatus <> 0
   AND s.RowStatus <> 254
CROSS APPLY SFin.tvf_OverdueInvoicesForJob(j.Guid) AS o
OUTER APPLY
(
    SELECT TOP (1)
        CONVERT(BIT, 1) AS IsSageInbound
    FROM SFin.SageExternalTransactions AS sageInbound
    WHERE sageInbound.MaterialisedReceiptTransactionGuid = t.Guid
      AND sageInbound.RowStatus NOT IN (0, 254)
    ORDER BY sageInbound.ID DESC
) AS SageInbound
OUTER APPLY
(
    SELECT TOP (1)
        CONVERT(BIT, 1) AS HasActiveManualSageExport
    FROM SFin.SageExportTransactions AS setr
    INNER JOIN SFin.SageExports AS se
        ON se.ID = setr.SageExportID
       AND se.RowStatus <> 0
       AND se.RowStatus <> 254
    WHERE setr.TransactionID = t.ID
      AND setr.RowStatus <> 0
      AND setr.RowStatus <> 254
    ORDER BY setr.ID DESC
) AS legacy
OUTER APPLY
	(
		SELECT STRING_AGG(d.Code, ',') AS Products
		FROM
		(
			SELECT DISTINCT p.Code
			FROM SSop.QuoteItems qi
			JOIN SJob.Jobs jobs
				ON jobs.ID = qi.CreatedJobId
				AND jobs.RowStatus NOT IN (0, 254)
			LEFT JOIN SProd.Products p
				ON p.ID = qi.ProductId
				AND p.RowStatus NOT IN (0, 254)
			WHERE qi.RowStatus NOT IN (0,254)
			  AND jobs.Guid = j.Guid
		) AS d
	) AS Prods
OUTER APPLY
(
    SELECT
        CASE
            WHEN CAST
                 (
                     SUM(ISNULL(td.Gross, 0))
                     AS DECIMAL(19, 2)
                 ) <> 0
                THEN CAST
                     (
                         COALESCE
                         (
                             CAST(tr.ExpectedDate AS DATE),
                             DATEADD
                             (
                                 DAY,
                                 ISNULL(ct.DueDays, 0),
                                 DATEADD
                                 (
                                     DAY,
                                     30,
                                     ISNULL
                                     (
                                         CAST(t.Date AS DATETIME),
                                         0
                                     )
                                 )
                             )
                         )
                         AS DATE
                     )
            ELSE NULL
        END AS DueDate
    FROM SFin.Transactions AS tr
    INNER JOIN SFin.TransactionTypes AS dueTt
        ON dueTt.ID = tr.TransactionTypeID
       AND dueTt.RowStatus NOT IN (0, 254)
    INNER JOIN SJob.Jobs AS dueJob
        ON dueJob.ID = t.JobID
       AND dueJob.RowStatus NOT IN (0, 254)
    LEFT JOIN SFin.TransactionDetails AS td
        ON td.TransactionID = t.ID
       AND td.RowStatus <> 0
       AND td.RowStatus <> 254
    LEFT JOIN SFin.CreditTerms AS ct
        ON ct.ID = t.CreditTermsId
       AND ct.RowStatus <> 0
       AND ct.RowStatus <> 254
    WHERE dueJob.ID = t.JobID
      AND tr.ID = t.ID
      AND tr.RowStatus <> 0
      AND tr.RowStatus <> 254
    GROUP BY
          tr.ExpectedDate
        , ct.DueDays
) AS DueDetails
WHERE t.RowStatus <> 0
  AND t.RowStatus <> 254
  AND t.ID > 0
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead
      (
          t.Guid,
          @UserId
      ) AS oscr
  )
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead
      (
          a.Guid,
          @UserId
      ) AS oscr
  )


UNION ALL


SELECT 
		root_hobt.ID,
        root_hobt.RowStatus,
        root_hobt.RowVersion,
        root_hobt.Guid,
        root_hobt.InvoiceNumber,
		root_hobt.InvoiceDate,
		a.Name AS Account,
		N'Subcontractor Invoice' AS TransactionType,
		root_hobt.ValueWithoutVAT AS Net,
		root_hobt.ValueWithVAT AS Vat,
		root_hobt.ValueWithVAT AS Gross,
		0 AS Outstanding,
		N'' AS SageTransactionReference,
		N'' AS PurchaseOrderNumber,
		Surveyor.FullName AS Surveyor,
		0 AS Batched,
		N'' AS IsOverdue,
		N'' AS SageStatusCode,
		N'' AS HasSageReference,
		OrgUnit.Name AS Department,
		OrgUnit2.Name AS OrgUnit,
			j.Number AS JobNumber,
			j.JobDescription AS JobDescription,
			Prods.Products
FROM SJob.SubContractorInvoices root_hobt
JOIN SJob.Jobs j
	ON root_hobt.JobId = j.ID
	AND j.RowStatus NOT IN (0, 254)
JOIN SCore.Identities Surveyor
	ON j.SurveyorID = Surveyor.ID
	AND Surveyor.RowStatus NOT IN (0, 254)
JOIN SCore.OrganisationalUnits AS OrgUnit
    ON OrgUnit.ID = j.OrganisationalUnitID
	AND OrgUnit.RowStatus NOT IN (0, 254)
JOIN SCore.OrganisationalUnits AS OrgUnit2
		ON OrgUnit.ParentID = OrgUnit2.ID
		AND OrgUnit2.RowStatus NOT IN (0, 254)
JOIN SCrm.Accounts AS a
	ON a.ID = root_hobt.SubContractorId
	AND a.RowStatus NOT IN (0, 254)
OUTER APPLY
	(
		SELECT STRING_AGG(d.Code, ',') AS Products
		FROM
		(
			SELECT DISTINCT p.Code
			FROM SSop.QuoteItems qi
			JOIN SJob.Jobs jobs
				ON jobs.ID = qi.CreatedJobId
				AND jobs.RowStatus NOT IN (0, 254)
			LEFT JOIN SProd.Products p
				ON p.ID = qi.ProductId
				AND p.RowStatus NOT IN (0, 254)
			WHERE qi.RowStatus NOT IN (0,254)
			  AND jobs.Guid = j.Guid
		) AS d
	) AS Prods
WHERE 
		(root_hobt.RowStatus NOT IN (0,254))
		AND (root_hobt.ID > 0)
		AND (root_hobt.InvoiceDate IS NOT NULL)
)
GO

GO

/* Deploy StoredProcedure SSop.EnquiriesDuplicate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Procedures\SSop.EnquiriesDuplicate.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[EnquiriesDuplicate]')
GO
CREATE OR ALTER PROCEDURE [SSop].[EnquiriesDuplicate]
	@SourceGuid UNIQUEIDENTIFIER,
	@TargetGuid UNIQUEIDENTIFIER
AS
	BEGIN

		DECLARE @SourceID INT,
				@SourceNumber NVARCHAR(50),
				@ID		  INT,
				@IsInsert BIT;

		SELECT
				@SourceID = ID,
				@SourceNumber = Number
		FROM
				SSop.Enquiries
		WHERE
				(Guid = @SourceGuid);

		IF (@@ROWCOUNT > 1)
			BEGIN
				;
				THROW 60000, N'Invalid source Enquiry', 1;
			END;

		EXEC SCore.UpsertDataObject
			@Guid					= @TargetGuid,
			@SchemeName				= N'SSop',
			@ObjectName				= N'Enquiries',
			@IncludeDefaultSecurity = 1,
			@IsInsert				= @IsInsert


		INSERT	SSop.Enquiries
			 (RowStatus,
			  Guid,
			  OrganisationalUnitID,
			  Date,
			  CreatedByUserId,
			  Number,
			  PropertyId,
			  PropertyNameNumber,
			  PropertyAddressLine1,
			  PropertyAddressLine2,
			  PropertyAddressLine3,
			  PropertyTown,
			  PropertyCountyId,
			  PropertyPostCode,
			  PropertyCountryId,
			  ClientAccountId,
			  ClientAddressId,
			  ClientAccountContactId,
			  ClientName,
			  ClientAddressNameNumber,
			  ClientAddressLine1,
			  ClientAddressLine2,
			  ClientAddressLine3,
			  ClientAddressTown,
			  ClientAddressCountyId,
			  ClientAddressPostCode,
			  ClientAddressCountryId,
			  AgentAccountId,
			  AgentAddressId,
			  AgentAccountContactId,
			  AgentName,
			  AgentAddressNameNumber,
			  AgentAddressLine1,
			  AgentAddressLine2,
			  AgentAddressLine3,
			  AgentTown,
			  AgentCountyId,
			  AgentAddressPostCode,
			  AgentCountryId,
			  DescriptionOfWorks,
			  ValueOfWork,
			  CurrentProjectRibaStageID,
			  RibaStage0Months,
			  RibaStage1Months,
			  RibaStage2Months,
			  RibaStage3Months,
			  RibaStage4Months,
			  RibaStage5Months,
			  RibaStage6Months,
			  RibaStage7Months,
			  PreConstructionStageMonths,
			  ConstructionStageMonths,
			  SendInfoToClient,
			  SendInfoToAgent,
			  KeyDates,
			  ExpectedProcurementRoute,
			  Notes,
			  EnquirySourceId,
			  IsReadyForQuoteReview,
			  QuotingDeadlineDate,
			  DeclinedToQuoteDate,
			  DeclinedToQuoteReason,
			  ExternalReference,
			  ProjectId,
			  IsSubjectToNDA,
			  DeadDate,
			  ChaseDate1,
			  ChaseDate2,
			  IsClientFinanceAccount,
			  FinanceAccountId,
			  FinanceAddressId,
			  FinanceContactId,
			  FinanceAccountName,
			  FinanceAddressNameNumber,
			  FinanceAddressLine1,
			  FinanceAddressLine2,
			  FinanceAddressLine3,
			  FinanceTown,
			  FinanceCountyId,
			  FinancePostCode,
			  EnterNewClientDetails,
			  EnterNewAgentDetails,
			  EnterNewFinanceDetails,
			  EnterNewStructureDetails,
			  SignatoryIdentityId,
			  ProposalLetter,
			  ClientContactDisplayName,
			  ClientContactDetailType,
			  ClientContactDetailTypeName,
			  ClientContactDetailTypeValue,
			  AgentContactDisplayName,
			  AgentContactDetailType,
			  AgentContactDetailTypeName,
			  AgentContactDetailTypeValue,
			  FinanceContactDisplayName,
			  FinanceContactDetailType,
			  FinanceContactDetailTypeName,
			  FinanceContactDetailTypeValue,
			  ContractID,
			  AgentContractID)
		SELECT
				 0,	-- RowStatus - tinyint
				 @TargetGuid,	-- Guid - uniqueidentifier
				 e.OrganisationalUnitID,	-- OrganisationalUnitID - int
				 e.Date,	-- Date - datetime2(7)
				 e.CreatedByUserId,	-- CreatedByUserId - int
				 (0),	-- Number - nvarchar(50)
				 e.PropertyId,	-- PropertyId - int
				 e.PropertyNameNumber,	-- PropertyNameNumber - nvarchar(100)
				 e.PropertyAddressLine1,	-- PropertyAddressLine1 - nvarchar(255)
				 e.PropertyAddressLine2,	-- PropertyAddressLine2 - nvarchar(255)
				 e.PropertyAddressLine3,	-- PropertyAddressLine3 - nvarchar(255)
				 e.PropertyTown,	-- PropertyTown - nvarchar(255)
				 e.PropertyCountyId,	-- PropertyCountyId - int
				 e.PropertyPostCode,	-- PropertyPostCode - nvarchar(30)
				 e.PropertyCountryId,	-- PropertyCountryId - int
				 e.ClientAccountId,	-- ClientAccountId - int
				 e.ClientAddressId,	-- ClientAddressId - int
				 e.ClientAccountContactId,	-- ClientAccountContactId - int
				 e.ClientName,	-- ClientName - nvarchar(250)
				 e.ClientAddressNameNumber,	-- ClientAddressNameNumber - nvarchar(100)
				 e.ClientAddressLine1,	-- ClientAddressLine1 - nvarchar(255)
				 e.ClientAddressLine2,	-- ClientAddressLine2 - nvarchar(255)
				 e.ClientAddressLine3,	-- ClientAddressLine3 - nvarchar(255)
				 e.ClientAddressTown,	-- ClientAddressTown - nvarchar(255)
				 e.ClientAddressCountyId,	-- ClientAddressCountyId - int
				 e.ClientAddressPostCode,	-- ClientAddressPostCode - nvarchar(30)
				 e.ClientAddressCountryId,	-- ClientAddressCountryId - int
				 e.AgentAccountId,	-- AgentAccountId - int
				 e.AgentAddressId,	-- AgentAddressId - int
				 e.AgentAccountContactId,	-- AgentAccountContactId - int
				 e.AgentName,	-- AgentName - nvarchar(250)
				 e.AgentAddressNameNumber,	-- AgentAddressNameNumber - nvarchar(100)
				 e.AgentAddressLine1,	-- AgentAddressLine1 - nvarchar(255)
				 e.AgentAddressLine2,	-- AgentAddressLine2 - nvarchar(255)
				 e.AgentAddressLine3,	-- AgentAddressLine3 - nvarchar(255)
				 e.AgentTown,	-- AgentTown - nvarchar(255)
				 e.AgentCountyId,	-- AgentCountyId - int
				 e.AgentAddressPostCode,	-- AgentAddressPostCode - nvarchar(30)
				 e.AgentCountryId,	-- AgentCountryId - int
				 e.DescriptionOfWorks,	-- DescriptionOfWorks - nvarchar(4000)
				 e.ValueOfWork,	-- ValueOfWork - decimal(19, 2)
				 e.CurrentProjectRibaStageID,	-- CurrentProjectRibaStageID - int
				 e.RibaStage0Months,	-- RibaStage0Months - int
				 e.RibaStage1Months,	-- RibaStage1Months - int
				 e.RibaStage2Months,	-- RibaStage2Months - int
				 e.RibaStage3Months,	-- RibaStage3Months - int
				 e.RibaStage4Months,	-- RibaStage4Months - int
				 e.RibaStage5Months,	-- RibaStage5Months - int
				 e.RibaStage6Months,	-- RibaStage6Months - int
				 e.RibaStage7Months,	-- RibaStage7Months - int
				 e.PreConstructionStageMonths,	-- PreConstructionStageMonths - int
				 e.ConstructionStageMonths,	-- ConstructionStageMonths - int
				 e.SendInfoToClient,	-- SendInfoToClient - bit
				 e.SendInfoToAgent,	-- SendInfoToAgent - bit
				 e.KeyDates,	-- KeyDates - nvarchar(2000)
				 e.ExpectedProcurementRoute,	-- ExpectedProcurementRoute - nvarchar(200)
				 e.Notes,	-- Notes - nvarchar(max)
				 e.EnquirySourceId,	-- EnquirySourceId - int
				 (0),	-- IsReadyForQuoteReview - bit
				 NULL,		-- QuotingDeadlineDate - date
				 NULL,		-- DeclinedToQuoteDate - date
				 N'',	-- DeclinedToQuoteReason - nvarchar(4000)
				 e.ExternalReference,	-- ExternalReference - nvarchar(50)
				 e.ProjectId,	-- ProjectId - int
				 e.IsSubjectToNDA,	-- IsSubjectToNDA - bit
				 NULL,		-- DeadDate - date
				 NULL,		-- ChaseDate1 - date
				 NULL,		-- ChaseDate2 - date
				 e.IsClientFinanceAccount,	-- IsClientFinanceAccount - bit
				 e.FinanceAccountId,	-- FinanceAccountId - int
				 e.FinanceAddressId,	-- FinanceAddressId - int
				 e.FinanceContactId,	-- FinanceContactId - int
				 e.FinanceAccountName,	-- FinanceAccountName - nvarchar(250)
				 e.FinanceAddressNameNumber,	-- FinanceAddressNameNumber - nvarchar(100)
				 e.FinanceAddressLine1,	-- FinanceAddressLine1 - nvarchar(255)
				 e.FinanceAddressLine2,	-- FinanceAddressLine2 - nvarchar(255)
				 e.FinanceAddressLine3,	-- FinanceAddressLine3 - nvarchar(255)
				 e.FinanceTown,	-- FinanceTown - nvarchar(255)
				 e.FinanceContactId,	-- FinanceCountyId - int
				 e.FinancePostCode,	-- FinancePostCode - nvarchar(30)
				 e.EnterNewClientDetails,	-- EnterNewClientDetails - bit
				 e.EnterNewAgentDetails,	-- EnterNewAgentDetails - bit
				 e.EnterNewFinanceDetails,	-- EnterNewFinanceDetails - bit
				 e.EnterNewStructureDetails,	-- EnterNewStructureDetails - bit
				 e.SignatoryIdentityId,	-- SignatoryIdentityId - int
				 e.ProposalLetter,	-- ProposalLetter - nvarchar(max)
				 e.ClientContactDisplayName, --ClientContactDisplayName nvarchar(250)
				 e.ClientContactDetailType,  --ClientContactDetailType smallint
				 e.ClientContactDetailTypeName, --ClientContactDetailTypeName nvarchar(100)
				 e.ClientContactDetailTypeValue, --ClientContactDetailTypeValue nvarchar(250)
				 e.AgentContactDisplayName, --AgentContactDisplayName nvarchar(250)
				 e.AgentContactDetailType,  --AgentContactDetailType smallint
				 e.AgentContactDetailTypeName, --AgentContactDetailTypeName nvarchar(100)
				 e.AgentContactDetailTypeValue, --AgentContactDetailTypeValue nvarchar(250)
				 e.FinanceContactDisplayName, --FinanceContactDisplayName nvarchar(250)
				 e.FinanceContactDetailType, --FinanceContactDetailType smallint
				 e.FinanceContactDetailTypeName, --FinanceContactDetailTypeName nvarchar(100)
				 e.FinanceContactDetailTypeValue, --FinanceContactDetailTypeValue nvarchar(250)
				 e.ContractID,
				 e.AgentContractID
		FROM	SSop.Enquiries AS e
		WHERE	(e.Guid = @SourceGuid)

		SELECT
				@ID = SCOPE_IDENTITY();

		-- Build the collection of Enquiry Services to duplicate. 
		DECLARE	@EnquiryServices SCore.TwoGuidUniqueList

		INSERT	@EnquiryServices
			 (GuidValue, GuidValueTwo)
		SELECT	es.Guid,
				NEWID()
		FROM	SSop.EnquiryServices AS es
		JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
		WHERE	(e.Guid = @SourceGuid)

		-- Create the data objects. 
		DECLARE @NewGuidList SCore.GuidUniqueList

		INSERT @NewGuidList
				(
					GuidValue
				)
			SELECT
					GuidValueTwo
			FROM
					@EnquiryServices

		EXEC SCore.DataObjectBulkUpsert
			@GuidList   = @NewGuidList,				-- GuidUniqueList
			@SchemeName = N'SSop',				-- nvarchar(255)
			@ObjectName = N'EnquiryServices',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit

		DELETE FROM
		@NewGuidList

		INSERT	SSop.EnquiryServices
			 (RowStatus, Guid, EnquiryId, JobTypeId, StartRibaStageId, EndRibaStageId, QuoteId)
		SELECT	1, 
				es.GuidValueTwo, 
				@ID, 
				es2.JobTypeId, 
				es2.StartRibaStageId,
				es2.EndRibaStageId,
				-1
		FROM	@EnquiryServices AS es
		JOIN	SSop.EnquiryServices AS es2 ON (es.GuidValue = es2.Guid)
				
		DECLARE	@ServiceQuoteList AS SCore.ThreeGuidUniqueList,	
				@CurrentQuote UNIQUEIDENTIFIER,
				@NewQuoteGuid UNIQUEIDENTIFIER,
				@MaxQuote UNIQUEIDENTIFIER

		INSERT	@ServiceQuoteList
			 (GuidValue, GuidValueTwo, GuidValueThree)
		SELECT	q.Guid,
				NEWID(),
				es2.GuidValueTwo
		FROM	SSop.Quotes AS q
		JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
		JOIN	@EnquiryServices AS es2 ON (es.Guid = es2.GuidValue)


		INSERT @NewGuidList
				(
					GuidValue
				)
			SELECT
					GuidValueTwo
			FROM
					@EnquiryServices

		EXEC SCore.DataObjectBulkUpsert
			@GuidList   = @NewGuidList,				-- GuidUniqueList
			@SchemeName = N'SSop',				-- nvarchar(255)
			@ObjectName = N'EnquiryServices',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit	

		DELETE FROM
		@NewGuidList	
		
		SELECT	@MaxQuote = MAX(GuidValue),
				@CurrentQuote = '00000000-0000-0000-0000-000000000000'
		FROM	@ServiceQuoteList AS tgul

		WHILE	@CurrentQuote < @MaxQuote
		BEGIN 
			SELECT	@CurrentQuote = GuidValue,
					@NewQuoteGuid = GuidValueTwo
			FROM	@ServiceQuoteList
			WHERE	(GuidValue > @CurrentQuote)
			ORDER BY	GuidValue

			EXEC SSop.QuotesDuplicate @SourceGuid = @CurrentQuote,	-- uniqueidentifier
									  @TargetGuid = @NewQuoteGuid	-- uniqueidentifier

			UPDATE	q
			SET		EnquiryServiceId = es.ID
			FROM	SSop.Quotes AS q
			JOIN	@ServiceQuoteList AS ql ON (q.Guid = ql.GuidValueTwo)
			JOIN	SSop.EnquiryServices AS es ON (es.Guid = ql.GuidValueThree)
			
		END

		DECLARE	@UserID INT = SCore.GetCurrentUserId(),
				@NewValue NVARCHAR(500) = N'Duplicated from ' + @SourceNumber

		INSERT	SCore.RecordHistory
			 (Guid,
			  RowStatus,
			  SchemaName,
			  TableName,
			  ColumnName,
			  RowID,
			  RowGuid,
			  Datetime,
			  UserID,
			  SQLUser,
			  PreviousValue,
			  NewValue,
			  EntityPropertyID)
		VALUES
			 (
				 NEWID(),	-- Guid - uniqueidentifier
				 1,	-- RowStatus - tinyint
				 N'SSop',	-- SchemaName - nvarchar(250)
				 N'Enquiries',	-- TableName - nvarchar(250)
				 N'',	-- ColumnName - nvarchar(250)
				 @ID,	-- RowID - bigint
				 @TargetGuid,	-- RowGuid - uniqueidentifier
				 GETUTCDATE(),	-- Datetime - datetime
				 @UserID,	-- UserID - int
				 N'',	-- SQLUser - nvarchar(250)
				 N'',	-- PreviousValue - nvarchar(max)
				 @NewValue,	-- NewValue - nvarchar(max)
				 -1	-- EntityPropertyID - int
			 )
	

		-- Allocate a new Enquiry number. 

		DECLARE @EnquiryNumber NVARCHAR(30);

		SELECT
				@EnquiryNumber = NEXT VALUE FOR SSop.EnquiryNumber;

		UPDATE  SSop.Enquiries
		SET		Number = @EnquiryNumber,
				RowStatus = 1
		WHERE
			(ID = @ID);
	END;
GO
GO

/* Deploy Function SSop.tvf_QuotesValidate using CanonicalAlter from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Programmability\Functions\SSop.tvf_QuotesValidate.sql */
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_QuotesValidate]')
GO

CREATE OR ALTER FUNCTION [SSop].[tvf_QuotesValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @DateSent DATE,
    @DeadDate DATE,
    @DateRejected DATE,
    @IsFinal BIT,
    @RevisionNumber INT,
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @DateDeclinedToQuote DATE,
    @DeclinedToQuoteReason NVARCHAR(MAX),
    @ContractGuid UNIQUEIDENTIFIER,
    @AgentContractGuid UNIQUEIDENTIFIER
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    IsInformationOnly BIT NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE @EntityTypeGuid UNIQUEIDENTIFIER = '1c4794c1-f956-4c32-b886-5500ac778a56';
    DECLARE @Final      BIT = 0;
    DECLARE @IsSent     BIT = 0;
    DECLARE @IsAccepted BIT = 0;
    DECLARE @IsRejected BIT = 0;
    DECLARE @IsDead     BIT = 0;
    DECLARE @IsReopened BIT = 0;
    DECLARE @ReadyForQuote UNIQUEIDENTIFIER = 'EB867FA0-9608-4CC7-93BE-CC8E8140E8F0';
    -- Ready to Send (replaces legacy IsFinal checkbox meaning)
    DECLARE @FinalStatus    UNIQUEIDENTIFIER = '02A2237F-2AE7-4E05-926F-38E8B7D050A0';
    -- Corrected GUIDs
    DECLARE @SentStatus     UNIQUEIDENTIFIER = '25D5491C-42A8-4B04-B3AC-D648AF0F8032';
    DECLARE @AcceptedStatus UNIQUEIDENTIFIER = '21A29AEE-2D99-4DA3-8182-F31813B0C498';
    DECLARE @RejectedStatus UNIQUEIDENTIFIER = '0A6A71F7-B39F-4213-997E-2B3A13B6144C';
    DECLARE @DeadStatus     UNIQUEIDENTIFIER = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';
    DECLARE @Reopened UNIQUEIDENTIFIER;

    -- Make deterministic + rowstatus-safe (optional but recommended)
    SELECT TOP (1) @Reopened = Guid
    FROM SCore.WorkflowStatus
    WHERE RowStatus NOT IN (0,254)
      AND Name LIKE N'%Reopened%'
    ORDER BY ID;
    -------------------------------------------------------------------------
    -- Determine flags based on the LATEST workflow transition for this Quote (latest-only)
    -------------------------------------------------------------------------
DECLARE
      @LatestWorkflowStatusGuid UNIQUEIDENTIFIER = NULL
    , @LatestIsActiveStatus     BIT              = NULL
    , @LatestIsCompleteStatus   BIT              = NULL;
 
	;WITH LatestEffective AS
	(
		SELECT TOP (1)
			  wfs.Guid             AS LatestWorkflowStatusGuid
			, wfs.IsActiveStatus   AS LatestIsActiveStatus
			, wfs.IsCompleteStatus AS LatestIsCompleteStatus
		FROM SCore.DataObjectTransition dot
		JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
		WHERE dot.RowStatus NOT IN (0,254)
		  AND wfs.RowStatus NOT IN (0,254)
		  AND dot.DataObjectGuid = @Guid
		ORDER BY
			dot.ID DESC
	)
	SELECT
		  @LatestWorkflowStatusGuid = LatestWorkflowStatusGuid
		, @LatestIsActiveStatus     = LatestIsActiveStatus
		, @LatestIsCompleteStatus   = LatestIsCompleteStatus
	FROM LatestEffective;

    -- Latest-only flags
    SET @Final      = CASE WHEN @LatestWorkflowStatusGuid = @FinalStatus    THEN 1 ELSE 0 END;
    SET @IsSent     = CASE WHEN @LatestWorkflowStatusGuid = @SentStatus     THEN 1 ELSE 0 END;
    SET @IsAccepted = CASE WHEN @LatestWorkflowStatusGuid = @AcceptedStatus THEN 1 ELSE 0 END;
    SET @IsRejected = CASE WHEN @LatestWorkflowStatusGuid = @RejectedStatus THEN 1 ELSE 0 END;
    SET @IsDead     = CASE WHEN @LatestWorkflowStatusGuid = @DeadStatus     THEN 1 ELSE 0 END;
    SET @IsReopened = CASE WHEN @LatestWorkflowStatusGuid = @Reopened       THEN 1 ELSE 0 END;
    -------------------------------------------------------------------------
    -- Prevent changing Quote if Enquiry not ready for quote review
    -------------------------------------------------------------------------

	/*
		Additional check for reopened status. 

		=======================================================================================
		= SET @IsReopened = CASE WHEN @LatestWorkflowStatusGuid = @Reopenen THEN 1 ELSE 0 END =
		=======================================================================================

		The above is based on the last available status. Currently, if we reopen a quote,
		it first assigns "Reopened" and then immediately after that "Quoting". Aka, it would fail.


	*/
	IF(@IsReopened = 0)
	BEGIN

		IF(EXISTS
				(
					SELECT 1  
					FROM SCore.DataObjectTransition AS Dob
					JOIN SCore.WorkflowStatus AS wfs ON (Dob.StatusID = wfs.ID)
					WHERE 
								(Dob.RowStatus NOT IN (0, 254))
							AND (wfs.RowStatus NOT IN (0,254))
							AND (Dob.DataObjectGuid = @Guid)
							AND (
										wfs.Guid = '9A60F983-24BA-4733-907E-C5CCE0B691CB' --Quoting
									OR  wfs.Guid = '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD' --Reopened
								)
							AND (
										dob.Comment LIKE N'%Reopened quote returned to quoting.%'
									OR  dob.Comment LIKE N'%System Imported%'
								)
							AND NOT EXISTS
								(
									SELECT 1  
									FROM SCore.DataObjectTransition AS Dob2
									JOIN SCore.WorkflowStatus AS wfs2 ON (Dob2.StatusID = wfs2.ID)
									WHERE 
											(Dob2.RowStatus NOT IN (0, 254))
										AND (wfs2.RowStatus NOT IN (0, 254))
										AND (Dob2.DataObjectGuid = @Guid )
										AND (Dob2.ID > Dob.ID)
								)
				)
		  )

		  SET @IsReopened = 1
		
	 END;



    IF EXISTS
    (
        SELECT 1
        FROM SSop.Quotes q
        JOIN SSop.EnquiryServices es ON es.ID = q.EnquiryServiceID
        JOIN SSop.Enquiries e ON e.ID = es.EnquiryId
        WHERE q.Guid = @Guid
          AND e.IsReadyForQuoteReview = 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.DataObjectTransition dob
              JOIN SCore.WorkflowStatus wfs ON dob.StatusID = wfs.ID
              WHERE dob.RowStatus NOT IN (0,254)
                AND wfs.RowStatus NOT IN (0,254)
                AND dob.DataObjectGuid = e.Guid
                AND wfs.Guid = @ReadyForQuote
          )
    )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT ep.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityProperties ep
        JOIN SCore.EntityHobts eh ON eh.ID = ep.EntityHoBTID
        JOIN SCore.EntityTypes et ON et.ID = eh.EntityTypeID
        WHERE et.Name = N'Quotes';
        RETURN;
    END;

    -------------------------------------------------------------------------
    -- CYB-317
    -- Lock superseded quote revisions.
    -- Only the latest active revision in a quote chain remains editable.
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SSop.Quotes AS qCurrent
        JOIN SSop.Quotes AS qOther
            ON qOther.RowStatus NOT IN (0,254)
           AND qOther.Number = qCurrent.Number
           AND ISNULL(qOther.OriginalQuoteId, -1) =
               CASE
                   WHEN qCurrent.OriginalQuoteId = -1 THEN qCurrent.ID
                   ELSE qCurrent.OriginalQuoteId
               END
           AND qOther.RevisionNumber > qCurrent.RevisionNumber
        WHERE qCurrent.Guid = @Guid
          AND qCurrent.RowStatus NOT IN (0,254)
    )
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfvv.Guid,
            N'P',
            1,
            0,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt IN (N'Quotes', N'Quote_ExtendedInfo');

        RETURN;
    END;

    -------------------------------------------------------------------------
    -- Lock quote when jobs exist or dead
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SSop.QuoteItems qi
        JOIN SSop.Quotes q ON q.ID = qi.QuoteId
        WHERE q.Guid = @Guid
          AND qi.RowStatus NOT IN (0,254)
          AND qi.CreatedJobId > 0
		  AND @IsReopened = 0
		  
    ) 
    OR ((@IsDead = 1 OR @DeadDate IS NOT NULL) AND @IsReopened = 0)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        VALUES (@EntityTypeGuid, N'E', 1, 0, 0, N'');
        RETURN;
    END;

    -------------------------------------------------------------------------
    -- CDM FeeCap hide
    -------------------------------------------------------------------------
	IF(@IsReopened = 0)
	BEGIN
		IF EXISTS
		(
			SELECT 1
			FROM SCore.OrganisationalUnits ou
			WHERE ou.Guid = @OrganisationalUnitGuid
			  AND ou.Name LIKE N'CDM%'
			  AND ou.RowStatus NOT IN (0,254)
		)
		BEGIN
			INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid, N'P', 0, 1, 0, N''
			FROM SCore.EntityPropertiesForValidationV epfvv
			WHERE epfvv.[Schema] = N'SSop'
			  AND epfvv.Hobt = N'Quotes'
			  AND epfvv.Name = N'FeeCap';
		END;
	END;
    -------------------------------------------------------------------------
    -- RevisionNumber rule
    -------------------------------------------------------------------------
    IF (@RevisionNumber < 1)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'RevisionNumber';
    END;
    -------------------------------------------------------------------------
    -- Don’t allow progress beyond Send until quote is Sent
    -------------------------------------------------------------------------
    IF ((@DateSent IS NULL) AND (@IsSent = 0))
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name IN (N'DateAccepted', N'DateRejected', N'RejectionReason', N'ChaseDate1', N'ChaseDate2');
    END;
    -------------------------------------------------------------------------
    -- Sent => IsFinal locked (legacy field still locked, but NO net error now)
    ---------------------------------------------------------------------------
    IF ((@IsSent = 1) OR (@DateSent IS NOT NULL))
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'IsFinal';
    END;
    -------------------------------------------------------------------------
    -- Block DateSent until workflow status is Ready to Send
    -------------------------------------------------------------------------
    IF (@Final = 0)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'DateSent';
    END;
    -------------------------------------------------------------------------
    -- Rejected locking (latest-only + reopen exception)
    -------------------------------------------------------------------------
    IF (((@IsRejected = 1) OR (@DateRejected IS NOT NULL)) AND @IsReopened = 0)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes';
    END;
    -------------------------------------------------------------------------
    -- Hide AgentContractID if ContractID set, and vice versa
    -------------------------------------------------------------------------
    IF (@ContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 0, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'AgentContractID';
    END
    ELSE IF (@AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 0, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'ContractID';
    END;
    -------------------------------------------------------------------------
    -- Final/Ready-to-Send lockdown of fields (KEEP) but NO net value error here
    -------------------------------------------------------------------------
    IF (@Final = 1)
       AND NOT EXISTS
       (
           SELECT 1
           FROM SSop.Quotes q
           WHERE q.Guid = @Guid
             AND q.LegacyId IS NOT NULL
             AND
             (
                 q.OrganisationalUnitID  < 0
              OR q.QuotingUserId         < 0
              OR q.QuotingConsultantId   < 0
             )
       )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name NOT IN
          (
              N'ChaseDate2', N'ChaseDate1', N'RejectionReason', N'DateRejected', N'DateAccepted',
              N'IsFinal', N'DateSent'
          );
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quote_ExtendedInfo';
    END;
    -------------------------------------------------------------------------
    -- Complete-status lock (latest-only)
    -------------------------------------------------------------------------
    IF (@LatestIsCompleteStatus = 1 AND @IsReopened = 0 )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt     = N'Quotes';
    END;
    RETURN;
END;

GO
GO
EXEC [SCore].[PostDeploymentScript];
GO
