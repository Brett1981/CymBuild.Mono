using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace CymBuild_AIErrorServiceAPI;

public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<AiErrorDbContext>
{
    public AiErrorDbContext CreateDbContext(string[] args)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json")
            .Build();

        var optionsBuilder = new DbContextOptionsBuilder<AiErrorDbContext>();
        optionsBuilder.UseSqlServer(config.GetConnectionString("DefaultConnection"));

        return new AiErrorDbContext(optionsBuilder.Options);
    }
}