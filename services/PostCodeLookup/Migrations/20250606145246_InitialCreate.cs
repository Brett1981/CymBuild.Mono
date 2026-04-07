using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PostCodeLookup.Migrations
{
    /// <inheritdoc/>
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PostcodeCaches",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Postcode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()"),
                    UpdatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()"),
                    LastFetchedUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()"),
                    CacheCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PostcodeCaches", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AddressCaches",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PostcodeCacheId = table.Column<int>(type: "int", nullable: false),
                    FormattedAddress = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Line1 = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    Line2 = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    Town = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    County = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    Country = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Uprn = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    LocalAuthority = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                    AuthorityCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AddressCaches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AddressCaches_PostcodeCaches_PostcodeCacheId",
                        column: x => x.PostcodeCacheId,
                        principalTable: "PostcodeCaches",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AddressCaches_PostcodeCacheId",
                table: "AddressCaches",
                column: "PostcodeCacheId");

            migrationBuilder.CreateIndex(
                name: "IX_PostcodeCaches_Postcode",
                table: "PostcodeCaches",
                column: "Postcode",
                unique: true);
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AddressCaches");

            migrationBuilder.DropTable(
                name: "PostcodeCaches");
        }
    }
}