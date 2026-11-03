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

    [Fact]
    public void Render_TextField_ShowsExistingValueAndUpdatesOnChange()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.Text };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue { Value = "Original" })
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var input = cut.Find("input");
        Assert.Equal("Original", input.GetAttribute("value"));

        input.Change("Updated");

        var property = Assert.Single(dataObject.DataProperties);
        property.Value.TryUnpack(out StringValue updated);
        Assert.Equal("Updated", updated.Value);
    }

    [Fact]
    public void Render_TextField_ClearsInvalidStateWhenEdited()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.Text };
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

        cut.Find("input").Change("Now valid");

        var property = Assert.Single(dataObject.DataProperties);
        Assert.False(property.IsInvalid);
        Assert.Equal(string.Empty, property.ValidationMessage);
    }

    [Fact]
    public void Render_MultilineTextField_RendersTextareaWithExistingValueAndUpdatesOnChange()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.MultilineText };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue { Value = "Line one" })
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var textarea = cut.Find("textarea");
        Assert.Equal("Line one", textarea.GetAttribute("value"));

        textarea.Change("Line two");

        var property = Assert.Single(dataObject.DataProperties);
        property.Value.TryUnpack(out StringValue updated);
        Assert.Equal("Line two", updated.Value);
    }

    [Fact]
    public void Render_NumberField_ShowsExistingValueAndUpdatesOnChange()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.Number };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new DoubleValue { Value = 12.5 })
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var input = cut.Find("input");
        Assert.Equal("12.5", input.GetAttribute("value"));

        input.Change("20");

        var property = Assert.Single(dataObject.DataProperties);
        property.Value.TryUnpack(out DoubleValue updated);
        Assert.Equal(20d, updated.Value);
    }

    [Fact]
    public void Render_BooleanField_ShowsExistingValueAndTogglesOnChange()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.Boolean };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new BoolValue { Value = false })
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var checkbox = cut.Find("input[type=checkbox]");
        Assert.Null(checkbox.GetAttribute("checked"));

        checkbox.Change(true);

        var property = Assert.Single(dataObject.DataProperties);
        property.Value.TryUnpack(out BoolValue updated);
        Assert.True(updated.Value);
    }

    [Fact]
    public void Render_DateField_ShowsExistingValueAndUpdatesOnChange()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.Date };
        var dataObject = new DataObject();
        var existing = new DateTime(2026, 1, 15, 0, 0, 0, DateTimeKind.Local);
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(Timestamp.FromDateTime(existing.ToUniversalTime()))
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        var input = cut.Find("input");
        Assert.Equal("2026-01-15", input.GetAttribute("value"));

        input.Change("2026-02-20");

        var property = Assert.Single(dataObject.DataProperties);
        property.Value.TryUnpack(out Timestamp updated);
        Assert.Equal(new DateTime(2026, 2, 20), updated.ToDateTime().ToLocalTime().Date);
    }

    [Fact]
    public void Render_DropdownSelection_UpdatesDataPropertyOnChange()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var config = new FieldDropdownConfig();
        config.Options.Add(new DropdownOption { Value = "one", Label = "One" });
        config.Options.Add(new DropdownOption { Value = "two", Label = "Two" });
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.Dropdown, ExtraConfig = config };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue { Value = "one" })
        });

        var cut = context.Render<V2FieldEditor>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        cut.Find("select").Change("two");

        var property = Assert.Single(dataObject.DataProperties);
        property.Value.TryUnpack(out StringValue updated);
        Assert.Equal("two", updated.Value);
    }
}
