using Microsoft.AspNetCore.Components;
using System;
using System.Threading.Tasks;

namespace Concursus.PWA.Shared
{
    public partial class FilteredDynamicGridViewV2 : ComponentBase
    {
        // -------------------------
        // Existing Invoicing KPIs
        // -------------------------
        private double TotalQuoteValue { get; set; } = 0;
        private double AverageQuoteValue { get; set; } = 0;

        private int NmbrOfOverdueInvoices { get; set; } = 0;
        private int NmbrOfPendingInvoices { get; set; } = 0;
        private int NmbrOfPaidInvoices { get; set; } = 0;

        private bool KPIValuesReceived { get; set; } = false;

        /// <summary>
        /// Loads KPI values for the Automated Invoicing dashboard (only once).
        /// This is intentionally separate from Authorisation KPIs, which are now managed in Authorisation.cs.
        /// </summary>
        private async Task GetKPIValues()
        {
            try
            {
                if (KPIValuesReceived)
                    return;

                var kpiValues = await coreClient.GetAutomatedInvoicingKPIAsync(
                    new API.Core.AutomatedInvoicingKPIReq());

                TotalQuoteValue = kpiValues.Sum;
                AverageQuoteValue = kpiValues.Average;
                NmbrOfOverdueInvoices = kpiValues.NumberOfOverdue;
                NmbrOfPaidInvoices = kpiValues.NumberOfPaid;
                NmbrOfPendingInvoices = kpiValues.NumberOfPending;

                KPIValuesReceived = true;
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/GetKPIValues()");
                OnError(ex);
            }
        }
    }
}
