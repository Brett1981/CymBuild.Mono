using System;
using System.Text;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Semantic finance document type used to route approved transactions at the
    /// active Sage integration boundary. Values are deliberately independent of
    /// environment-specific TransactionTypes.ID values.
    /// </summary>
    public enum SageOutboundDocumentType
    {
        Unknown = 0,
        Invoice = 1,
        CreditNote = 2,
        Receipt = 3,
        Payment = 4
    }

    public static class SageOutboundDocumentTypeResolver
    {
        /// <summary>
        /// Resolves the finance transaction type using its stable business name.
        /// Spaces, hyphens and other punctuation are ignored so legacy aliases
        /// such as "Credit Note" and "Credit-Note" resolve consistently.
        /// </summary>
        public static SageOutboundDocumentType Resolve(string? transactionTypeName)
        {
            var normalisedName = Normalise(transactionTypeName);

            return normalisedName switch
            {
                "invoice" => SageOutboundDocumentType.Invoice,
                "creditnote" => SageOutboundDocumentType.CreditNote,
                "receipt" => SageOutboundDocumentType.Receipt,
                "payment" => SageOutboundDocumentType.Payment,
                _ => SageOutboundDocumentType.Unknown
            };
        }

        private static string Normalise(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return string.Empty;
            }

            var builder = new StringBuilder(value.Length);

            foreach (var character in value)
            {
                if (char.IsLetterOrDigit(character))
                {
                    builder.Append(char.ToLowerInvariant(character));
                }
            }

            return builder.ToString();
        }
    }
}
