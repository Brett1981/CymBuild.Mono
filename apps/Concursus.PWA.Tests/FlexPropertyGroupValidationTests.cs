using Concursus.Components.Shared.Classes;
using Concursus.PWA.Shared;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System.Reflection;
using Xunit;

// FlexPropertyGroup.inputUpdated is set directly outside of a render tree here, same as
// ShoreInputTests; keep BL0005 suppression local to this file.
#pragma warning disable BL0005

namespace Concursus.PWA.Tests;

/// <summary>
/// Covers the Enquiry page's "checking an Enter New Agent/Client/Asset Details checkbox
/// requires validation" behaviour added to FlexPropertyGroup.HandleInputUpdated. The
/// EditPage.ValidationRequired/DataHasBeenValidated calls themselves aren't exercised here:
/// EditPage calls StateHasChanged() internally, which throws unless the component is attached
/// to a live Blazor renderer, and this project has no bUnit/renderer harness. These tests keep
/// editPageRef unset (null) so that guarded branch is skipped, and instead verify the parts that
/// don't require a renderer: the checkbox-guid-to-section mapping, and that input events for
/// every field (checkbox or not) keep being forwarded exactly as before.
/// </summary>
public sealed class FlexPropertyGroupValidationTests
{
    private static readonly System.Type ComponentType = typeof(FlexPropertyGroup);

    private static IReadOnlyDictionary<string, string> GetCheckboxGuidToSectionMap()
    {
        var field = ComponentType.GetField("EnquiryNewDetailsCheckboxGuids", BindingFlags.Static | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("EnquiryNewDetailsCheckboxGuids field not found.");

        return (IReadOnlyDictionary<string, string>)field.GetValue(null)!;
    }

    private static IReadOnlyDictionary<string, string> GetDuplicateCheckButtonSectionCheckboxGuids()
    {
        var field = typeof(DuplicateCheckButton).GetField("SectionCheckboxGuids", BindingFlags.Static | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("SectionCheckboxGuids field not found.");

        return (IReadOnlyDictionary<string, string>)field.GetValue(null)!;
    }

    private static void InvokeHandleInputUpdated(FlexPropertyGroup component, InputUpdatedArgs args)
    {
        var method = ComponentType.GetMethod("HandleInputUpdated", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("HandleInputUpdated method not found.");

        method.Invoke(component, new object[] { args });
    }

    [Theory]
    [InlineData("Agent")]
    [InlineData("Client")]
    [InlineData("Asset")]
    public void CheckboxGuidMap_MatchesDuplicateCheckButtonSectionGuids(string section)
    {
        var checkboxGuidToSection = GetCheckboxGuidToSectionMap();
        var sectionToCheckboxGuid = GetDuplicateCheckButtonSectionCheckboxGuids();

        var expectedGuid = sectionToCheckboxGuid[section];

        Assert.True(checkboxGuidToSection.TryGetValue(expectedGuid, out var mappedSection));
        Assert.Equal(section, mappedSection);
    }

    [Fact]
    public void CheckboxGuidMap_HasNoUnexpectedEntries()
    {
        var checkboxGuidToSection = GetCheckboxGuidToSectionMap();

        Assert.Equal(3, checkboxGuidToSection.Count);
    }

    [Fact]
    public void HandleInputUpdated_CheckboxGuidWithoutEditPageRef_DoesNotThrow_AndForwardsEvent()
    {
        var component = new FlexPropertyGroup();
        InputUpdatedArgs? forwarded = null;
        component.inputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args => forwarded = args);

        var checkboxGuid = GetDuplicateCheckButtonSectionCheckboxGuids()["Agent"];
        var args = new InputUpdatedArgs
        {
            EntityId = Guid.Parse(checkboxGuid),
            NewValue = Any.Pack(new BoolValue { Value = true })
        };

        var ex = Record.Exception(() => InvokeHandleInputUpdated(component, args));

        Assert.Null(ex);
        Assert.Same(args, forwarded);
    }

    [Fact]
    public void HandleInputUpdated_NonCheckboxField_StillForwardsEvent()
    {
        var component = new FlexPropertyGroup();
        InputUpdatedArgs? forwarded = null;
        component.inputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args => forwarded = args);

        var args = new InputUpdatedArgs
        {
            EntityId = Guid.NewGuid(),
            NewValue = Any.Pack(new StringValue { Value = "Some Name" })
        };

        var ex = Record.Exception(() => InvokeHandleInputUpdated(component, args));

        Assert.Null(ex);
        Assert.Same(args, forwarded);
    }
}

#pragma warning restore BL0005
