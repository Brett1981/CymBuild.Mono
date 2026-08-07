using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Helpers;

namespace Concursus.Components.Shared.Tests.Helpers;

public sealed class V2DropdownLoaderTests
{
    [Fact]
    public async Task PopulateDropdownOptionsAsync_RejectsNullInputs()
    {
        await Assert.ThrowsAsync<ArgumentNullException>(() =>
            V2DropdownLoader.PopulateDropdownOptionsAsync(
                null!,
                config => Task.FromResult<IReadOnlyList<DropdownOption>>(Array.Empty<DropdownOption>())));

        await Assert.ThrowsAsync<ArgumentNullException>(() =>
            V2DropdownLoader.PopulateDropdownOptionsAsync(new PageViewDefinition(), null!));
    }

    [Fact]
    public async Task PopulateDropdownOptionsAsync_DoesNothingWhenNoDropdownsExist()
    {
        var calls = 0;
        var page = Page(Field(FieldViewType.Text));

        await V2DropdownLoader.PopulateDropdownOptionsAsync(
            page,
            config =>
            {
                calls++;
                return Task.FromResult<IReadOnlyList<DropdownOption>>(Array.Empty<DropdownOption>());
            });

        Assert.Equal(0, calls);
    }

    [Fact]
    public async Task PopulateDropdownOptionsAsync_LoadsOncePerDefinitionAndSharesOptions()
    {
        var calls = 0;
        var firstConfig = Config("shared-definition");
        var secondConfig = Config("SHARED-DEFINITION");
        var page = Page(
            Field(FieldViewType.Dropdown, firstConfig),
            Field(FieldViewType.Dropdown, secondConfig));
        var expected = new[]
        {
            new DropdownOption { Value = "1", Label = "One" },
            new DropdownOption { Value = "2", Label = "Two" }
        };

        await V2DropdownLoader.PopulateDropdownOptionsAsync(
            page,
            config =>
            {
                calls++;
                return Task.FromResult<IReadOnlyList<DropdownOption>>(expected);
            });

        Assert.Equal(1, calls);
        Assert.Equal(expected, firstConfig.Options);
        Assert.Equal(expected, secondConfig.Options);
        Assert.Same(firstConfig.Options, secondConfig.Options);
    }

    [Fact]
    public async Task PopulateDropdownOptionsAsync_ConvertsLoaderFailureToEmptyOptions()
    {
        var config = Config("definition");
        config.Options.Add(new DropdownOption { Value = "old", Label = "Old" });
        var page = Page(Field(FieldViewType.Dropdown, config));

        await V2DropdownLoader.PopulateDropdownOptionsAsync(
            page,
            _ => throw new InvalidOperationException("lookup unavailable"));

        Assert.Empty(config.Options);
    }

    [Fact]
    public async Task PopulateDropdownOptionsAsync_StopsBeforeLoadingWhenCancelled()
    {
        var calls = 0;
        var page = Page(
            Field(FieldViewType.Dropdown, Config("one")),
            Field(FieldViewType.Dropdown, Config("two")));
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await V2DropdownLoader.PopulateDropdownOptionsAsync(
            page,
            config =>
            {
                calls++;
                return Task.FromResult<IReadOnlyList<DropdownOption>>(Array.Empty<DropdownOption>());
            },
            cancellation.Token);

        Assert.Equal(0, calls);
    }

    private static PageViewDefinition Page(params FieldViewDefinition[] fields)
    {
        var section = new SectionViewDefinition();
        section.Fields.AddRange(fields);
        var page = new PageViewDefinition();
        page.Sections.Add(section);
        return page;
    }

    private static FieldViewDefinition Field(FieldViewType type, FieldDropdownConfig? config = null) => new()
    {
        Id = Guid.NewGuid().ToString(),
        ViewType = type,
        ExtraConfig = config
    };

    private static FieldDropdownConfig Config(string definitionId) => new()
    {
        DefinitionId = definitionId
    };
}
