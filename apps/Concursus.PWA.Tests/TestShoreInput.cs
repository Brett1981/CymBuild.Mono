using Concursus.Components.Shared.Services;
using Concursus.PWA.Shared;
using System.Reflection;

namespace Concursus.PWA.Tests;

public sealed class TestShoreInput : ShoreInput
{
    public TestShoreInput()
    {
        SetGeneratedInjectedProperty("NavManager", new TestNavigationManager());
        SetGeneratedInjectedProperty("InteractionTracker", new UserInteractionTrackerService());
    }

    public new int IntValueBinding
    {
        get => base.IntValueBinding;
        set => base.IntValueBinding = value;
    }

    public new string? StringValueBinding
    {
        get => base.StringValueBinding;
        set => base.StringValueBinding = value;
    }

    public new bool BoolValueBinding
    {
        get => base.BoolValueBinding;
        set => base.BoolValueBinding = value;
    }

    public new DateTime? DateTimeValueBinding
    {
        get => base.DateTimeValueBinding;
        set => base.DateTimeValueBinding = value;
    }

    public new double DoubleValueBinding
    {
        get => base.DoubleValueBinding;
        set => base.DoubleValueBinding = value;
    }

    public new void SetDefaultWindowParameters()
    {
        base.SetDefaultWindowParameters();
    }

    public new void SetDetailWindowParameters()
    {
        base.SetDetailWindowParameters();
    }

    public new void NavigateToDetailPage()
    {
        base.NavigateToDetailPage();
    }

    public new void HandleModelOnClick()
    {
        base.HandleModelOnClick();
    }

    private void SetGeneratedInjectedProperty(string propertyName, object value)
    {
        Type? currentType = GetType();
        while (currentType is not null)
        {
            PropertyInfo? property = currentType.GetProperty(
                propertyName,
                BindingFlags.Instance |
                BindingFlags.Public |
                BindingFlags.NonPublic |
                BindingFlags.DeclaredOnly);

            if (property is not null)
            {
                property.SetValue(this, value);
                return;
            }

            currentType = currentType.BaseType;
        }

        throw new InvalidOperationException(
            $"Unable to initialise generated ShoreInput injection property '{propertyName}'.");
    }
}
