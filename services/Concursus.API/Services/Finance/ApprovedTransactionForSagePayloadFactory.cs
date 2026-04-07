#nullable enable

using System;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Produces the exact JSON payload that will be posted to /api/sales-orders.
    ///
    /// This is intentionally the single source of truth for outbound payload serialization.
    /// The JSON produced here should later be persisted in Phase 6 for auditability so that
    /// the stored payload exactly matches the posted payload.
    /// </summary>
    public sealed class ApprovedTransactionForSagePayloadFactory : IApprovedTransactionForSagePayloadFactory
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = null,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            WriteIndented = false,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        };

        private readonly ISageSalesOrderRequestMapper _mapper;

        public ApprovedTransactionForSagePayloadFactory(ISageSalesOrderRequestMapper mapper)
        {
            _mapper = mapper ?? throw new ArgumentNullException(nameof(mapper));
        }

        /// <summary>
        /// Builds the final outbound wrapper DTO.
        /// </summary>
        public SageCreateSalesOrderRequest Build(ApprovedTransactionForSageReadModel source)
        {
            return _mapper.Map(source);
        }

        /// <summary>
        /// Builds the exact JSON payload that will be sent to the Sage REST-wrapper.
        /// </summary>
        public string BuildJson(ApprovedTransactionForSageReadModel source)
        {
            var dto = Build(source);
            return JsonSerializer.Serialize(dto, JsonOptions);
        }
    }
}