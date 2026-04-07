using CymBuild_AIErrorServiceAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_AIErrorServiceAPI
{
    public class AiErrorDbContext : DbContext
    {
        public AiErrorDbContext(DbContextOptions<AiErrorDbContext> options) : base(options)
        {
        }

        public DbSet<AiErrorReport> AiErrorReports { get; set; }
        public DbSet<JiraSyncLog> JiraSyncLogs { get; set; }
    }
}