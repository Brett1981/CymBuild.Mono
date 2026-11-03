using CymBuild.Database.IntegrationTests.Infrastructure;
using Xunit.Sdk;
using Xunit.v3;

[assembly: Parallelization(Mode = ParallelMode.None)]
[assembly: AssemblyFixture(typeof(SqlTestDatabaseProvisioningFixture))]