#nullable enable

using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.EF.Finance
{
    public sealed class SageInboundPaymentReadRepository : ISageInboundPaymentReadRepository
    {
        private readonly Core _core;

        public SageInboundPaymentReadRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        public async Task<SageInboundSyncTarget?> GetSyncTargetAsync(
            Guid cymBuildDocumentGuid,
            CancellationToken cancellationToken = default)
        {
            const string sql = @"
SELECT TOP (1)
    s.CymBuildEntityTypeID,
    s.CymBuildDocumentGuid,
    s.CymBuildDocumentID,
    s.InvoiceRequestID,
    s.TransactionID,
    s.JobID,
    s.SageDataset,
    s.SageAccountReference,
    s.SageDocumentNo
FROM SFin.SageInboundDocumentStatus AS s
WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
  AND s.RowStatus NOT IN (0,254)

UNION ALL

SELECT TOP (1)
    0 AS CymBuildEntityTypeID,
    ir.Guid AS CymBuildDocumentGuid,
    CAST(ir.ID AS BIGINT) AS CymBuildDocumentID,
    ir.ID AS InvoiceRequestID,
    ISNULL(t.ID, -1) AS TransactionID,
    ISNULL(ir.JobId, -1) AS JobID,
    N'LIVE' AS SageDataset,
    ISNULL(a.Code, N'') AS SageAccountReference,
    ISNULL(t.Number, N'') AS SageDocumentNo
FROM SFin.InvoiceRequests AS ir
LEFT JOIN SFin.InvoiceRequestItems AS iri
    ON iri.InvoiceRequestId = ir.ID
   AND iri.RowStatus NOT IN (0,254)
LEFT JOIN SFin.TransactionDetails AS td
    ON td.InvoiceRequestItemId = iri.ID
   AND td.RowStatus NOT IN (0,254)
LEFT JOIN SFin.Transactions AS t
    ON t.ID = td.TransactionID
   AND t.RowStatus NOT IN (0,254)
LEFT JOIN SCrm.Accounts AS a
    ON a.ID = t.AccountID
   AND a.RowStatus NOT IN (0,254)
WHERE ir.Guid = @CymBuildDocumentGuid
  AND ir.RowStatus NOT IN (0,254);";

            await using var connection = _core.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@CymBuildDocumentGuid", SqlDbType.UniqueIdentifier)
            {
                Value = cymBuildDocumentGuid
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return null;
            }

            return new SageInboundSyncTarget
            {
                CymBuildEntityTypeId = reader.GetInt32(reader.GetOrdinal("CymBuildEntityTypeID")),
                CymBuildDocumentGuid = reader.GetGuid(reader.GetOrdinal("CymBuildDocumentGuid")),
                CymBuildDocumentId = reader.GetInt64(reader.GetOrdinal("CymBuildDocumentID")),
                InvoiceRequestId = reader.GetInt32(reader.GetOrdinal("InvoiceRequestID")),
                TransactionId = reader.GetInt64(reader.GetOrdinal("TransactionID")),
                JobId = reader.GetInt32(reader.GetOrdinal("JobID")),
                SageDataset = reader.GetString(reader.GetOrdinal("SageDataset")),
                SageAccountReference = reader.GetString(reader.GetOrdinal("SageAccountReference")),
                SageDocumentNo = reader.GetString(reader.GetOrdinal("SageDocumentNo"))
            };
        }
    }
}