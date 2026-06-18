#nullable enable

using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Security.Claims;

namespace Concursus.EF.Finance
{
    public sealed class TransactionInvoicePreviewRepository : ITransactionInvoicePreviewRepository
    {
        private readonly Core _core;

        public TransactionInvoicePreviewRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        public async Task<string> ReserveInvoiceNumberAsync(Guid transactionGuid, CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[TransactionReserveInvoiceNumber]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid });

            var output = new SqlParameter("@ReservedInvoiceNumber", SqlDbType.NVarChar, 30)
            {
                Direction = ParameterDirection.Output
            };

            command.Parameters.Add(output);
            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);

            return Convert.ToString(output.Value) ?? string.Empty;
        }

        public async Task<TransactionInvoicePreviewInfo?> GetCurrentAsync(Guid transactionGuid, CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[TransactionInvoicePreviewCurrentGet]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                return null;

            return new TransactionInvoicePreviewInfo
            {
                Id = reader.GetInt64(reader.GetOrdinal("ID")),
                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                TransactionGuid = transactionGuid,
                ReservedInvoiceNumber = reader.GetString(reader.GetOrdinal("InvoiceNumberReserved")),
                SharePointDriveId = reader.GetString(reader.GetOrdinal("SharePointDriveId")),
                SharePointItemId = reader.GetString(reader.GetOrdinal("SharePointItemId")),
                SharePointWebUrl = reader.GetString(reader.GetOrdinal("SharePointWebUrl")),
                Filename = reader.GetString(reader.GetOrdinal("Filename")),
                MimeType = reader.GetString(reader.GetOrdinal("MimeType")),
                FileHash = reader.GetString(reader.GetOrdinal("FileHash")),
                SourceTransactionRowVersion = (byte[])reader[reader.GetOrdinal("SourceTransactionRowVersion")],
                GeneratedDateTimeUtc = reader.GetDateTime(reader.GetOrdinal("GeneratedDateTimeUtc")),
                IsCurrent = reader.GetBoolean(reader.GetOrdinal("IsCurrent")),
                IsPostedToSage = reader.GetBoolean(reader.GetOrdinal("IsPostedToSage"))
            };
        }

        public async Task InsertPreviewAsync(
    Guid transactionGuid,
    Guid mergeDocumentGuid,
    string reservedInvoiceNumber,
    string sharePointDriveId,
    string sharePointItemId,
    string sharePointWebUrl,
    string filename,
    string mimeType,
    string fileHash,
    int generatedByUserId,
    CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
                throw new ArgumentException("A valid transaction guid is required.", nameof(transactionGuid));

            if (mergeDocumentGuid == Guid.Empty)
                throw new ArgumentException("A valid merge document guid is required.", nameof(mergeDocumentGuid));

            if (string.IsNullOrWhiteSpace(reservedInvoiceNumber))
                throw new ArgumentException("A reserved invoice number is required.", nameof(reservedInvoiceNumber));

            if (string.IsNullOrWhiteSpace(sharePointDriveId))
                throw new ArgumentException("A SharePoint drive id is required.", nameof(sharePointDriveId));

            if (string.IsNullOrWhiteSpace(sharePointItemId))
                throw new ArgumentException("A SharePoint item id is required.", nameof(sharePointItemId));

            if (string.IsNullOrWhiteSpace(sharePointWebUrl))
                throw new ArgumentException("A SharePoint web url is required.", nameof(sharePointWebUrl));

            if (string.IsNullOrWhiteSpace(filename))
                throw new ArgumentException("A filename is required.", nameof(filename));

            if (string.IsNullOrWhiteSpace(mimeType))
                throw new ArgumentException("A mime type is required.", nameof(mimeType));

            if (string.IsNullOrWhiteSpace(fileHash))
                throw new ArgumentException("A file hash is required.", nameof(fileHash));

            if (generatedByUserId <= 0)
                throw new ArgumentException("A valid generatedByUserId is required.", nameof(generatedByUserId));

            const string sql = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRAN;

DECLARE @PreviewGuid UNIQUEIDENTIFIER = NEWID();
DECLARE @TransactionId BIGINT;
DECLARE @MergeDocumentId INT;
DECLARE @EntityTypeId_TransactionInvoicePreviews INT;
DECLARE @SourceTransactionRowVersion VARBINARY(8);

SELECT TOP (1)
    @TransactionId = t.ID,
    @SourceTransactionRowVersion = t.RowVersion
FROM SFin.Transactions AS t
WHERE t.Guid = @TransactionGuid
  AND t.RowStatus NOT IN (0, 254);

IF @TransactionId IS NULL
BEGIN
    THROW 60050, N'Transaction could not be resolved for invoice preview insert.', 1;
END;

SELECT TOP (1)
    @MergeDocumentId = md.ID
FROM SCore.MergeDocuments AS md
WHERE md.Guid = @MergeDocumentGuid
  AND md.RowStatus NOT IN (0, 254);

IF @MergeDocumentId IS NULL
BEGIN
    THROW 60051, N'Merge document could not be resolved for invoice preview insert.', 1;
END;

SELECT TOP (1)
    @EntityTypeId_TransactionInvoicePreviews = eh.EntityTypeID
FROM SCore.EntityHobts AS eh
WHERE eh.RowStatus NOT IN (0, 254)
  AND eh.SchemaName = N'SFin'
  AND eh.ObjectName = N'TransactionInvoicePreviews';

IF @EntityTypeId_TransactionInvoicePreviews IS NULL
BEGIN
    THROW 60052, N'Entity type for SFin.TransactionInvoicePreviews could not be resolved from SCore.EntityHobts.', 1;
END;

INSERT INTO SCore.DataObjects
(
    Guid,
    RowStatus,
    EntityTypeId
)
VALUES
(
    @PreviewGuid,
    1,
    @EntityTypeId_TransactionInvoicePreviews
);

UPDATE SFin.TransactionInvoicePreviews
SET
    IsCurrent = 0
WHERE TransactionId = @TransactionId
  AND RowStatus NOT IN (0, 254)
  AND IsCurrent = 1;

INSERT INTO SFin.TransactionInvoicePreviews
(
    RowStatus,
    Guid,
    TransactionId,
    MergeDocumentId,
    InvoiceNumberReserved,
    SharePointDriveId,
    SharePointItemId,
    SharePointWebUrl,
    Filename,
    MimeType,
    FileHash,
    SourceTransactionRowVersion,
    GeneratedByUserId,
    GeneratedDateTimeUtc,
    IsCurrent,
    IsPostedToSage
)
VALUES
(
    1,
    @PreviewGuid,
    @TransactionId,
    @MergeDocumentId,
    @ReservedInvoiceNumber,
    @SharePointDriveId,
    @SharePointItemId,
    @SharePointWebUrl,
    @Filename,
    @MimeType,
    @FileHash,
    @SourceTransactionRowVersion,
    @GeneratedByUserId,
    SYSUTCDATETIME(),
    1,
    0
);

COMMIT TRAN;";

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid });
            command.Parameters.Add(new SqlParameter("@MergeDocumentGuid", SqlDbType.UniqueIdentifier) { Value = mergeDocumentGuid });
            command.Parameters.Add(new SqlParameter("@ReservedInvoiceNumber", SqlDbType.NVarChar, 30) { Value = reservedInvoiceNumber });
            command.Parameters.Add(new SqlParameter("@SharePointDriveId", SqlDbType.NVarChar, 200) { Value = sharePointDriveId });
            command.Parameters.Add(new SqlParameter("@SharePointItemId", SqlDbType.NVarChar, 200) { Value = sharePointItemId });
            command.Parameters.Add(new SqlParameter("@SharePointWebUrl", SqlDbType.NVarChar, 1000) { Value = sharePointWebUrl });
            command.Parameters.Add(new SqlParameter("@Filename", SqlDbType.NVarChar, 260) { Value = filename });
            command.Parameters.Add(new SqlParameter("@MimeType", SqlDbType.NVarChar, 100) { Value = mimeType });
            command.Parameters.Add(new SqlParameter("@FileHash", SqlDbType.NVarChar, 128) { Value = fileHash });
            command.Parameters.Add(new SqlParameter("@GeneratedByUserId", SqlDbType.Int) { Value = generatedByUserId });

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        public async Task<TransactionInvoicePostingGuardResult> GetPostingGuardAsync(Guid transactionGuid, CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[TransactionInvoicePreviewPostingGuardGet]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@TransactionGuid", transactionGuid);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return new TransactionInvoicePostingGuardResult
                {
                    TransactionGuid = transactionGuid,
                    BlockingReason = "Transaction not found."
                };
            }

            var result = new TransactionInvoicePostingGuardResult
            {
                TransactionGuid = transactionGuid,
                HasPreview = reader.GetBoolean(reader.GetOrdinal("HasPreview")),
                HasReservedInvoiceNumber = reader.GetBoolean(reader.GetOrdinal("HasReservedInvoiceNumber")),
                PreviewMatchesCurrentTransaction = reader.GetBoolean(reader.GetOrdinal("PreviewMatchesCurrentTransaction")),
                ReservedInvoiceNumber = reader.GetString(reader.GetOrdinal("ReservedInvoiceNumber"))
            };

            result.BlockingReason = result.CanPostToSage
                ? string.Empty
                : !result.HasPreview
                    ? "Invoice preview has not been generated."
                    : !result.HasReservedInvoiceNumber
                        ? "Reserved invoice number is missing."
                        : !result.PreviewMatchesCurrentTransaction
                            ? "Invoice preview is stale and must be regenerated."
                            : "Posting is blocked.";

            return result;
        }
        public async Task<TransactionInvoicePrintModel?> GetInvoicePrintModelAsync(
    Guid transactionGuid,
    TransactionInvoiceRenderMode renderMode,
    CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("A valid transaction guid is required.", nameof(transactionGuid));
            }

            const string sql = @"
SELECT
    imi.TransactionGuid,
    imi.CustomerReference,
    imi.InvoiceToBlock,
    imi.InvoiceDate,
    imi.CreditTerms,
    imi.CostCentre,
    imi.Department,
    imi.ReservedInvoiceNumber,
    imi.SageInvoiceNumber,
    imi.SageSalesOrderNumber,
    imi.PurchaseOrderNumber,
    imi.NetTotal,
    imi.VatTotal,
    imi.GrossTotal,
    imi.JobTitle,
    imi.LineDescription,
    imi.Quantity,
    imi.UnitPrice,
    imi.Net,
    imi.Vat,
    imi.VatCode
FROM SFin.Transaction_InvoiceMergeInfo AS imi
WHERE imi.TransactionGuid = @TransactionGuid;";

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transactionGuid
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return null;
            }

            static string GetString(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? string.Empty
                    : Convert.ToString(reader.GetValue(ordinal)) ?? string.Empty;
            }

            static decimal GetDecimal(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? 0m
                    : Convert.ToDecimal(reader.GetValue(ordinal));
            }

            static DateTime GetDateTime(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? DateTime.MinValue
                    : Convert.ToDateTime(reader.GetValue(ordinal));
            }

            static Guid GetGuid(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? Guid.Empty
                    : reader.GetGuid(ordinal);
            }

            static string NormalizeForMultilineHtml(string? value)
            {
                if (string.IsNullOrWhiteSpace(value))
                {
                    return string.Empty;
                }

                return value
                    .Replace("\r\n", "\n", StringComparison.Ordinal)
                    .Replace("\r", "\n", StringComparison.Ordinal)
                    .Trim();
            }

            var result = new TransactionInvoicePrintModel
            {
                TransactionGuid = GetGuid(reader, "TransactionGuid"),
                RenderMode = renderMode,
                CustomerReference = GetString(reader, "CustomerReference"),
                InvoiceToBlock = NormalizeForMultilineHtml(GetString(reader, "InvoiceToBlock")),
                TaxPointDate = GetDateTime(reader, "InvoiceDate"),
                PaymentTerms = GetString(reader, "CreditTerms"),
                CostCentre = GetString(reader, "CostCentre"),
                Department = GetString(reader, "Department"),
                InvoiceNumber = renderMode == TransactionInvoiceRenderMode.Final
                    ? GetString(reader, "SageInvoiceNumber")
                    : string.Empty,
                SalesOrderNumber = renderMode == TransactionInvoiceRenderMode.Final
                    ? GetString(reader, "SageSalesOrderNumber")
                    : string.Empty,
                PurchaseOrderNumber = GetString(reader, "PurchaseOrderNumber"),
                TotalAmountExcludingVat = GetDecimal(reader, "NetTotal"),
                TotalVat = GetDecimal(reader, "VatTotal"),
                TotalAmountDue = GetDecimal(reader, "GrossTotal"),
                Lines = new List<TransactionInvoicePrintLineModel>()
            };

            do
            {
                result.Lines.Add(new TransactionInvoicePrintLineModel
                {
                    Description = string.IsNullOrWhiteSpace(GetString(reader, "LineDescription"))
                        ? "Invoice"
                        : GetString(reader, "LineDescription"),
                    Quantity = GetDecimal(reader, "Quantity") == 0m ? 1m : GetDecimal(reader, "Quantity"),
                    UnitPrice = GetDecimal(reader, "UnitPrice"),
                    AmountExVat = GetDecimal(reader, "Net"),
                    VatCode = GetString(reader, "VatCode"),
                    VatAmount = GetDecimal(reader, "Vat")
                });
            }
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false));

            return result;
        }
        public async Task<TransactionInvoicePrintModel?> GetInvoicePrintModelAsync(
    Guid transactionGuid,
    CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("A valid transaction guid is required.", nameof(transactionGuid));
            }

            const string sql = @"
SELECT
    imi.TransactionGuid,
    imi.CustomerReference,
    imi.InvoiceToBlock,
    imi.InvoiceDate,
    imi.CreditTerms,
    imi.CostCentre,
    imi.Department,
    imi.InvoiceNumber,
    imi.PurchaseOrderNumber,
    imi.NetTotal,
    imi.VatTotal,
    imi.GrossTotal,
    imi.JobTitle,
    imi.Quantity,
    imi.UnitPrice,
    imi.Vat,
    imi.TaxCode
FROM SFin.Transaction_InvoiceMergeInfo AS imi
WHERE imi.TransactionGuid = @TransactionGuid
ORDER BY imi.TransactionGuid;";

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transactionGuid
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return null;
            }

            static string GetString(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? string.Empty
                    : Convert.ToString(reader.GetValue(ordinal)) ?? string.Empty;
            }

            static decimal GetDecimal(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? 0m
                    : Convert.ToDecimal(reader.GetValue(ordinal));
            }

            static DateTime GetDateTime(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? DateTime.MinValue
                    : Convert.ToDateTime(reader.GetValue(ordinal));
            }

            static Guid GetGuid(SqlDataReader reader, string columnName)
            {
                var ordinal = reader.GetOrdinal(columnName);
                return reader.IsDBNull(ordinal)
                    ? Guid.Empty
                    : reader.GetGuid(ordinal);
            }

            static string NormalizeForMultilineHtml(string? value)
            {
                if (string.IsNullOrWhiteSpace(value))
                {
                    return string.Empty;
                }

                return value
                    .Replace("\r\n", "\n", StringComparison.Ordinal)
                    .Replace("\r", "\n", StringComparison.Ordinal)
                    .Trim();
            }

            var result = new TransactionInvoicePrintModel
            {
                TransactionGuid = GetGuid(reader, "TransactionGuid"),
                CustomerReference = GetString(reader, "CustomerReference"),
                InvoiceToBlock = NormalizeForMultilineHtml(GetString(reader, "InvoiceToBlock")),
                TaxPointDate = GetDateTime(reader, "InvoiceDate"),
                PaymentTerms = GetString(reader, "CreditTerms"),
                CostCentre = GetString(reader, "CostCentre"),
                Department = GetString(reader, "Department"),
                InvoiceNumber = GetString(reader, "InvoiceNumber"),
                PurchaseOrderNumber = GetString(reader, "PurchaseOrderNumber"),
                TotalAmountExcludingVat = GetDecimal(reader, "NetTotal"),
                TotalVat = GetDecimal(reader, "VatTotal"),
                TotalAmountDue = GetDecimal(reader, "GrossTotal"),
                Lines = new List<TransactionInvoicePrintLineModel>()
            };

            do
            {
                var description = GetString(reader, "JobTitle");
                var quantity = GetDecimal(reader, "Quantity");
                var unitPrice = GetDecimal(reader, "UnitPrice");
                var vatAmount = GetDecimal(reader, "Vat");
                var amountExVat = quantity == 0m ? unitPrice : quantity * unitPrice;

                result.Lines.Add(new TransactionInvoicePrintLineModel
                {
                    Description = string.IsNullOrWhiteSpace(description) ? "Invoice" : description,
                    Quantity = quantity == 0m ? 1m : quantity,
                    UnitPrice = unitPrice,
                    AmountExVat = amountExVat,
                    VatCode = GetString(reader, "TaxCode"),
                    VatAmount = vatAmount
                });
            }
            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false));

            return result;
        }

        public async Task MarkPostedToSageAsync(Guid transactionGuid, CancellationToken cancellationToken = default)
        {
            const string sql = @"
UPDATE tip
SET tip.IsPostedToSage = 1,
    tip.PostedToSageDateTimeUtc = SYSUTCDATETIME()
FROM SFin.TransactionInvoicePreviews AS tip
JOIN SFin.Transactions AS t
    ON t.ID = tip.TransactionId
WHERE t.Guid = @TransactionGuid
  AND tip.RowStatus NOT IN (0, 254)
  AND tip.IsCurrent = 1;";

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection) { CommandType = CommandType.Text };
            command.Parameters.AddWithValue("@TransactionGuid", transactionGuid);
            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        public async Task<TransactionInvoicePreviewJobContext?> GetJobContextAsync(
    Guid transactionGuid,
    CancellationToken cancellationToken = default)
        {
            const string sql = @"
SELECT TOP (1)
    t.Guid AS TransactionGuid,
    t.JobID AS JobId,
    j.Guid AS JobGuid
FROM SFin.Transactions AS t
INNER JOIN SJob.Jobs AS j
    ON j.ID = t.JobID
WHERE t.Guid = @TransactionGuid
  AND t.RowStatus NOT IN (0, 254)
  AND j.RowStatus NOT IN (0, 254);";

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transactionGuid
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                return null;

            return new TransactionInvoicePreviewJobContext
            {
                TransactionGuid = reader.GetGuid(reader.GetOrdinal("TransactionGuid")),
                JobId = reader.GetInt32(reader.GetOrdinal("JobId")),
                JobGuid = reader.GetGuid(reader.GetOrdinal("JobGuid"))
            };
        }
    }


}