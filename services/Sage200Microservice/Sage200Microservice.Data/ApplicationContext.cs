using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Sage200Microservice.Data.Models;

namespace Sage200Microservice.Data
{
    public class ApplicationContext : DbContext
    {
        private readonly IConfiguration _configuration;

        public ApplicationContext(DbContextOptions<ApplicationContext> options) : base(options)
        {
        }

        public ApplicationContext(DbContextOptions<ApplicationContext> options, IConfiguration configuration)
            : base(options)
        {
            _configuration = configuration;
        }

        public DbSet<Customer> Customers { get; set; }
        public DbSet<Invoice> Invoices { get; set; }
        public DbSet<InvoiceStatusHistory> InvoiceStatusHistories { get; set; }
        public DbSet<ApiLog> ApiLogs { get; set; }
        public DbSet<ApiKey> ApiKeys { get; set; }
        public DbSet<AuditLog> AuditLogs { get; set; }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                var cs = _configuration?.GetConnectionString("DefaultConnection")
                         ?? Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
                         ?? "Server=(localdb)\\MSSQLLocalDB;Database=Sage200APIMicroservice;Trusted_Connection=True;TrustServerCertificate=True;";

                optionsBuilder.UseSqlServer(cs, sql =>
                {
                    sql.EnableRetryOnFailure(5, TimeSpan.FromSeconds(30), errorNumbersToAdd: null);
                    sql.MigrationsAssembly("Sage200Microservice.Data");
                    sql.MinBatchSize(10);
                    sql.MaxBatchSize(100);
                    sql.CommandTimeout(60);
                    sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery);
                });
            }
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Customers
            modelBuilder.Entity<Customer>(b =>
            {
                b.ToTable("Customers");
                b.HasKey(x => x.Id);
                b.Property(x => x.CustomerName).HasMaxLength(200).IsRequired();
                b.Property(x => x.CustomerCode).HasMaxLength(50).IsRequired();
                b.HasIndex(x => x.CustomerCode).IsUnique();
                b.Property(x => x.AddressLine1).HasMaxLength(200);
                b.Property(x => x.AddressLine2).HasMaxLength(200);
                b.Property(x => x.City).HasMaxLength(100);
                b.Property(x => x.Postcode).HasMaxLength(20);
                b.Property(x => x.Telephone).HasMaxLength(50);
                b.Property(x => x.Email).HasMaxLength(200);
                b.Property(x => x.CreatedAt).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
                b.Property(x => x.CreatedBy).HasMaxLength(100).HasDefaultValue("System");
                b.Property(x => x.SageId).HasMaxLength(100);
                b.Property(x => x.LastSyncedAt).HasColumnType("datetime2");
            });

            // Invoices
            modelBuilder.Entity<Invoice>(b =>
            {
                b.ToTable("Invoices");
                b.HasKey(x => x.Id);

                b.Property(x => x.InvoiceReference).HasMaxLength(50).IsRequired();
                b.HasIndex(x => x.InvoiceReference).IsUnique();

                b.Property(x => x.GrossValue).HasColumnType("decimal(18,2)");
                b.Property(x => x.OutstandingValue).HasColumnType("decimal(18,2)");

                b.Property(x => x.Status).HasMaxLength(30).IsRequired();

                b.Property(x => x.CreatedAt).HasColumnType("datetime2")
                    .HasDefaultValueSql("SYSUTCDATETIME()");
                b.Property(x => x.LastCheckedAt).HasColumnType("datetime2");

                b.Property(x => x.CreatedBy).HasMaxLength(100).HasDefaultValue("System");
                b.Property(x => x.SageId).HasMaxLength(100);
                b.Property(x => x.LastSyncedAt).HasColumnType("datetime2");

                // Make FK required and bind it to the navigation
                b.Property(i => i.CustomerId).IsRequired();

                b.HasOne(i => i.Customer)           // <-- use the navigation here
                 .WithMany()                        // (no back-collection on Customer)
                 .HasForeignKey(i => i.CustomerId)  // single FK column
                 .OnDelete(DeleteBehavior.Restrict);// Restrict because FK is NOT NULL
            });

            // Invoice Status History
            modelBuilder.Entity<InvoiceStatusHistory>(b =>
            {
                b.ToTable("InvoiceStatusHistories");
                b.HasKey(x => x.Id);
                b.Property(x => x.InvoiceReference).HasMaxLength(50).IsRequired();
                b.Property(x => x.OutstandingValue).HasColumnType("decimal(18,2)");
                b.Property(x => x.AllocatedValue).HasColumnType("decimal(18,2)").HasDefaultValue(0);
                b.Property(x => x.GrossValue).HasColumnType("decimal(18,2)");
                b.Property(x => x.Status).HasMaxLength(30).IsRequired();
                b.Property(x => x.CheckTimestamp).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
                b.Property(x => x.Source).HasMaxLength(30).IsRequired();
                b.Property(x => x.CheckedBy).HasMaxLength(100).HasDefaultValue("System");
                b.Property(x => x.CorrelationId).HasMaxLength(64);
                b.HasIndex(x => new { x.InvoiceReference, x.CheckTimestamp });
            });

            // ApiLogs
            modelBuilder.Entity<ApiLog>(b =>
            {
                b.ToTable("ApiLogs");
                b.HasKey(x => x.Id);
                b.Property(x => x.Endpoint).HasMaxLength(200).IsRequired();
                b.Property(x => x.RequestMethod).HasMaxLength(10).IsRequired();
                b.Property(x => x.HttpStatusCode).IsRequired();
                b.Property(x => x.Timestamp).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
                b.Property(x => x.CallerId).HasMaxLength(100);
                b.Property(x => x.ApiType).HasMaxLength(30);
                b.HasIndex(x => x.Timestamp);
            });

            // ApiKeys
            modelBuilder.Entity<ApiKey>(b =>
            {
                b.ToTable("ApiKeys");
                b.HasKey(x => x.Id);
                b.Property(x => x.Key).HasMaxLength(200).IsRequired();
                b.HasIndex(x => x.Key).IsUnique();
                b.Property(x => x.ClientName).HasMaxLength(100).IsRequired();
                b.Property(x => x.CreatedAt).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
                b.Property(x => x.ExpiresAt).HasColumnType("datetime2");
                b.Property(x => x.LastUsedAt).HasColumnType("datetime2");
                b.Property(x => x.PreviousKey).HasMaxLength(200);
                b.Property(x => x.PreviousKeyExpiresAt).HasColumnType("datetime2");
                b.Property(x => x.GracePeriodEnd).HasColumnType("datetime2");
                b.Property(x => x.Version).HasDefaultValue(1);
                // AllowedIpAddresses: NVARCHAR(MAX), JSON or CSV – keep as string
            });

            // AuditLogs
            modelBuilder.Entity<AuditLog>(b =>
            {
                b.ToTable("AuditLogs");
                b.HasKey(x => x.Id); // bigint identity
                b.Property(x => x.Timestamp).HasColumnType("datetime2").HasDefaultValueSql("SYSUTCDATETIME()");
                b.Property(x => x.EventType).HasMaxLength(50).IsRequired();
                b.Property(x => x.Category).HasMaxLength(50).IsRequired();
                b.Property(x => x.Severity).HasMaxLength(20).IsRequired();
                b.Property(x => x.Status).HasMaxLength(20);
                b.Property(x => x.UserId).HasMaxLength(100);
                b.Property(x => x.ClientId).HasMaxLength(100);
                b.Property(x => x.IpAddress).HasMaxLength(45);
                b.Property(x => x.Resource).HasMaxLength(100);
                b.Property(x => x.Action).HasMaxLength(100);
                b.Property(x => x.CorrelationId).HasMaxLength(64);
                b.Property(x => x.HttpMethod).HasMaxLength(10);
                b.Property(x => x.UrlPath).HasMaxLength(2048);
                b.Property(x => x.UserAgent).HasMaxLength(512);
                b.Property(x => x.ExpiresAt).HasColumnType("datetime2");
                b.HasIndex(x => x.Timestamp);
                b.HasIndex(x => x.CorrelationId);
            });
        }
    }
}