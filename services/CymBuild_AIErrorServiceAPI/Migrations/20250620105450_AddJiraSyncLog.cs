using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CymBuild_AIErrorServiceAPI.Migrations
{
    /// <inheritdoc/>
    public partial class AddJiraSyncLog : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "JiraSyncLogs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    StartedUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndedUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Success = table.Column<bool>(type: "bit", nullable: false),
                    Message = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JiraSyncLogs", x => x.Id);
                });
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "JiraSyncLogs");
        }
    }
}