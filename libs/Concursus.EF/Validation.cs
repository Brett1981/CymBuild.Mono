using Concursus.Common.Shared.Extensions;
using Concursus.EF.Types;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Data.SqlClient;

namespace Concursus.EF
{
    public class Validation
    {
        #region Internal Methods

        internal static void ApplyValidationResults(
                ref DataObject dataObject,
                bool rowVersionCheckResult,
                EntityType entityType,
                List<Types.ValidationResult> validationResults,
                Guid hoBTGuid,
                bool ForInformationView,
                bool validateOnly = false
)
        {
            // Reset all data properties to the entity property defaults
            foreach (DataProperty dataProperty in dataObject.DataProperties)
            {
                EntityProperty? entityProperty = entityType.EntityProperties
                    .FirstOrDefault(ep => ep.Guid == dataProperty.EntityPropertyGuid && ep.EntityHoBTGuid == hoBTGuid);

                if (entityProperty is not null)
                {
                    dataProperty.IsReadOnly = ForInformationView ? true : entityProperty.IsReadOnly;
                    dataProperty.IsHidden = entityProperty.IsHidden;
                    dataProperty.IsInvalid = false;
                    dataProperty.ValidationMessage = "";
                }
            }

            // Process the validation results
            foreach (Types.ValidationResult vr in validationResults)
            {
                string targetType = vr.TargetType ?? "";

                if (targetType.Equals("p", StringComparison.OrdinalIgnoreCase))
                {
                    DataProperty? dataProperty = dataObject.DataProperties
                        .FirstOrDefault(p => p.EntityPropertyGuid == vr.TargetGuid);

                    if (dataProperty is not null)
                    {
                        SetDataPropertyValidation(ref dataProperty, vr);
                    }
                }

                if (targetType.Equals("g", StringComparison.OrdinalIgnoreCase))
                {
                    foreach (EntityProperty entityProperty in entityType.EntityProperties
                        .Where(p => p.EntityPropertyGroupGuid == vr.TargetGuid))
                    {
                        DataProperty? dataProperty = dataObject.DataProperties
                            .FirstOrDefault(p => p.EntityPropertyGuid == entityProperty.Guid);

                        if (dataProperty is not null)
                        {
                            SetDataPropertyValidation(ref dataProperty, vr);
                        }
                    }
                }

                if (targetType.Equals("h", StringComparison.OrdinalIgnoreCase))
                {
                    foreach (EntityProperty entityProperty in entityType.EntityProperties
                        .Where(p => p.EntityHoBTGuid == vr.TargetGuid))
                    {
                        DataProperty? dataProperty = dataObject.DataProperties
                            .FirstOrDefault(p => p.EntityPropertyGuid == entityProperty.Guid);

                        if (dataProperty is not null)
                        {
                            SetDataPropertyValidation(ref dataProperty, vr);
                        }
                    }
                }

                if (targetType.Equals("e", StringComparison.OrdinalIgnoreCase))
                {
                    foreach (EntityProperty entityProperty in entityType.EntityProperties
                        .Where(p => p.EntityTypeGuid == vr.TargetGuid))
                    {
                        DataProperty? dataProperty = dataObject.DataProperties
                            .FirstOrDefault(p => p.EntityPropertyGuid == entityProperty.Guid);

                        if (dataProperty is not null)
                        {
                            SetDataPropertyValidation(ref dataProperty, vr);
                        }
                    }
                }
            }

            if (validationResults.Any(v => v.IsInvalid) || dataObject.ValidationResults.Count > 0)
            {
                dataObject.HasValidationMessages = true;
            }
        }

        /// <summary>
        /// Validates whether the proposed row version matches the database version.
        /// </summary>
        internal static async Task<bool> CheckRowVersionMatches(
            EntityType entityType,
            string proposedRowVersion,
            Guid recordGuid,
            SqlConnection connection,
            SqlTransaction transaction)
        {
            EntityHoBT? entityHoBT = entityType.EntityHoBTs.FirstOrDefault(h => h.IsMainHoBT);

            if (entityHoBT == null)
            {
                throw new InvalidOperationException("Main HoBT not found for the entity type.");
            }

            string query = $@"SELECT RowVersion FROM [{entityHoBT.SchemaName}].[{entityHoBT.ObjectName}] WHERE Guid = @Guid";

            await using (var command = QueryBuilder.CreateCommand(query, connection, transaction))
            {
                command.AddParameters(new[]
                {
            new SqlParameter("@Guid", recordGuid)
        });

                await using var reader = await command.ExecuteReaderAsync();
                if (!reader.HasRows)
                {
                    return true; // New record, no validation needed
                }

                while (await reader.ReadAsync())
                {
                    string dbRowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion")));
                    if (dbRowVersion == proposedRowVersion)
                    {
                        return true;
                    }
                }
            }

            return false; // No match found
        }

        internal static bool PropertyHasValue(EntityProperty entityProperty, DataProperty dataProperty)
        {
            if (dataProperty.Value is not null)
            {
                if (dataProperty.Value.TypeUrl == "type.googleapis.com/google.protobuf.Empty")
                {
                    return false;
                }
                else
                {
                    if (entityProperty.DropDownListDefinitionGuid != Guid.Empty)
                    {
                        if (dataProperty.Value.Unpack<StringValue>().Value != Guid.Empty.ToString())
                        {
                            return true;
                        }
                        else
                        {
                            return false;
                        }
                    }
                    else if (entityProperty.EntityDataTypeName.ToLower() == "nvarchar" || entityProperty.EntityDataTypeName.ToLower() == "nvarchar(max)")
                    {
                        if (dataProperty.Value.Unpack<StringValue>().Value != "")
                        {
                            return true;
                        }
                        else
                        {
                            return false;
                        }
                    }
                    else if (entityProperty.EntityDataTypeName.ToLower() == "int")
                    {
                        if (dataProperty.Value.Unpack<Int32Value>().Value != 0)
                        {
                            return true;
                        }
                        else
                        {
                            return false;
                        }
                    }
                    else if (entityProperty.EntityDataTypeName.ToLower() == "bigint")
                    {
                        if (dataProperty.Value.Unpack<Int64Value>().Value != 0)
                        {
                            return true;
                        }
                        else
                        {
                            return false;
                        }
                    }
                    else if (entityProperty.EntityDataTypeName.ToLower() == "double")
                    {
                        if (dataProperty.Value.Unpack<DoubleValue>().Value != 0)
                        {
                            return true;
                        }
                        else
                        {
                            return false;
                        }
                    }
                    else if ((entityProperty.EntityDataTypeName.ToLower() == "bool"))
                    {
                        return true;
                    }
                    else if ((entityProperty.EntityDataTypeName.ToLower() == "datetime2"))
                    {
                        return true;
                    }
                    else if ((entityProperty.EntityDataTypeName.ToLower() == "date"))
                    {
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                }
            }
            else
            {
                return false;
            }
        }

        internal static async Task<List<ValidationResult>> RunObjectValidation(EntityType entityType, DataObject dataObject, SqlConnection connection, EntityHoBT entityHoBT, SqlTransaction? transaction = null)
        {
            EntityQuery? query = new();
            List<ValidationResult> results = new();

            query = entityType.EntityQueries.Where(q => q.IsDefaultValidation == true && q.EntityHoBTGuid == entityHoBT.Guid).FirstOrDefault();

            if (query is not null)
            {
                using (SqlCommand command = QueryBuilder.BuildCommandForEntityQuery(query, dataObject, new List<EntityQueryParameterValue>(), connection, transaction))
                {
                    using (SqlDataReader reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            results.Add(new ValidationResult()
                            {
                                TargetGuid = reader.GetGuid(reader.GetOrdinal("TargetGuid")),
                                TargetType = reader.GetString(reader.GetOrdinal("TargetType")).ToUpper() ?? "",
                                IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
                                IsInformationOnly = reader.GetBoolean(reader.GetOrdinal("IsInformationOnly")),
                                IsInvalid = reader.GetBoolean(reader.GetOrdinal("IsInvalid")),
                                IsReadOnly = reader.GetBoolean(reader.GetOrdinal("IsReadOnly")),
                                Message = reader.GetString(reader.GetOrdinal("Message")) ?? ""
                            });
                        }
                    }
                }
            }

            // Apply the standard validations to properties
            foreach (EntityProperty ep in entityType.EntityProperties.Where(p => p.EntityHoBTGuid == entityHoBT.Guid))
            {
                // Get the data Object
                DataProperty? dataProperty = dataObject.DataProperties.Where(dp => dp.EntityPropertyGuid == ep.Guid).FirstOrDefault();

                if (dataProperty is not null)
                {
                    bool changed = false;
                    Types.ValidationResult validationResult = new()
                    {
                        TargetGuid = ep.Guid,
                        TargetType = "p",
                        Message = "",
                        IsHidden = false,
                        IsInvalid = false,
                        IsReadOnly = false,
                    };

                    // Get the existing Validation Results if there is one.
                    Types.ValidationResult? existingValidationResult = new()
                    {
                        TargetGuid = Guid.Empty
                    };

                    existingValidationResult = results.Where(r => r.TargetType == "P" && r.TargetGuid == ep.Guid).FirstOrDefault();

                    if (existingValidationResult is not null)
                    {
                        validationResult.IsReadOnly = existingValidationResult.IsReadOnly;
                        validationResult.IsHidden = existingValidationResult.IsHidden;
                        validationResult.IsInvalid = existingValidationResult.IsInvalid;
                        validationResult.Message = existingValidationResult.Message;
                    }

                    if (
                            ep.IsCompulsory
                            && PropertyHasValue(ep, dataProperty) == false
                       )
                    {
                        validationResult.IsInvalid = true;
                        validationResult.Message = "The value is compulsory.";
                        changed = true;
                    }

                    if (ep.IsHidden)
                    {
                        validationResult.IsHidden = true;
                        changed = true;
                    }

                    if (ep.IsReadOnly
                        || (ep.IsImmutable
                            && dataObject.RowStatus != 0
                            && PropertyHasValue(ep, dataProperty) == true
                        )
                        )
                    {
                        validationResult.IsReadOnly = true;
                        changed = true;
                    }

                    if (changed)
                    {
                        if (existingValidationResult != null)
                        {
                            if (existingValidationResult.TargetGuid != Guid.Empty)
                            {
                                results.Remove(existingValidationResult);
                            }
                        }

                        results.Add(validationResult);
                    }
                }
            }

            return results;
        }

        internal static void SetDataPropertyValidation(ref DataProperty dataProperty, Types.ValidationResult validationResult)
        {
            dataProperty.ValidationMessage = validationResult.Message;
            dataProperty.IsInvalid = validationResult.IsInvalid;
            dataProperty.IsReadOnly = (validationResult.IsReadOnly ? validationResult.IsReadOnly : dataProperty.IsReadOnly);

            dataProperty.IsHidden = (validationResult.IsHidden ? validationResult.IsHidden : dataProperty.IsHidden);
        }

        #endregion Internal Methods
    }
}