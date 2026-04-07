using Concursus.API.Core;
using Concursus.Components.Shared.Classes;

namespace Concursus.Components.Shared.Helpers
{
    /// <summary>
    /// V2 builder for turning EntityType metadata into a PageViewDefinition that the UI can render
    /// without repeatedly re-interpreting raw metadata.
    ///
    /// Responsibilities:
    /// - Take the EntityType (from CoreService / FormHelper) as the single source of truth.
    /// - Create PageViewDefinition → Sections → Fields in a stable, ordered structure.
    /// - Respect existing metadata flags: • Groups: IsHidden, IsDefaultCollapsed, SortOrder, Label.
    /// • Fields: Name, Label, Guid, IsHidden, IsReadOnly, IsCompulsory, EntityPropertyGroupGuid.
    ///
    /// This builder does NOT:
    /// - Replace current EditPage/JobDetail logic yet.
    /// - Decide exact Blazor components (Telerik vs custom) – that comes in the renderer layer.
    /// </summary>
    public static class ViewDefinitionBuilder
    {
        /// <summary>
        /// Builds a PageViewDefinition from an EntityType. This will be the entry point for V2
        /// forms (e.g. AddressDetailV2, StructureDetailV2).
        /// </summary>
        public static PageViewDefinition BuildPageViewDefinition(EntityType entityType)
        {
            if (entityType == null) throw new ArgumentNullException(nameof(entityType));

            var page = new PageViewDefinition
            {
                Id = entityType.Guid ?? string.Empty,
                Title = string.IsNullOrWhiteSpace(entityType.Label)
                    ? entityType.Name
                    : entityType.Label,
                CssClass = null // Reserved for future layout-level styling if needed
            };

            // 1) Build sections from EntityPropertyGroups
            var sections = BuildSections(entityType);

            // 2) Attach sections to page in order
            page.Sections.AddRange(sections.OrderBy(s => s.Order).ToList());

            return page;
        }

        /// <summary>
        /// Builds SectionViewDefinitions from the EntityPropertyGroups collection. Each section
        /// corresponds roughly to a panel/card/tab in the existing UI.
        /// </summary>
        private static IEnumerable<SectionViewDefinition> BuildSections(EntityType entityType)
        {
            var groups = entityType.EntityPropertyGroups
                        ?? new Google.Protobuf.Collections.RepeatedField<EntityPropertyGroup>();
            var properties = entityType.EntityProperties
                           ?? new Google.Protobuf.Collections.RepeatedField<EntityProperty>();

            // 1) Normal groups from metadata (non-hidden)
            foreach (var group in groups.Where(g => !g.IsHidden))
            {
                var section = new SectionViewDefinition
                {
                    Id = group.Guid ?? string.Empty,
                    GroupKey = group.Guid ?? string.Empty,
                    Title = string.IsNullOrWhiteSpace(group.Label) ? group.Name : group.Label,
                    Order = group.SortOrder,
                    IsInitiallyCollapsed = group.IsDefaultCollapsed,
                    CssClass = group.Layout // For future layout interpretation
                };

                var groupedFields = properties
                    .Where(p => p.EntityPropertyGroupGuid == group.Guid)
                    .ToList();

                section.Fields.AddRange(
                    groupedFields
                        .OrderBy(p => p.SortOrder)
                        .Select(BuildFieldViewDefinition)
                );

                yield return section;
            }

            // 2) Ungrouped fields (no matching group / empty group guid)
            var ungrouped = properties
                .Where(p => string.IsNullOrWhiteSpace(p.EntityPropertyGroupGuid)
                            || !groups.Any(g => g.Guid == p.EntityPropertyGroupGuid))
                .ToList();

            if (ungrouped.Any())
            {
                var fallbackSection = new SectionViewDefinition
                {
                    Id = "ungrouped",
                    GroupKey = null,
                    Title = "Other",
                    Order = int.MaxValue, // ensures it appears last
                    IsInitiallyCollapsed = false,
                    CssClass = null
                };

                fallbackSection.Fields.AddRange(
                    ungrouped
                        .OrderBy(p => p.SortOrder)
                        .Select(BuildFieldViewDefinition)
                );

                yield return fallbackSection;
            }
        }

        /// <summary>
        /// Determines the most appropriate FieldViewType for a given EntityProperty, based on the
        /// same metadata the rest of CymBuild already uses.
        /// </summary>
        private static FieldViewType DetermineViewType(EntityProperty property)
        {
            if (property == null)
            {
                return FieldViewType.Text;
            }

            // 1) Preserve existing behaviour first -----------------------------------

            // a) Hidden fields
            if (property.IsHidden)
            {
                return FieldViewType.Hidden;
            }

            // b) Dropdown / lookup fields
            if (!string.IsNullOrWhiteSpace(property.DropDownListDefinitionGuid) &&
                !IsEmptyGuid(property.DropDownListDefinitionGuid))
            {
                return FieldViewType.Dropdown;
            }

            // c) Read-only fields
            if (property.IsReadOnly)
            {
                return FieldViewType.ReadOnly;
            }

            // 2) Refine by data type / length ---------------------------------
            var typeName = (property.EntityDataTypeName ?? string.Empty)
                .Trim()
                .ToLowerInvariant();

            if (!string.IsNullOrEmpty(typeName))
            {
                // a) Boolean-style types
                if (typeName.Contains("bit") ||
                    typeName.Contains("bool") ||
                    typeName.Contains("boolean") ||
                    typeName.Contains("yesno") ||
                    typeName.Contains("flag"))
                {
                    return FieldViewType.Boolean;
                }

                // b) Date / time types
                if (typeName.Contains("date") || typeName.Contains("time") || typeName.Contains("timestamp"))
                {
                    if (typeName.Contains("date") && !typeName.Contains("time"))
                    {
                        return FieldViewType.Date;
                    }

                    return FieldViewType.DateTime;
                }

                // c) Numeric types
                if (typeName.Contains("int") ||
                    typeName.Contains("decimal") ||
                    typeName.Contains("numeric") ||
                    typeName.Contains("money") ||
                    typeName.Contains("float") ||
                    typeName.Contains("real") ||
                    typeName.Contains("number"))
                {
                    return FieldViewType.Number;
                }

                // d) Long text / memo types
                if (typeName.Contains("memo") || typeName.Contains("text") || typeName.Contains("ntext"))
                {
                    if (property.MaxLength == 0 || property.MaxLength > 512)
                    {
                        return FieldViewType.MultilineText;
                    }
                }
            }

            // e) Latitude / longitude
            if (property.IsLatitude || property.IsLongitude)
            {
                return FieldViewType.Number;
            }

            // f) Fallback for unknown type but large MaxLength
            if (property.MaxLength == 0 || property.MaxLength > 512)
            {
                return FieldViewType.MultilineText;
            }

            // 3) Default: single-line text
            return FieldViewType.Text;
        }

        /// <summary>
        /// Builds a FieldViewDefinition from a single EntityProperty.
        /// </summary>
        private static FieldViewDefinition BuildFieldViewDefinition(EntityProperty property)
        {
            if (property == null) throw new ArgumentNullException(nameof(property));

            var viewType = DetermineViewType(property);

            // If this is a dropdown, create a FieldDropdownConfig so V2DropdownLoader +
            // V2FieldEditor know which DropDownListDefinition to use.
            FieldDropdownConfig? dropdownConfig = null;

            if (viewType == FieldViewType.Dropdown &&
                !string.IsNullOrWhiteSpace(property.DropDownListDefinitionGuid) &&
                !IsEmptyGuid(property.DropDownListDefinitionGuid))
            {
                dropdownConfig = new FieldDropdownConfig
                {
                    DefinitionId = property.DropDownListDefinitionGuid,
                    FieldId = property.Guid ?? string.Empty
                };
            }

            var field = new FieldViewDefinition
            {
                Id = property.Guid ?? string.Empty,
                FieldName = property.Name ?? string.Empty,
                Title = string.IsNullOrWhiteSpace(property.Label) ? property.Name : property.Label,
                ViewType = viewType,
                IsReadOnly = property.IsReadOnly,
                IsHidden = property.IsHidden,
                IsRequired = property.IsCompulsory,
                Placeholder = null,
                HelpText = null,
                LayoutGroupKey = null,
                ExtraConfig = dropdownConfig
            };

            return field;
        }

        /// <summary>
        /// Helper to check if a string representation of a Guid is "empty".
        /// </summary>
        private static bool IsEmptyGuid(string guidString)
        {
            if (string.IsNullOrWhiteSpace(guidString)) return true;

            var trimmed = guidString.Trim().Trim('{', '}');

            return string.Equals(trimmed, "00000000-0000-0000-0000-000000000000",
                StringComparison.OrdinalIgnoreCase);
        }
    }
}