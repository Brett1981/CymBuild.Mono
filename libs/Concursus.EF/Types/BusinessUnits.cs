using System;
using System.Collections.Generic;
using System.Text;

namespace Concursus.EF.Types
{
    public class BusinessUnits : IntTypeBase
    {
        public int ID { get; set; }
        public string Name { get; set; } = "";
        public Guid ParentOrganisationalUnitGuid { get; set; }
    }
}
