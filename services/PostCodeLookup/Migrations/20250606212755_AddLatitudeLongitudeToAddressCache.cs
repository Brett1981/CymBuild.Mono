using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PostCodeLookup.Migrations
{
    /// <inheritdoc/>
    public partial class AddLatitudeLongitudeToAddressCache : Migration
    {
        /// <inheritdoc/>
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "Latitude",
                table: "AddressCaches",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "Longitude",
                table: "AddressCaches",
                type: "float",
                nullable: true);
        }

        /// <inheritdoc/>
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "AddressCaches");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "AddressCaches");
        }
    }
}