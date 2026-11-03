using System.Security.Claims;
using Concursus.API.Interfaces;
using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Services;
using Concursus.API.Services.Finance;
using Concursus.API.Services.Graph;
using Concursus.Common.Shared.Models.Finance;
using Concursus.EF;
using Concursus.EF.Finance;
using Concursus_EF;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace Concursus.API.Tests;

/// <summary>
/// Builds a CoreService instance for unit tests. CoreService constructs its ServiceBase/EF.Core
/// dependency internally (no DI seam), so this is only safe for methods that never touch
/// _serviceBase._entityFramework or OpenSqlAsync - e.g. CoreService.Sage.cs, whose methods use
/// only the constructor-injected interfaces mocked here. A dummy connection string satisfies
/// ServiceBase's/the repository classes' required-config checks without ever being connected to.
/// </summary>
internal static class CoreServiceTestFactory
{
    public const string DummyConnectionString =
        "Server=(localdb)\\MSSQLLocalDB;Database=CymBuild_Test_Unused;Integrated Security=True;";

    public sealed record Dependencies(
        Mock<ISageApiClient> SageApiClient,
        Mock<ITransactionSageSubmissionAdminService> TransactionSageSubmissionAdminService,
        Mock<ISageInboundPaymentSyncService> SageInboundPaymentSyncService,
        Mock<ISageInboundDiagnosticsRepository> SageInboundDiagnosticsRepository);

    public static (CoreService Service, Dependencies Mocks) Create()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:ShoreDB"] = DummyConnectionString
            })
            .Build();

        var httpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity())
        };
        var httpContextAccessor = Mock.Of<IHttpContextAccessor>(accessor => accessor.HttpContext == httpContext);

        var sageApiClient = new Mock<ISageApiClient>();
        var transactionSageSubmissionAdminService = new Mock<ITransactionSageSubmissionAdminService>();
        var sageInboundPaymentSyncService = new Mock<ISageInboundPaymentSyncService>();
        var sageInboundDiagnosticsRepository = new Mock<ISageInboundDiagnosticsRepository>();

        var service = new CoreService(
            NullLogger<CoreService>.Instance,
            configuration,
            httpContextAccessor,
            Mock.Of<ISharepointService>(),
            new JobClosureDecisionRepository(configuration, NullLoggerFactory.Instance),
            Mock.Of<ILookupService>(),
            sageApiClient.Object,
            transactionSageSubmissionAdminService.Object,
            Mock.Of<IDelegatedGraphClientFactory>(),
            sageInboundPaymentSyncService.Object,
            sageInboundDiagnosticsRepository.Object,
            new MetadataMigrationRepository(configuration),
            new MigrationBootstrapRepository(configuration),
            new MemoryCache(new MemoryCacheOptions()));

        return (service, new Dependencies(
            sageApiClient,
            transactionSageSubmissionAdminService,
            sageInboundPaymentSyncService,
            sageInboundDiagnosticsRepository));
    }
}
