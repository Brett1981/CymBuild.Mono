using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CymBuild_AIErrorServiceAPI.Migrations
{
    /// <inheritdoc/>
    public partial class AddJiraDescriptionToAiErrorReports : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "JiraDescription",
                table: "AiErrorReports",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "JiraDescription",
                table: "AiErrorReports");
        }
    }
}