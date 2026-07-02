using Concursus.API.Services.AIAssistant;

namespace Concursus.API.Services;

public static class AIAssistantServiceRegistration
{
    public static IServiceCollection AddCymBuildAIAssistant(this IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        services.Configure<BlueGenOptions>(options =>
        {
            configuration.GetSection(BlueGenOptions.SectionName).Bind(options);
            options.ApplyEnvironmentOverrides();
        });

        services.AddHttpClient<IBlueGenClient, BlueGenClient>();

        services.AddScoped<IAIAssistantPromptBuilder, AIAssistantPromptBuilder>();
        services.AddScoped<IAIAssistantAnswerService, AIAssistantAnswerService>();

        return services;
    }
}
