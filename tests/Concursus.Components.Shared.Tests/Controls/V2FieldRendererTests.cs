using Bunit;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Controls;

namespace Concursus.Components.Shared.Tests.Controls;

public sealed class V2FieldRendererTests
{
    [Fact]
    public void Render_ShowsNoFieldDefinitionMessage_WhenFieldDefinitionIsNull()
    {
        using var context = new BunitContext();

        var cut = context.Render<V2FieldRenderer>();

        Assert.Contains("No field definition.", cut.Markup);
        Assert.Contains("v2-field--empty", cut.Markup);
    }

    [Fact]
    public void Render_ShowsNothing_WhenFieldIsHidden()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Secret field",
            ViewType = FieldViewType.Text,
            IsHidden = true
        };

        var cut = context.Render<V2FieldRenderer>(parameters =>
            parameters.Add(component => component.FieldDefinition, field));

        Assert.DoesNotContain("Secret field", cut.Markup);
        Assert.Empty(cut.FindAll("label"));
    }

    [Fact]
    public void Render_ShowsNothing_WhenViewTypeIsHidden()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Internal id",
            ViewType = FieldViewType.Hidden
        };

        var cut = context.Render<V2FieldRenderer>(parameters =>
            parameters.Add(component => component.FieldDefinition, field));

        Assert.DoesNotContain("Internal id", cut.Markup);
        Assert.Empty(cut.FindAll("label"));
    }

    [Fact]
    public void Render_ShowsRequiredIndicator_ForEditableRequiredField()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Job number",
            ViewType = FieldViewType.Text,
            IsRequired = true
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("v2-field__required-indicator", cut.Markup);
    }

    [Fact]
    public void Render_DoesNotShowRequiredIndicator_WhenFieldIsNotRequired()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Notes",
            ViewType = FieldViewType.Text,
            IsRequired = false
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.DoesNotContain("v2-field__required-indicator", cut.Markup);
    }

    [Fact]
    public void Render_ShowsHelpText_WhenProvided()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Notes",
            ViewType = FieldViewType.Text,
            HelpText = "Visible to the client"
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("v2-field__help-text", cut.Markup);
        Assert.Contains("Visible to the client", cut.Markup);
    }

    [Fact]
    public void Render_OmitsHelpTextBlock_WhenNotProvided()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Notes",
            ViewType = FieldViewType.Text
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.DoesNotContain("v2-field__help-text", cut.Markup);
    }

    [Fact]
    public void Render_DelegatesToFieldValueRenderer_WhenReadOnly()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Status",
            ViewType = FieldViewType.ReadOnly,
            IsReadOnly = true
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("v2-field-value", cut.Markup);
        Assert.Empty(cut.FindAll("input"));
    }

    [Fact]
    public void Render_DelegatesToFieldEditor_WhenNotReadOnly()
    {
        using var context = new BunitContext();
        var field = new FieldViewDefinition
        {
            Id = Guid.NewGuid().ToString(),
            Title = "Job description",
            ViewType = FieldViewType.Text,
            IsReadOnly = false
        };
        var dataObject = new DataObject();

        var cut = context.Render<V2FieldRenderer>(parameters => parameters
            .Add(component => component.FieldDefinition, field)
            .Add(component => component.DataObject, dataObject));

        Assert.Contains("v2-field-editor", cut.Markup);
        Assert.Single(cut.FindAll("input"));
    }
}
