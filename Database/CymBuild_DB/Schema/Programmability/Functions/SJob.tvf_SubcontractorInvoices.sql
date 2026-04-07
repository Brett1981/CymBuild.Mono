SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_SubcontractorInvoices]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
(
	WITH VisibleInvoices AS
	(
		SELECT  
				si.ID,
				si.Guid,
				si.RowVersion,
				si.RowStatus,
				si.SubContractorName,
				si.DescriptionOfWork,
				si.InvoiceDate,
				si.ValueWithVAT,
				si.ValueWithoutVAT,
				CAST(NULL AS DECIMAL(18,2)) AS NetFee,
				CAST(NULL AS DECIMAL(18,2)) AS Margin
		FROM    SJob.SubContractorInvoices AS si
		JOIN    SJob.Jobs AS j 
				ON j.ID = si.JobId
		WHERE   si.RowStatus NOT IN (0, 254)
			AND si.ID > 0
			AND j.Guid = @ParentGuid
			AND EXISTS
			(
				SELECT 1
				FROM SCore.ObjectSecurityForUser_CanRead (si.Guid, @UserId)
			)
	)

	/* Detail rows */
	SELECT
			ID,
			Guid,
			RowVersion,
			RowStatus,
			SubContractorName,
			DescriptionOfWork,
			InvoiceDate,
			ValueWithVAT,
			ValueWithoutVAT,
			NetFee,
			Margin
	FROM VisibleInvoices

	UNION ALL

	/* Total row */
	SELECT
			-1 AS ID,
			MIN(vi.Guid) AS Guid,
			NULL AS RowVersion,
			1 AS RowStatus,
			N'Total' AS SubContractorName,
			N'' AS DescriptionOfWork,
			NULL AS InvoiceDate,

			/* Total subcontractor cost */
			SUM(vi.ValueWithVAT) AS ValueWithVAT,
			SUM(vi.ValueWithoutVAT) AS ValueWithoutVAT,

			/* Adjusted net fee (Total ex. Fee Cap) */
			MAX(jfd.Agreed) + SUM(vi.ValueWithoutVAT) AS NetFee,

			/* Remaining margin */
			MAX(jfd.Remaining) - SUM(vi.ValueWithoutVAT) AS Margin
	FROM VisibleInvoices vi
	JOIN SJob.Jobs j
		ON j.Guid = @ParentGuid
	JOIN SJob.Job_FeeDrawdown jfd
		ON jfd.JobId = j.ID
		AND jfd.StageId = -2   -- Total (ex. Fee Cap)
);



GO