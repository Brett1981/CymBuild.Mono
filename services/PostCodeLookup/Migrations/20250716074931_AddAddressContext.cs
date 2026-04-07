using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PostCodeLookup.Migrations
{
    /// <inheritdoc/>
    public partial class AddAddressContext : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Context",
                table: "AddressCaches",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Context",
                table: "AddressCaches");
        }
    }
}