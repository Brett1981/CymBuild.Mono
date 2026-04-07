using System;
using System.Collections.Generic;

namespace Concursus.API.Client.Models.Finance
{
    public sealed class TransactionSageSubmissionRequeueClientResult
    {
        public int RequeuedTransactionCount { get; set; }

        public int ResetOutboxRowCount { get; set; }

        public int ResetStatusRowCount { get; set; }

        public string Message { get; set; } = string.Empty;

        public List<TransactionSageSubmissionRequeueClientResultItem> Items { get; set; } = new();
    }

    public sealed class TransactionSageSubmissionRequeueClientResultItem
    {
        public long TransactionId { get; set; }

        public Guid TransactionGuid { get; set; }

        public bool ResetStatusRow { get; set; }

        public int ResetOutboxRows { get; set; }
    }
}