using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Helpers;

namespace Concursus.Components.Shared.Tests.Helpers;

public sealed class ViewDefinitionBuilderTests
{
    [Fact]
    public void BuildPageViewDefinition_RejectsNullMetadata()
    {
        Assert.Throws<ArgumentNullException>(() =>
            ViewDefinitionBuilder.BuildPageViewDefinition(null!));
    }

    [Fact]
    public void BuildPageViewDefinition_UsesLabelAndOrdersVisibleSections()
    {
        var laterGroup = Group("later", "Later", sortOrder: 20);
        var hiddenGroup = Group("hidden", "Hidden", sortOrder: 1, hidden: true);
        var earlierGroup = Group("earlier", "Earlier", sortOrder: 10);
        var entityType = new EntityType
        {
            Guid = Guid.NewGuid().ToString(),
            Name = "Job",
            Label = "Job details"
        };
        entityType.EntityPropertyGroups.Add(laterGroup);
        entityType.EntityPropertyGroups.Add(hiddenGroup);
        entityType.EntityPropertyGroups.Add(earlierGroup);

        var page = ViewDefinitionBuilder.BuildPageViewDefinition(entityType);

        Assert.Equal("Job details", page.Title);
        Assert.Equal(new[] { "Earlier", "Later" }, page.Sections.Select(section => section.Title));
        Assert.DoesNotContain(page.Sections, section => section.Id == hiddenGroup.Guid);
    }

    [Fact]
    public void BuildPageViewDefinition_FallsBackToEntityNameAndOtherSection()
    {
        var entityType = new EntityType
        {
            Guid = Guid.NewGuid().ToString(),
            Name = "Asset",
            Label = " "
        };
        entityType.EntityProperties.Add(Property("ungrouped", "Name", "Asset name", "nvarchar", maxLength: 100));

        var page = ViewDefinitionBuilder.BuildPageViewDefinition(entityType);

        Assert.Equal("Asset", page.Title);
        var section = Assert.Single(page.Sections);
        Assert.Equal("ungrouped", section.Id);
        Assert.Equal("Other", section.Title);
        Assert.Equal("Asset name", Assert.Single(section.Fields).Title);
    }

    [Theory]
    [InlineData("bit", 1, false, false, false, FieldViewType.Boolean)]
    [InlineData("date", 1, false, false, false, FieldViewType.Date)]
    [InlineData("datetime2", 1, false, false, false, FieldViewType.DateTime)]
    [InlineData("decimal", 1, false, false, false, FieldViewType.Number)]
    [InlineData("nvarchar", 1000, false, false, false, FieldViewType.MultilineText)]
    [InlineData("nvarchar", 100, false, false, false, FieldViewType.Text)]
    [InlineData("nvarchar", 100, true, false, false, FieldViewType.Hidden)]
    [InlineData("nvarchar", 100, false, true, false, FieldViewType.ReadOnly)]
    [InlineData("nvarchar", 100, false, false, true, FieldViewType.Number)]
    public void BuildPageViewDefinition_MapsMetadataToExpectedFieldType(
        string dataType,
        int maxLength,
        bool hidden,
        bool readOnly,
        bool latitude,
        FieldViewType expected)
    {
        var group = Group("group", "Details", sortOrder: 1);
        var property = Property("field", "Field", "Field label", dataType, maxLength);
        property.EntityPropertyGroupGuid = group.Guid;
        property.IsHidden = hidden;
        property.IsReadOnly = readOnly;
        property.IsLatitude = latitude;

        var entityType = new EntityType { Name = "Entity" };
        entityType.EntityPropertyGroups.Add(group);
        entityType.EntityProperties.Add(property);

        var field = Assert.Single(
            Assert.Single(ViewDefinitionBuilder.BuildPageViewDefinition(entityType).Sections).Fields);

        Assert.Equal(expected, field.ViewType);
    }

    [Fact]
    public void BuildPageViewDefinition_CreatesDropdownConfigurationFromMetadata()
    {
        var definitionGuid = Guid.NewGuid().ToString();
        var property = Property("field", "AccountId", "Account", "uniqueidentifier", 36);
        property.DropDownListDefinitionGuid = definitionGuid;
        property.IsCompulsory = true;

        var entityType = new EntityType { Name = "Entity" };
        entityType.EntityProperties.Add(property);

        var field = Assert.Single(
            Assert.Single(ViewDefinitionBuilder.BuildPageViewDefinition(entityType).Sections).Fields);
        var config = Assert.IsType<FieldDropdownConfig>(field.ExtraConfig);

        Assert.Equal(FieldViewType.Dropdown, field.ViewType);
        Assert.True(field.IsRequired);
        Assert.Equal(definitionGuid, config.DefinitionId);
        Assert.Equal(property.Guid, config.FieldId);
    }

    private static EntityPropertyGroup Group(
        string seed,
        string label,
        int sortOrder,
        bool hidden = false) => new()
        {
            Guid = StableGuid(seed),
            Name = label,
            Label = label,
            SortOrder = sortOrder,
            IsHidden = hidden
        };

    private static EntityProperty Property(
        string seed,
        string name,
        string label,
        string dataType,
        int maxLength) => new()
        {
            Guid = StableGuid(seed),
            Name = name,
            Label = label,
            EntityDataTypeName = dataType,
            MaxLength = maxLength,
            SortOrder = 1
        };

    private static string StableGuid(string seed)
    {
        var bytes = System.Security.Cryptography.MD5.HashData(System.Text.Encoding.UTF8.GetBytes(seed));
        return new Guid(bytes).ToString();
    }
}
