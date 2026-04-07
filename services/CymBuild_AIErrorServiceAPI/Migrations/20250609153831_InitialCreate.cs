using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CymBuild_AIErrorServiceAPI.Migrations
{
    /// <inheritdoc/>
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AiErrorReports",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Hash = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ErrorMessage = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    StackTrace = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ContextJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    AiAnalysis = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    JiraTicketKey = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    JiraUrl = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    JiraStatus = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    JiraTicketCreated = table.Column<bool>(type: "bit", nullable: false),
                    IsResolved = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AiErrorReports", x => x.Id);
                });
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AiErrorReports");
        }
    }
}