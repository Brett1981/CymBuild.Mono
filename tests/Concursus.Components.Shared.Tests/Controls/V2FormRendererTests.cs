using Bunit;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Controls;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.Components.Shared.Tests.Controls;

public sealed class V2FormRendererTests
{
    [Fact]
    public void Render_ShowsEmptyStateWhenDefinitionIsMissing()
    {
        using var context = new BunitContext();

        var cut = context.Render<V2FormRenderer>();

        Assert.Contains("No view definition provided.", cut.Markup);
        Assert.Contains("v2-form-renderer--empty", cut.Markup);
    }

    [Fact]
    public void Render_ShowsTitleAndNoSectionsState()
    {
        using var context = new BunitContext();
        var page = new PageViewDefinition { Title = "Job details" };

        var cut = context.Render<V2FormRenderer>(parameters =>
            parameters.Add(component => component.ViewDefinition, page));

        Assert.Equal("Job details", cut.Find("h2").TextContent);
        Assert.Contains("No sections defined for this page.", cut.Markup);
    }

    [Fact]
    public void Render_OrdersSectionsByMetadataOrder()
    {
        using var context = new BunitContext();
        var page = new PageViewDefinition();
        page.Sections.Add(new SectionViewDefinition { Title = "Second", Order = 20 });
        page.Sections.Add(new SectionViewDefinition { Title = "First", Order = 10 });

        var cut = context.Render<V2FormRenderer>(parameters =>
            parameters.Add(component => component.ViewDefinition, page));

        var headings = cut.FindAll("h3").Select(element => element.TextContent).ToArray();
        Assert.Equal(new[] { "First", "Second" }, headings);
    }

    [Fact]
    public void Render_DoesNotExposeHiddenFields()
    {
        using var context = new BunitContext();
        var hidden = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Secret field",
            ViewType = FieldViewType.Hidden,
            IsHidden = true
        };
        var section = new SectionViewDefinition { Title = "Details", Order = 1 };
        section.Fields.Add(hidden);
        var page = new PageViewDefinition();
        page.Sections.Add(section);

        var cut = context.Render<V2FormRenderer>(parameters =>
            parameters.Add(component => component.ViewDefinition, page));

        Assert.DoesNotContain("Secret field", cut.Markup);
    }

    [Fact]
    public void Render_ReadOnlyFieldUsesDataPropertyValueAndRequiredHint()
    {
        using var context = new BunitContext();
        var fieldGuid = Guid.NewGuid().ToString();
        var field = new FieldViewDefinition
        {
            Id = fieldGuid,
            Title = "Description",
            ViewType = FieldViewType.ReadOnly,
            IsReadOnly = true,
            IsRequired = true,
            HelpText = "Shown on reports"
        };
        var section = new SectionViewDefinition { Order = 1 };
        section.Fields.Add(field);
        var page = new PageViewDefinition();
        page.Sections.Add(section);
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty
        {
            EntityPropertyGuid = fieldGuid,
            Value = Any.Pack(new StringValue { Value = "Existing value" })
        });

        var cut = context.Render<V2FormRenderer>(parameters => parameters
            .Add(component => component.ViewDefinition, page)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("Description", cut.Markup);
        Assert.Contains("Existing value", cut.Markup);
        Assert.Contains("v2-field__required-indicator", cut.Markup);
        Assert.Contains("Shown on reports", cut.Markup);
    }
}
