#nullable enable

using System;
using System.Collections.Generic;
using System.Data;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;

namespace Concursus.EF.Finance
{
    /// <summary>
    /// Read-side repository for the approved transaction -> Sage submission flow.
    ///
    /// Responsibilities:
    /// - deserialize the outbox payload
    /// - load a deterministic transaction read model
    /// - load deterministic line models for downstream wrapper mapping
    ///
    /// This repository intentionally performs reads only.
    /// </summary>
    public sealed class TransactionToSageReadRepository : ITransactionToSageReadRepository
    {
        private readonly Core _core;

        public TransactionToSageReadRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        /// <summary>
        /// Attempts to deserialize an outbox payload into the approved transaction event model.
        /// Returns null when the payload is empty or invalid.
        /// </summary>
        public TransactionApprovedForSageSubmissionEvent? DeserializeApprovedTransactionEvent(string payloadJson)
        {
            if (string.IsNullOrWhiteSpace(payloadJson))
            {
                return null;
            }

            try
            {
                return JsonSerializer.Deserialize<TransactionApprovedForSageSubmissionEvent>(payloadJson);
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Loads the full approved transaction read model for Sage submission using the transition guid.
        /// </summary>
        public async Task<ApprovedTransactionForSageReadModel?> GetApprovedTransactionForSageAsync(
            Guid transactionBatchTransitionGuid,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken);

            var header = await LoadHeaderAsync(connection, transactionBatchTransitionGuid, cancellationToken);

            if (header is null)
            {
                return null;
            }

            header.Lines = await LoadLinesAsync(
                connection,
                header.TransactionId,
                header.JobId,
                cancellationToken);

            return header;
        }

        /// <summary>
        /// Loads the transaction/header data for the supplied transition guid.
        /// </summary>
        private static async Task<ApprovedTransactionForSageReadModel?> LoadHeaderAsync(
            SqlConnection connection,
            Guid transitionGuid,
            CancellationToken cancellationToken)
        {
            const string sql = """
SELECT TOP (1)
       tbt.Guid                                                   AS TransitionGuid,
       CONVERT(bigint, tbt.ID)                                    AS TransitionId,
       tbt.DateTimeUTC                                            AS TransitionOccurredOnUtc,

       t.Guid                                                     AS TransactionGuid,
       CONVERT(bigint, t.ID)                                      AS TransactionId,
       CAST(ISNULL(t.Number, N'') AS nvarchar(100))               AS TransactionNumber,
       CAST(t.Batched AS bit)                                     AS Batched,
       t.RowStatus                                                AS TransactionRowStatus,

       t.JobID                                                    AS JobId,
       j.Guid                                                     AS JobGuid,
       CAST(ISNULL(j.Number, N'') AS nvarchar(100))               AS JobNumber,
       CAST(ISNULL(j.JobDescription, N'') AS nvarchar(500))       AS JobDescription,

       t.AccountID                                                AS AccountId,
       t.OrganisationalUnitId                                     AS OrganisationalUnitId,

       CAST(t.[Date] AS datetime2(7))                             AS TransactionDateUtc,
       CAST(t.ExpectedDate AS datetime2(7))                       AS ExpectedDateUtc,

       CAST(ISNULL(t.Number, N'') AS nvarchar(100))               AS InvoiceNumber,
       CAST(ISNULL(t.SageTransactionReference, N'') AS nvarchar(100)) AS ExistingSageReference,
       CAST(ISNULL(t.PurchaseOrderNumber, N'') AS nvarchar(100))  AS PurchaseOrderNumber,

       CAST(ISNULL(acc.Name, N'') AS nvarchar(250))               AS CustomerName,
       CAST(ISNULL(acc.Code, N'') AS nvarchar(100))               AS SageCustomerReference,
       CAST(N'' AS nvarchar(250))                                 AS CustomerEmail,
       CAST(N'' AS nvarchar(250))                                 AS CustomerContactName,

       CAST(N'' AS nvarchar(250))                                 AS BillingAddressLine1,
       CAST(N'' AS nvarchar(250))                                 AS BillingAddressLine2,
       CAST(N'' AS nvarchar(250))                                 AS BillingAddressLine3,
       CAST(N'' AS nvarchar(100))                                 AS BillingTown,
       CAST(N'' AS nvarchar(100))                                 AS BillingCounty,
       CAST(N'' AS nvarchar(50))                                  AS BillingPostCode,
       CAST(N'' AS nvarchar(100))                                 AS BillingCountry,

       CAST(ISNULL(detailAgg.NetAmount, 0.00)   AS decimal(18, 2))   AS NetAmount,
       CAST(ISNULL(detailAgg.VatAmount, 0.00)   AS decimal(18, 2))   AS VatAmount,
       CAST(ISNULL(detailAgg.GrossAmount, 0.00) AS decimal(18, 2))   AS GrossAmount,

       CAST(N'GBP' AS nvarchar(10))                               AS CurrencyCode,

       tbt.CreatedByUserId                                        AS ActorIdentityId,
       t.SurveyorUserId                                           AS SurveyorIdentityId,
       CAST(ISNULL(tbt.Comment, N'') AS nvarchar(max))            AS ApprovalComment
FROM   SFin.TransactionBatchTransitions AS tbt
JOIN   SFin.Transactions AS t
       ON t.ID = tbt.TransactionID
      AND t.Guid = tbt.TransactionGuid
LEFT JOIN SCrm.Accounts AS acc
       ON acc.ID = t.AccountID
      AND acc.RowStatus NOT IN (0, 254)
LEFT JOIN SJob.Jobs AS j
       ON j.ID = t.JobID
      AND j.RowStatus NOT IN (0, 254)
LEFT JOIN
(
    SELECT td.TransactionID,
           SUM(td.Net)   AS NetAmount,
           SUM(td.Vat)   AS VatAmount,
           SUM(td.Gross) AS GrossAmount
    FROM   SFin.TransactionDetails AS td
    WHERE  td.RowStatus NOT IN (0, 254)
    GROUP BY td.TransactionID
) AS detailAgg
       ON detailAgg.TransactionID = t.ID
WHERE  tbt.Guid = @TransitionGuid
  AND  tbt.RowStatus NOT IN (0, 254)
  AND  t.RowStatus NOT IN (0, 254);
""";

            await using var command = QueryBuilder.CreateCommand(sql, connection, transaction: null);
            command.CommandType = CommandType.Text;
            command.Parameters.Add(new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transitionGuid
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            if (!await reader.ReadAsync(cancellationToken))
            {
                return null;
            }

            return new ApprovedTransactionForSageReadModel
            {
                TransitionGuid = reader.GetGuid(reader.GetOrdinal("TransitionGuid")),
                TransitionId = reader.GetInt64(reader.GetOrdinal("TransitionId")),
                TransitionOccurredOnUtc = reader.GetDateTime(reader.GetOrdinal("TransitionOccurredOnUtc")),

                TransactionGuid = reader.GetGuid(reader.GetOrdinal("TransactionGuid")),
                TransactionId = reader.GetInt64(reader.GetOrdinal("TransactionId")),
                TransactionNumber = reader.GetString(reader.GetOrdinal("TransactionNumber")),
                Batched = reader.GetBoolean(reader.GetOrdinal("Batched")),
                RowStatus = reader.GetByte(reader.GetOrdinal("TransactionRowStatus")),

                JobId = reader.IsDBNull(reader.GetOrdinal("JobId"))
                    ? null
                    : reader.GetInt32(reader.GetOrdinal("JobId")),
                JobGuid = reader.IsDBNull(reader.GetOrdinal("JobGuid"))
                    ? null
                    : reader.GetGuid(reader.GetOrdinal("JobGuid")),
                JobNumber = reader.GetString(reader.GetOrdinal("JobNumber")),
                JobDescription = reader.GetString(reader.GetOrdinal("JobDescription")),

                AccountId = reader.IsDBNull(reader.GetOrdinal("AccountId"))
                    ? null
                    : reader.GetInt32(reader.GetOrdinal("AccountId")),
                OrganisationalUnitId = reader.IsDBNull(reader.GetOrdinal("OrganisationalUnitId"))
                    ? null
                    : reader.GetInt32(reader.GetOrdinal("OrganisationalUnitId")),

                TransactionDateUtc = reader.IsDBNull(reader.GetOrdinal("TransactionDateUtc"))
                    ? null
                    : reader.GetDateTime(reader.GetOrdinal("TransactionDateUtc")),
                ExpectedDateUtc = reader.IsDBNull(reader.GetOrdinal("ExpectedDateUtc"))
                    ? null
                    : reader.GetDateTime(reader.GetOrdinal("ExpectedDateUtc")),

                InvoiceNumber = reader.GetString(reader.GetOrdinal("InvoiceNumber")),
                ExistingSageReference = reader.GetString(reader.GetOrdinal("ExistingSageReference")),
                PurchaseOrderNumber = reader.GetString(reader.GetOrdinal("PurchaseOrderNumber")),

                CustomerName = reader.GetString(reader.GetOrdinal("CustomerName")),
                SageCustomerReference = reader.GetString(reader.GetOrdinal("SageCustomerReference")),
                CustomerEmail = reader.GetString(reader.GetOrdinal("CustomerEmail")),
                CustomerContactName = reader.GetString(reader.GetOrdinal("CustomerContactName")),

                BillingAddressLine1 = reader.GetString(reader.GetOrdinal("BillingAddressLine1")),
                BillingAddressLine2 = reader.GetString(reader.GetOrdinal("BillingAddressLine2")),
                BillingAddressLine3 = reader.GetString(reader.GetOrdinal("BillingAddressLine3")),
                BillingTown = reader.GetString(reader.GetOrdinal("BillingTown")),
                BillingCounty = reader.GetString(reader.GetOrdinal("BillingCounty")),
                BillingPostCode = reader.GetString(reader.GetOrdinal("BillingPostCode")),
                BillingCountry = reader.GetString(reader.GetOrdinal("BillingCountry")),

                NetAmount = reader.GetDecimal(reader.GetOrdinal("NetAmount")),
                VatAmount = reader.GetDecimal(reader.GetOrdinal("VatAmount")),
                GrossAmount = reader.GetDecimal(reader.GetOrdinal("GrossAmount")),
                CurrencyCode = reader.GetString(reader.GetOrdinal("CurrencyCode")),

                ActorIdentityId = reader.IsDBNull(reader.GetOrdinal("ActorIdentityId"))
                    ? null
                    : reader.GetInt32(reader.GetOrdinal("ActorIdentityId")),
                SurveyorIdentityId = reader.IsDBNull(reader.GetOrdinal("SurveyorIdentityId"))
                    ? null
                    : reader.GetInt32(reader.GetOrdinal("SurveyorIdentityId")),
                ApprovalComment = reader.GetString(reader.GetOrdinal("ApprovalComment"))
            };
        }

        /// <summary>
        /// Loads line/detail rows for the approved transaction.
        ///
        /// Finance mapping rule applied here:
        /// - NominalCode remains config-driven in appsettings (default 31010)
        /// - VatCode remains config-driven in appsettings (default 22)
        /// - CostCentreCode and DepartmentCode come from the Job OrganisationalUnit
        ///   via SCore.OrganisationalUnits.CostCentreCode
        /// - Expected format is PART1-PART2, e.g. BBS-CDM
        ///     PART1 -> CostCentreCode
        ///     PART2 -> DepartmentCode
        /// </summary>
        private static async Task<List<ApprovedTransactionForSageLineReadModel>> LoadLinesAsync(
            SqlConnection connection,
            long transactionId,
            int? jobId,
            CancellationToken cancellationToken)
        {
            const string sql = """
SELECT td.ID                               AS LineId,
       td.Guid                             AS LineGuid,
       td.RowStatus                        AS RowStatus,
       CAST(td.ID AS nvarchar(50))         AS LineReference,
       td.[Description]                    AS [Description],
       CAST(N'' AS nvarchar(100))          AS ProductCode,
       CAST(1 AS decimal(18, 2))           AS Quantity,
       td.Net                              AS UnitPrice,
       td.Net                              AS NetAmount,
       td.Vat                              AS VatAmount,
       td.Gross                            AS GrossAmount,
       CAST(N'' AS nvarchar(20))           AS VatCode,
       CAST(N'' AS nvarchar(50))           AS NominalCode,
       CAST(
            CASE
                WHEN ou.CostCentreCode IS NULL OR ou.CostCentreCode = N'' THEN N''
                WHEN CHARINDEX(N'-', ou.CostCentreCode) > 0
                    THEN LEFT(ou.CostCentreCode, CHARINDEX(N'-', ou.CostCentreCode) - 1)
                ELSE ou.CostCentreCode
            END
            AS nvarchar(50)
       )                                   AS CostCentreCode,
       CAST(
            CASE
                WHEN ou.CostCentreCode IS NULL OR ou.CostCentreCode = N'' THEN N''
                WHEN CHARINDEX(N'-', ou.CostCentreCode) > 0
                    THEN SUBSTRING(
                            ou.CostCentreCode,
                            CHARINDEX(N'-', ou.CostCentreCode) + 1,
                            LEN(ou.CostCentreCode))
                ELSE N''
            END
            AS nvarchar(50)
       )                                   AS DepartmentCode,
       CAST(NULL AS bigint)                AS InvoiceRequestItemId,
       CAST(NULL AS bigint)                AS ActivityId,
       CAST(NULL AS bigint)                AS MilestoneId,
       CAST(N'' AS nvarchar(100))          AS JobPaymentStageName,
       CAST(N'' AS nvarchar(50))           AS LineType,
       CAST(NULL AS datetime2(7))          AS ServiceDateUtc
FROM   SFin.TransactionDetails AS td
LEFT JOIN SJob.Jobs AS j
       ON j.ID = @JobId
      AND j.RowStatus NOT IN (0, 254)
LEFT JOIN SCore.OrganisationalUnits AS ou
       ON ou.ID = j.OrganisationalUnitID
      AND ou.RowStatus NOT IN (0, 254)
WHERE  td.TransactionID = @TransactionId
  AND  td.RowStatus NOT IN (0, 254)
ORDER BY td.ID ASC;
""";

            var results = new List<ApprovedTransactionForSageLineReadModel>();

            await using var command = QueryBuilder.CreateCommand(sql, connection, transaction: null);
            command.CommandType = CommandType.Text;
            command.Parameters.Add(new SqlParameter("@TransactionId", SqlDbType.BigInt)
            {
                Value = transactionId
            });
            command.Parameters.Add(new SqlParameter("@JobId", SqlDbType.Int)
            {
                Value = (object?)jobId ?? DBNull.Value
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            while (await reader.ReadAsync(cancellationToken))
            {
                results.Add(new ApprovedTransactionForSageLineReadModel
                {
                    LineId = reader.GetInt64(reader.GetOrdinal("LineId")),
                    LineGuid = reader.IsDBNull(reader.GetOrdinal("LineGuid"))
                        ? null
                        : reader.GetGuid(reader.GetOrdinal("LineGuid")),
                    RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                    LineReference = reader.GetString(reader.GetOrdinal("LineReference")),
                    Description = reader.GetString(reader.GetOrdinal("Description")),
                    ProductCode = reader.GetString(reader.GetOrdinal("ProductCode")),
                    Quantity = reader.GetDecimal(reader.GetOrdinal("Quantity")),
                    UnitPrice = reader.GetDecimal(reader.GetOrdinal("UnitPrice")),
                    NetAmount = reader.GetDecimal(reader.GetOrdinal("NetAmount")),
                    VatAmount = reader.GetDecimal(reader.GetOrdinal("VatAmount")),
                    GrossAmount = reader.GetDecimal(reader.GetOrdinal("GrossAmount")),
                    VatCode = reader.GetString(reader.GetOrdinal("VatCode")),
                    NominalCode = reader.GetString(reader.GetOrdinal("NominalCode")),
                    CostCentreCode = reader.GetString(reader.GetOrdinal("CostCentreCode")),
                    DepartmentCode = reader.GetString(reader.GetOrdinal("DepartmentCode")),
                    InvoiceRequestItemId = reader.IsDBNull(reader.GetOrdinal("InvoiceRequestItemId"))
                        ? null
                        : reader.GetInt64(reader.GetOrdinal("InvoiceRequestItemId")),
                    ActivityId = reader.IsDBNull(reader.GetOrdinal("ActivityId"))
                        ? null
                        : reader.GetInt64(reader.GetOrdinal("ActivityId")),
                    MilestoneId = reader.IsDBNull(reader.GetOrdinal("MilestoneId"))
                        ? null
                        : reader.GetInt64(reader.GetOrdinal("MilestoneId")),
                    JobPaymentStageName = reader.GetString(reader.GetOrdinal("JobPaymentStageName")),
                    LineType = reader.GetString(reader.GetOrdinal("LineType")),
                    ServiceDateUtc = reader.IsDBNull(reader.GetOrdinal("ServiceDateUtc"))
                        ? null
                        : reader.GetDateTime(reader.GetOrdinal("ServiceDateUtc"))
                });
            }

            return results;
        }
    }
}