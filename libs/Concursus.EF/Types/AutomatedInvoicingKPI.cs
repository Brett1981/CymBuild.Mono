using System;
using System.Collections.Generic;
using System.Text;

namespace Concursus.EF.Types
{
    public class AutomatedInvoicingKPI
    {
        public double Sum { get; set; } = 0;
        public double Average { get; set; } = 0;

        public int NumberOfPending { get; set; } = 0;
        public int NumberOfOverdue { get; set; } = 0;
        public int NumberOfPaid { get; set; } = 0;
    }
}
