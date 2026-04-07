#!/bin/bash

# Define variables
MIGRATION_NAME="YourMigrationName" # e.g. "AddProtectionKeysV8_06"
CONTEXT="DataProtectionKeyContext"
SQL_OUTPUT_FILE="MigrationScript.sql"

# Create a new migration
echo "Creating a new migration: $MIGRATION_NAME"
dotnet ef migrations add $MIGRATION_NAME -c $CONTEXT

# Output the SQL script
echo "Generating the SQL script for the migration"
dotnet ef migrations script -c $CONTEXT -o $SQL_OUTPUT_FILE

echo "SQL script has been saved to $SQL_OUTPUT_FILE"