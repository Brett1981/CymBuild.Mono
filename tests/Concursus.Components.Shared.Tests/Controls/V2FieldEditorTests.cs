using Bunit;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Controls;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.Components.Shared.Tests.Controls;

public sealed class V2FieldEditorTests
{
    [Fact]
    public void Render_ShowsEmptyStateWithoutDefinitionOrData()
    {
        using var context = new BunitContext();

        var cut = context.Render<V2FieldEditor>();

        Assert.Contains("(no data)", cut.Markup);
    }

    [Fact]
    public void Render_AddsMissingDataPropertyUsingMetadataGuid()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            ViewType = FieldViewType.Dropdown,
            ExtraConfig = new FieldDropdownConfig()
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var property = Assert.Single(dataObject.DataProperties);
        Assert.Equal(field.Id, property.EntityPropertyGuid);
        Assert.True(property.IsEnabled);
        Assert.Contains("-- no options available --", cut.Markup);
    }

    [Fact]
    public void Render_DropdownUsesMetadataOptionsAndCurrentValue()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var config = new FieldDropdownConfig();
        config.Options.Add(new DropdownOption { Value = "one", Label = "One" });
        config.Options.Add(new DropdownOption { Value = "two", Label = "Two" });
        var field = new FieldViewDefinition
        {
            Id = fieldGuid,
            ViewType = FieldViewType.Dropdown,
            ExtraConfig = config
        };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue { Value = "two" })
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var options = cut.FindAll("option");
        Assert.Equal(new[] { "One", "Two" }, options.Select(option => option.TextContent));
        Assert.Equal("two", cut.Find("select").GetAttribute("value"));
    }

    [Fact]
    public void Render_ShowsValidationMessageFromDataProperty()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition
        {
            Id = fieldGuid,
            ViewType = FieldViewType.Dropdown,
            ExtraConfig = new FieldDropdownConfig()
        };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue()),
            IsInvalid = true,
            ValidationMessage = "A value is required."
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("A value is required.", cut.Markup);
        Assert.Contains("text-danger", cut.Markup);
    }
}
