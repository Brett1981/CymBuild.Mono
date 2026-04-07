using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using static Concursus.API.Core.Core;

namespace Concursus.Components.Shared.Helpers
{
    /// <summary>
    /// Helper for populating dropdown / lookup options on a PageViewDefinition.
    ///
    /// It:
    /// - Scans the PageViewDefinition for fields with ViewType == Dropdown.
    /// - Extracts their FieldDropdownConfig from ExtraConfig.
    /// - For each unique DefinitionId, it calls the provided loader ONCE.
    /// - Writes the loaded options back into FieldDropdownConfig.Options.
    ///
    /// IMPORTANT:
    /// - This helper does NOT know about FormHelper, gRPC, or any PWA services. You pass in a
    /// delegate that knows how to load the options for a given FieldDropdownConfig (including
    /// current value injection if needed).
    /// - If the delegate throws or returns an empty list, the UI will still render a dropdown
    /// shell; it just won’t have any options.
    /// </summary>
    public static class V2DropdownLoader
    {
        /// <summary>
        /// Populates dropdown options for all dropdown fields in the given page, using the provided
        /// loader function.
        ///
        /// The loader receives the FieldDropdownConfig for a definition and returns a list of
        /// DropdownOption items (Value + Label + optional Group/Colour).
        ///
        /// NOTE:
        /// - The loader is responsible for: • Passing ParentGuid / RecordGuid /
        /// CurrentSelectedValueGuid to gRPC. • Ensuring the current value is present in the
        /// returned options list, if the backend does not already guarantee this.
        /// </summary>
        public static async Task PopulateDropdownOptionsAsync(
            PageViewDefinition page,
            Func<FieldDropdownConfig, Task<IReadOnlyList<DropdownOption>>> loadOptionsAsync,
            CancellationToken cancellationToken = default)
        {
            if (page == null) throw new ArgumentNullException(nameof(page));
            if (loadOptionsAsync == null) throw new ArgumentNullException(nameof(loadOptionsAsync));

            if (page.Sections == null || page.Sections.Count == 0)
            {
                return;
            }

            // 1) Flatten all fields from all sections
            var allFields = page.Sections
                .Where(s => s.Fields != null)
                .SelectMany(s => s.Fields)
                .Where(f => f != null)
                .ToList();

            if (allFields.Count == 0)
            {
                return;
            }

            // 2) Filter to dropdown fields with a usable FieldDropdownConfig
            var dropdownFieldsWithConfig = allFields
                .Where(f => f.ViewType == FieldViewType.Dropdown)
                .Select(f => new
                {
                    Field = f,
                    Config = f.ExtraConfig as FieldDropdownConfig
                })
                .Where(x =>
                    x.Config != null &&
                    !string.IsNullOrWhiteSpace(x.Config.DefinitionId))
                .ToList();

            if (dropdownFieldsWithConfig.Count == 0)
            {
                return;
            }

            // 3) Group by DefinitionId so we only call the loader once per dropdown definition
            var groupsByDefinitionId = dropdownFieldsWithConfig
                .GroupBy(x => x.Config!.DefinitionId, StringComparer.OrdinalIgnoreCase)
                .ToList();

            foreach (var group in groupsByDefinitionId)
            {
                if (cancellationToken.IsCancellationRequested)
                {
                    break;
                }

                var sampleConfig = group.First().Config!;
                IReadOnlyList<DropdownOption> options;

                try
                {
                    options = await loadOptionsAsync(sampleConfig).ConfigureAwait(false)
                              ?? Array.Empty<DropdownOption>();
                }
                catch
                {
                    // V2 experimental mode: don't break the whole form because one dropdown failed.
                    options = Array.Empty<DropdownOption>();
                }

                var optionsList = options.ToList();

                // 4) Assign the loaded options back to all fields that share this definition
                foreach (var item in group)
                {
                    if (item.Config != null)
                    {
                        item.Config.Options = optionsList;
                    }
                }
            }
        }

        /// <summary>
        /// Populates FieldDropdownConfig.Options for all dropdown fields on the page.
        /// Options are loaded once per unique DefinitionId (DropDownListDefinitionGuid)
        /// and then reused across fields that share that definition.
        /// </summary>
        /// <param name="pageDefinition">The page definition built by ViewDefinitionBuilder.</param>
        /// <param name="coreClient">The gRPC CoreClient (injected in the PWA).</param>
        /// <param name="parentGuid">
        /// Optional parent context Guid (string). If null or invalid, Guid.Empty is used.
        /// </param>
        /// <param name="recordGuid">
        /// Optional record context Guid (string). If null or invalid, Guid.Empty is used.
        /// </param>
        /// <param name="cancellationToken">Cancellation token for the gRPC calls.</param>
        public static async Task LoadDropdownOptionsAsync(
            PageViewDefinition pageDefinition,
            CoreClient coreClient,
            string? parentGuid = null,
            string? recordGuid = null,
            CancellationToken cancellationToken = default)
        {
            if (pageDefinition == null) throw new ArgumentNullException(nameof(pageDefinition));
            if (coreClient == null) throw new ArgumentNullException(nameof(coreClient));

            // Flatten all fields on the page and pick only dropdowns that have a config
            var dropdownFields = pageDefinition.Sections
                .SelectMany(s => s.Fields)
                .Where(f => f.ViewType == FieldViewType.Dropdown &&
                            f.ExtraConfig is FieldDropdownConfig cfg &&
                            !string.IsNullOrWhiteSpace(cfg.DefinitionId))
                .ToList();

            if (!dropdownFields.Any())
            {
                // Nothing to do – return early.
                return;
            }

            // 1) Build a distinct set of DefinitionIds to avoid repeated calls.
            var definitionIds = dropdownFields
                .Select(f => ((FieldDropdownConfig)f.ExtraConfig!).DefinitionId)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            // Cache of options per DefinitionId.
            var optionsByDefinition = new Dictionary<string, List<DropdownOption>>(
                StringComparer.OrdinalIgnoreCase);

            // 2) Load options once per DefinitionId.
            foreach (var definitionId in definitionIds)
            {
                var definitionGuid = ParseGuidOrEmpty(definitionId);

                if (definitionGuid == Guid.Empty)
                {
                    // Misconfigured metadata – skip gracefully.
                    continue;
                }

                var request = new DropDownDataListRequest
                {
                    Guid = definitionGuid.ToString(),
                    ParentGuid = ParseGuidOrEmpty(parentGuid).ToString(),
                    RecordGuid = ParseGuidOrEmpty(recordGuid).ToString(),
                    // V2 does not apply client-side filters yet and does not require
                    // CurrentSelectedValueGuid for the basic case.
                    CurrentSelectedValueGuid = Guid.Empty.ToString()
                };

                // NOTE:
                // If in future you want to support search-as-you-type like ShoreInput does,
                // you can add Filters here in the same way ShoreInput.ReadItemsAsync builds
                // a DataObjectCompositeFilter. For now we just load the full list.

                var reply = await coreClient.DropDownDataListAsync(
                    request,
                    cancellationToken: cancellationToken);

                // Map reply items to DropdownOption. The proto items typically expose
                // Guid and Name – adjust property names here if your proto differs.
                var options = reply.Items
                    .Select(item => new DropdownOption
                    {
                        // Underlying value stored in DataProperty (usually a Guid string).
                        Value = SafeString(item, "Guid"),

                        // Human-readable label shown to the user (usually Name column).
                        Label = PreferNameOrGuid(item)
                    })
                    .Where(o => !string.IsNullOrWhiteSpace(o.Value))
                    .ToList();

                optionsByDefinition[definitionId] = options;
            }

            // 3) Attach options back onto each field's FieldDropdownConfig.
            foreach (var field in dropdownFields)
            {
                if (field.ExtraConfig is not FieldDropdownConfig cfg)
                    continue;

                if (!optionsByDefinition.TryGetValue(cfg.DefinitionId, out var options))
                    continue;

                cfg.Options.Clear();
                cfg.Options.AddRange(options);
            }
        }

        #region Private helpers

        /// <summary>
        /// Parses a string as a Guid; returns Guid.Empty if null/whitespace/invalid.
        /// This mirrors PWAFunctions.ParseAndReturnEmptyGuidIfInvalid but lives in
        /// Components.Shared to avoid a PWA dependency.
        /// </summary>
        private static Guid ParseGuidOrEmpty(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return Guid.Empty;

            return Guid.TryParse(value, out var parsed) ? parsed : Guid.Empty;
        }

        /// <summary>
        /// Safely extracts a string property from the dropdown item via reflection.
        /// This keeps the helper resilient to minor proto changes (Guid vs Id, etc.).
        /// </summary>
        private static string SafeString(object item, string propertyName)
        {
            var prop = item.GetType().GetProperty(propertyName);
            if (prop == null) return string.Empty;

            var raw = prop.GetValue(item);
            return raw?.ToString() ?? string.Empty;
        }

        /// <summary>
        /// Chooses a human-readable label for the dropdown item.
        /// Tries Name / Label / Description; falls back to Guid/Id.
        /// </summary>
        private static string PreferNameOrGuid(object item)
        {
            // Try common label properties first.
            foreach (var candidate in new[] { "Name", "Label", "Description" })
            {
                var text = SafeString(item, candidate);
                if (!string.IsNullOrWhiteSpace(text))
                    return text;
            }

            // Fallback to Guid / Id.
            foreach (var candidate in new[] { "Guid", "Id" })
            {
                var text = SafeString(item, candidate);
                if (!string.IsNullOrWhiteSpace(text))
                    return text;
            }

            return string.Empty;
        }

        #endregion
    }
}
