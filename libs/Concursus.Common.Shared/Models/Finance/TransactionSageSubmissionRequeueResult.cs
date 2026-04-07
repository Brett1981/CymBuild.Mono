using System;
using System.Collections.Generic;

namespace Concursus.Common.Shared.Models.Finance
{
    public sealed class TransactionSageSubmissionRequeueResult
    {
        public int RequeuedTransactionCount { get; set; }

        public int ResetOutboxRowCount { get; set; }

        public int ResetStatusRowCount { get; set; }

        public string Message { get; set; } = string.Empty;

        public List<TransactionSageSubmissionRequeueResultItem> Items { get; set; } = new();
    }

    public sealed class TransactionSageSubmissionRequeueResultItem
    {
        public long TransactionId { get; set; }

        public Guid TransactionGuid { get; set; }

        public bool ResetStatusRow { get; set; }

        public int ResetOutboxRows { get; set; }
    }
}