using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace Sage200Microservice.Data
{
    public class ApplicationContextFactory : IDesignTimeDbContextFactory<ApplicationContext>
    {
        public ApplicationContext CreateDbContext(string[] args)
        {
            // Try current folder (Data project) and the API project's appsettings as fallback
            var basePath = Directory.GetCurrentDirectory();
            var apiPath = Path.Combine(basePath, "..", "Sage200Microservice.API");

            var config = new ConfigurationBuilder()
                .SetBasePath(basePath)
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings.Development.json", optional: true)
                .AddJsonFile(Path.Combine(apiPath, "appsettings.json"), optional: true)
                .AddJsonFile(Path.Combine(apiPath, "appsettings.Development.json"), optional: true)
                .AddEnvironmentVariables()
                .Build();

            var cs =
                config.GetConnectionString("DefaultConnection")
                ?? config.GetConnectionString("Sage200Microservice")
                ?? "Server=(localdb)\\MSSQLLocalDB;Database=Sage200APIMicroservice;Trusted_Connection=True;TrustServerCertificate=True;";
            Console.WriteLine($"[EF] Using connection string: {cs}");
            var optionsBuilder = new DbContextOptionsBuilder<ApplicationContext>();
            optionsBuilder.UseSqlServer(cs, sql =>
            {
                sql.EnableRetryOnFailure(5, TimeSpan.FromSeconds(30), errorNumbersToAdd: null);
                sql.MigrationsAssembly("Sage200Microservice.Data");
                sql.MinBatchSize(10);
                sql.MaxBatchSize(100);
                sql.CommandTimeout(60);
                sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery);
            });

            // Use the 2-arg ctor so runtime mapping that uses IConfiguration still works
            return new ApplicationContext(optionsBuilder.Options, config);
        }
    }
}