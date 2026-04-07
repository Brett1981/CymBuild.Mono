using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CymBuild_AIErrorServiceAPI.Migrations
{
    /// <inheritdoc/>
    public partial class AddJiraLastSyncedAndPriority : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "JiraLastSyncedUtc",
                table: "AiErrorReports",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "JiraPriority",
                table: "AiErrorReports",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "JiraLastSyncedUtc",
                table: "AiErrorReports");

            migrationBuilder.DropColumn(
                name: "JiraPriority",
                table: "AiErrorReports");
        }
    }
}