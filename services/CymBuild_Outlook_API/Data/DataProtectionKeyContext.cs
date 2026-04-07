using Microsoft.AspNetCore.DataProtection.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_Outlook_API.Data
{
    public class DataProtectionKeyContext : DbContext, IDataProtectionKeyContext
    {
        public DataProtectionKeyContext(DbContextOptions<DataProtectionKeyContext> options)
            : base(options)
        {
        }

        public DbSet<DataProtectionKey> DataProtectionKeys { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Specify the schema and table name for DataProtectionKeys
            modelBuilder.Entity<DataProtectionKey>(entity =>
            {
                entity.ToTable("DataProtectionKeys", "SOffice");
            });
        }
    }
}