using static Concursus.Common.Shared.Enums;

namespace Concursus.Common.Shared.Helpers
{
    public static class OrganisationalUnitHelper
    {
        // Define GUIDs once
        private static readonly Dictionary<OrganisationalUnits, string> _unitIds =
            new()
            {
            { OrganisationalUnits.CDM, "2C9489BD-EAE8-4703-90D7-56C94E802EDA" },
            { OrganisationalUnits.BuildingControl, "0125329F-003B-4CE4-A2C9-8C6DCC1A4DFF" },
            { OrganisationalUnits.FireSafety, "FDB20506-DCB0-4911-BDD1-EED2C27225AF" },
            { OrganisationalUnits.FireEngineering, "E3F5F61F-0313-44D5-B47A-669408A067B1" },
            { OrganisationalUnits.StructuralEngineering, "AEBD6E67-7883-405D-A234-8377722281C1" },
            { OrganisationalUnits.BuildingEnvelope, "1882472F-9976-4D25-8BF6-A91F7BE1AA3F" }
            };

        // Reverse dictionary for lookup by ID
        private static readonly Dictionary<string, OrganisationalUnits> _idToUnit =
            _unitIds.ToDictionary(kvp => kvp.Value, kvp => kvp.Key, StringComparer.OrdinalIgnoreCase);

        public static string GetId(OrganisationalUnits unit) => _unitIds[unit];

        public static bool TryGetById(string unitId, out OrganisationalUnits unit) => _idToUnit.TryGetValue(unitId, out unit);

        // Optional: strict version throwing exceptions
        public static OrganisationalUnits GetById(string unitId) =>
            _idToUnit.TryGetValue(unitId, out var unit)
                ? unit
                : throw new ArgumentException("Unknown unit id", nameof(unitId));
    }
}
