using Concursus.API.Core;
using Concursus.PWA.Shared;
using Google.Protobuf.WellKnownTypes;
using System.Reflection;
using Xunit;

// These tests set component parameters directly outside of a render tree, same as
// ShoreInputTests; keep BL0005 suppression local to this file.
#pragma warning disable BL0005

namespace Concursus.PWA.Tests;

// DuplicateCheckButton keeps its supporting logic private rather than protected, so these
// characterization tests reach it via reflection instead of subclassing (see TestShoreInput
// for the subclassing approach used where members are protected).
public sealed class DuplicateCheckButtonTests
{
    private static readonly System.Type ComponentType = typeof(DuplicateCheckButton);

    private static string InvokeGetFieldValue(DuplicateCheckButton component, IReadOnlyDictionary<string, string> guids, string key)
    {
        var method = ComponentType.GetMethod("GetFieldValue", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("GetFieldValue method not found.");

        return (string)method.Invoke(component, new object[] { guids, key })!;
    }

    private static IReadOnlyDictionary<string, string> GetStaticFieldGuids(string fieldName)
    {
        var field = ComponentType.GetField(fieldName, BindingFlags.Static | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException($"{fieldName} field not found.");

        return (IReadOnlyDictionary<string, string>)field.GetValue(null)!;
    }

    private static object? GetPrivatePropertyValue(DuplicateCheckButton component, string propertyName)
    {
        var property = ComponentType.GetProperty(propertyName, BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException($"{propertyName} property not found.");

        return property.GetValue(component);
    }

    private static System.Type? InvokeResolvePageComponentType(string? pageUri)
    {
        var method = ComponentType.GetMethod("ResolvePageComponentType", BindingFlags.Static | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("ResolvePageComponentType method not found.");

        return (System.Type?)method.Invoke(null, new object?[] { pageUri });
    }

    private static DataProperty StringProperty(string entityPropertyGuid, string value) =>
        new()
        {
            EntityPropertyGuid = entityPropertyGuid,
            Value = Any.Pack(new StringValue { Value = value })
        };

    [Fact]
    public void GetFieldValue_ReturnsUnpackedStringForMatchingProperty()
    {
        var guids = GetStaticFieldGuids("AgentFieldGuids");
        var nameGuid = guids["Name"];
        var component = new DuplicateCheckButton
        {
            DataObject = new DataObject
            {
                DataProperties = { StringProperty(nameGuid, "Acme Ltd") }
            }
        };

        var value = InvokeGetFieldValue(component, guids, "Name");

        Assert.Equal("Acme Ltd", value);
    }

    [Fact]
    public void GetFieldValue_UnknownKey_ReturnsEmptyString()
    {
        var guids = GetStaticFieldGuids("AgentFieldGuids");
        var component = new DuplicateCheckButton { DataObject = new DataObject() };

        var value = InvokeGetFieldValue(component, guids, "NotAField");

        Assert.Equal(string.Empty, value);
    }

    [Fact]
    public void GetFieldValue_PropertyNotPresentOnDataObject_ReturnsEmptyString()
    {
        var guids = GetStaticFieldGuids("AssetFieldGuids");
        var component = new DuplicateCheckButton { DataObject = new DataObject() };

        var value = InvokeGetFieldValue(component, guids, "Town");

        Assert.Equal(string.Empty, value);
    }

    [Fact]
    public void GetFieldValue_NullDataObject_ReturnsEmptyString()
    {
        var guids = GetStaticFieldGuids("ClientFieldGuids");
        var component = new DuplicateCheckButton { DataObject = null! };

        var value = InvokeGetFieldValue(component, guids, "Name");

        Assert.Equal(string.Empty, value);
    }

    [Theory]
    [InlineData("Asset", "StructureDetail", "2cfbff39-93cd-436b-b8ca-b2fcf7609707", "asset", "assets")]
    [InlineData("Agent", "AccountDetail", "40476ecc-d19a-4de9-90df-e1f45cd72fb2", "account", "accounts")]
    [InlineData("Client", "AccountDetail", "40476ecc-d19a-4de9-90df-e1f45cd72fb2", "account", "accounts")]
    public void SectionDependentProperties_VaryByEntityGroupSection(
        string entityGroupSection,
        string expectedTargetPageUri,
        string expectedTargetEntityTypeGuid,
        string expectedNounSingular,
        string expectedNounPlural)
    {
        var component = new DuplicateCheckButton { EntityGroupSection = entityGroupSection };

        Assert.Equal(expectedTargetPageUri, GetPrivatePropertyValue(component, "TargetPageUri"));
        Assert.Equal(expectedTargetEntityTypeGuid, GetPrivatePropertyValue(component, "TargetEntityTypeGuid"));
        Assert.Equal(expectedNounSingular, GetPrivatePropertyValue(component, "DuplicateNounSingular"));
        Assert.Equal(expectedNounPlural, GetPrivatePropertyValue(component, "DuplicateNounPlural"));
    }

    [Theory]
    [InlineData("StructureDetail")]
    [InlineData("AccountDetail")]
    public void ResolvePageComponentType_ResolvesKnownPwaPage(string pageUri)
    {
        var resolved = InvokeResolvePageComponentType(pageUri);

        Assert.NotNull(resolved);
        Assert.EndsWith(pageUri, resolved!.Name, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ThisPageDoesNotExist")]
    public void ResolvePageComponentType_UnresolvableUri_ReturnsNull(string? pageUri)
    {
        var resolved = InvokeResolvePageComponentType(pageUri);

        Assert.Null(resolved);
    }

    [Fact]
    public void MarkValidated_UpdatesButtonState_AndDoesNotThrowWithoutAnEditPage()
    {
        // editPageRef is left unset (null), same as a DuplicateCheckButton that hasn't been
        // wired to an EditPage yet - MarkValidated must not assume it is present.
        var component = new DuplicateCheckButton { EntityGroupSection = "Agent" };
        var method = ComponentType.GetMethod("MarkValidated", BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException("MarkValidated method not found.");

        var ex = Record.Exception(() => method.Invoke(component, null));

        Assert.Null(ex);
        Assert.Equal("Validated", GetPrivateFieldValue(component, "ButtonText"));
        Assert.Equal("btn btn-success", GetPrivateFieldValue(component, "ButtonCss"));
    }

    private static object? GetPrivateFieldValue(DuplicateCheckButton component, string fieldName)
    {
        var field = ComponentType.GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic)
            ?? throw new InvalidOperationException($"{fieldName} field not found.");

        return field.GetValue(component);
    }
}

#pragma warning restore BL0005
