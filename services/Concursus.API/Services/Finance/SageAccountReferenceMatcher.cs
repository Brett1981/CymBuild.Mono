#nullable enable

using System;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// CYB-555: SFA ignores the account filter on V2FetchCustomerTransactions, so a
    /// document-number lookup returns every row whose SecondReference matches, from any
    /// customer (LIVE: documentNo 0000038575 returned a 2026 credit note for 30607 and
    /// a 2010 invoice for 12955). The inbound sync keeps only rows for the account it
    /// asked for. Sage pads numeric account references (00030607 vs 30607), so leading
    /// zeros and case are ignored.
    /// </summary>
    public static class SageAccountReferenceMatcher
    {
        /// <summary>
        /// True when the row belongs to the requested account, or when either side has no
        /// account to compare (the row is then kept, as before this guard).
        /// </summary>
        public static bool IsRequestedAccount(string? rowAccountReference, string? requestedAccountReference)
        {
            if (string.IsNullOrWhiteSpace(rowAccountReference) ||
                string.IsNullOrWhiteSpace(requestedAccountReference))
            {
                return true;
            }

            return string.Equals(
                Normalise(rowAccountReference),
                Normalise(requestedAccountReference),
                StringComparison.OrdinalIgnoreCase);
        }

        private static string Normalise(string accountReference)
        {
            return accountReference.Trim().TrimStart('0');
        }
    }
}
