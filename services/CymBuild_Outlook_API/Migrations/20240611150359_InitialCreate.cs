using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CymBuild_Outlook_API.Migrations
{
    /// <inheritdoc/>
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "SOffice");

            migrationBuilder.CreateTable(
                name: "DataProtectionKeys",
                schema: "SOffice",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    FriendlyName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Xml = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DataProtectionKeys", x => x.Id);
                });
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DataProtectionKeys",
                schema: "SOffice");
        }
    }
}