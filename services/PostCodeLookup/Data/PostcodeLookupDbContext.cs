using Microsoft.EntityFrameworkCore;
using PostCodeLookup.Data.Entities;

namespace PostCodeLookup.Data
{
    /// <summary>
    /// EF Core context for PostcodeLookup. Defines the PostcodeCaches and AddressCaches tables.
    /// </summary>
    public class PostcodeLookupDbContext : DbContext
    {
        public PostcodeLookupDbContext(DbContextOptions<PostcodeLookupDbContext> options)
            : base(options)
        {
        }

        /// <summary>
        /// Table of cached postcode lookups.
        /// </summary>
        public DbSet<PostcodeCache> PostcodeCaches { get; set; } = default!;

        /// <summary>
        /// Table of cached addresses per postcode.
        /// </summary>
        public DbSet<AddressCache> AddressCaches { get; set; } = default!;

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // ---------------------------------------- Configure PostcodeCache entity ----------------------------------------
            modelBuilder.Entity<PostcodeCache>(entity =>
            {
                entity.HasKey(e => e.Id);

                // Postcode: required, max length 20, unique index
                entity.Property(e => e.Postcode)
                      .HasMaxLength(20)
                      .IsRequired();
                entity.HasIndex(e => e.Postcode).IsUnique();

                // Default values for timestamps (SQL GETUTCDATE())
                entity.Property(e => e.CreatedUtc)
                      .HasDefaultValueSql("GETUTCDATE()");
                entity.Property(e => e.UpdatedUtc)
                      .HasDefaultValueSql("GETUTCDATE()");
                entity.Property(e => e.LastFetchedUtc)
                      .HasDefaultValueSql("GETUTCDATE()");

                // CacheCount defaults to 0
                entity.Property(e => e.CacheCount)
                      .HasDefaultValue(0);
            });

            // ---------------------------------------- Configure AddressCache entity ----------------------------------------
            modelBuilder.Entity<AddressCache>(entity =>
            {
                entity.HasKey(e => e.Id);

                // FormattedAddress: required, max length 500
                entity.Property(e => e.FormattedAddress)
                      .HasMaxLength(500)
                      .IsRequired();

                // Line1, Line2, Town, County: max lengths
                entity.Property(e => e.Line1)
                      .HasMaxLength(250);
                entity.Property(e => e.Line2)
                      .HasMaxLength(250);
                entity.Property(e => e.Town)
                      .HasMaxLength(250);
                entity.Property(e => e.County)
                      .HasMaxLength(250);

                // Country: required, max length 100
                entity.Property(e => e.Country)
                      .HasMaxLength(100)
                      .IsRequired();

                // Uprn, LocalAuthority, AuthorityCode: max lengths
                entity.Property(e => e.Uprn)
                      .HasMaxLength(20);
                entity.Property(e => e.LocalAuthority)
                      .HasMaxLength(250);
                entity.Property(e => e.AuthorityCode)
                      .HasMaxLength(20);

                // CreatedUtc default to GETUTCDATE()
                entity.Property(e => e.CreatedUtc)
                      .HasDefaultValueSql("GETUTCDATE()");

                // Configure foreign key relationship (cascade delete)
                entity.HasOne(e => e.PostcodeCache)
                      .WithMany(pc => pc.Addresses)
                      .HasForeignKey(e => e.PostcodeCacheId)
                      .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}