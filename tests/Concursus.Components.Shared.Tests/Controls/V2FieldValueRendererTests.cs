using Bunit;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Controls;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.Components.Shared.Tests.Controls;

public sealed class V2FieldValueRendererTests
{
    [Fact]
    public void Render_ShowsNoFieldDefinitionMessage_WhenFieldDefinitionIsNull()
    {
        using var context = new BunitContext();

        var cut = context.Render<V2FieldValueRenderer>();

        Assert.Contains("(no field definition)", cut.Markup);
    }

    [Fact]
    public void Render_ShowsNoDataLoadedMessage_WhenDataObjectIsNull()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition { Id = Guid.NewGuid().ToString(), ViewType = FieldViewType.ReadOnly };

        var cut = context.Render<V2FieldValueRenderer>(parameters =>
            parameters.Add(component => component.FieldDefinition, field));

        Assert.Contains("(no data loaded)", cut.Markup);
    }

    [Fact]
    public void Render_ShowsEmptyValue_WhenNoMatchingDataPropertyExists()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition { Id = Guid.NewGuid().ToString(), ViewType = FieldViewType.ReadOnly };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldValueRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Equal(string.Empty, cut.Find("span").TextContent.Trim());
    }

    [Fact]
    public void Render_ShowsUnpackedStringValue_WhenDataPropertyMatchesByGuid()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid, ViewType = FieldViewType.ReadOnly };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue { Value = "Existing value" })
        });

        var cut = context.Render<V2FieldValueRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("String: \"Existing value\"", cut.Markup);
        Assert.Contains("v2-field-value--readonly", cut.Markup);
    }

    [Fact]
    public void Render_DoesNotMatchDataProperty_WhenGuidCaseDiffersButStillEqualsOrdinalIgnoreCase()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition { Id = fieldGuid.ToUpperInvariant(), ViewType = FieldViewType.ReadOnly };
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid.ToLowerInvariant(),
            Value = Any.Pack(new StringValue { Value = "Case-insensitive match" })
        });

        var cut = context.Render<V2FieldValueRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("String: \"Case-insensitive match\"", cut.Markup);
    }
}
