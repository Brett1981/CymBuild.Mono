using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using Concursus.API.Core;
using Microsoft.Graph;
using Azure.Identity;
using System.Data;
using System.Security.Principal;

namespace Concursus.API.EntityFramework
{
    internal class Core
    {
        protected readonly string _connectionString;
        protected readonly IConfiguration _configuration;   
        internal Logging logger;
        internal bool useLegacyUserTables;
        internal System.Security.Claims.ClaimsPrincipal user;
        protected int _userId = -1;

        internal Core(
            IConfiguration configuration,
            string connectionString,
            Logging logger,
            bool useLegacyUserTables,
            System.Security.Claims.ClaimsPrincipal user)
        {
            _configuration = configuration;
            _connectionString = connectionString;
            this.user = user;
            this.useLegacyUserTables = useLegacyUserTables;
            this.logger = logger;
        }

        #region SQL Client
        public SqlConnection CreateConnection()
        {
            SqlConnection conn = new SqlConnection(_connectionString);

            return conn;
        }

        public async Task<bool> OpenConnectionAsync(SqlConnection connection)
        {
            if (connection.State == System.Data.ConnectionState.Closed)
            {
                await connection.OpenAsync();

                var command = connection.CreateCommand();

                if (int.Parse(connection.ServerVersion[..2]) >= 14)
                {
                    command.CommandText = "EXECUTE SCore.CreateUserSession @UserEmail=@email;";

                    if (user.Identity is null){
                        throw new Exception ("User has no identity");
                    }

                    command.Parameters.Add(new SqlParameter("email", user.Identity.Name));
                    command.ExecuteNonQuery();
                }

                _userId = await GetCurrentUserId(connection);

                if (logger is not null)
                {
                    logger.UserId = _userId;
                }
            }

            return true;
        }

        public SqlTransaction BeginTransaction(SqlConnection connection, System.Data.IsolationLevel isolationLevel = System.Data.IsolationLevel.Serializable)
        {
            SqlTransaction transaction = connection.BeginTransaction(isolationLevel);

            return transaction;
        }

        public SqlCommand CreateCommand(string statement, SqlConnection connection, SqlTransaction? transaction = null)
        {
            SqlCommand cmd = connection.CreateCommand();
            if (statement != null)
            {
                cmd.CommandText = statement;
            }

            if (transaction != null)
            {
                cmd.Transaction = transaction;
            }

            logger.LogTrace("Created command for : " + statement);

            return cmd;
        }

        public async void CommitTransactionAsync(SqlTransaction transaction)
        {
            await transaction.CommitAsync();
        }

        public async void RollbackTransactionAsync(SqlTransaction transaction)
        {
            await transaction.RollbackAsync();
        }

        public void CloseConnectionAsync(SqlConnection connection)
        {
            if (connection is not null)
            {
                if (connection.State == System.Data.ConnectionState.Open)
                {
                    connection.CloseAsync();
                }
            }
        }

        #endregion

        #region Entity Definitions
        async protected internal Task<Concursus.API.Core.EntityType> GetEntityType(string guid, bool forRead, bool forWrite)
        {
            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                return await GetEntityType(guid, connection, _userId, forRead, forWrite);
            }
        }

        async protected internal Task<Concursus.API.Core.EntityType> GetEntityType(string guid, SqlConnection connection, Int32 userId, bool forRead, bool forWrite)
        {
            Concursus.API.Core.EntityType entityType = new();

            string sql = $@"SELECT *
                FROM  SCore.tvf_EntityTypes (@Guid, @UserId)";

                using (var command = new SqlCommand(sql, connection))
                {
                    command.Parameters.Add(new SqlParameter("@guid", guid));
                    command.Parameters.Add(new SqlParameter("@userId", userId));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            entityType = new()
                            {
                                RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                IsReadOnlyOffline = reader.GetBoolean(reader.GetOrdinal("IsReadOnlyOffline")),
                                IsRequiredSystemData = reader.GetBoolean(reader.GetOrdinal("IsRequiredSystemData")),
                                HasDocuments = reader.GetBoolean(reader.GetOrdinal("HasDocuments")),
                                LanguageLabelGuid = reader.GetGuid(reader.GetOrdinal("LanguageLabelGuid")).ToString(),
                                DoNotTrackChanges = reader.GetBoolean(reader.GetOrdinal("DoNotTrackChanges")),
                                Label = reader.GetString(reader.GetOrdinal("Label")),
                            };

                            entityType.ObjectSecurity.Add(new ObjectSecurity()
                            {
                                CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite")),
                            });
                        }
                    }
                }

                if (entityType.Guid != "")
                {
                    sql = $@"SELECT *
                        FROM SCore.tvf_PropertyGroupsForEntityType ( @Guid, @UserId )";

                    using (var command = new SqlCommand(sql, connection))
                    {
                        command.Parameters.Add(new SqlParameter("@Guid", entityType.Guid));
                        command.Parameters.Add(new SqlParameter("@UserId", userId));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                EntityPropertyGroup entityPropertyGroup = new()
                                {
                                    RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                                    RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    LanguageLabelGuid = reader.GetGuid(reader.GetOrdinal("LanguageLabelGuid")).ToString(),
                                    SortOrder = reader.GetInt16(reader.GetOrdinal("SortOrder")),
                                    Label = reader.GetString(reader.GetOrdinal("Label")),
                                };

                                entityType.ObjectSecurity.Add(new ObjectSecurity()
                                {
                                    CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                    CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite")),
                                });

                                entityType.EntityPropertyGroups.Add(entityPropertyGroup);
                            }
                        }
                    }

                    sql = $@"SELECT *
                            FROM SCore.tvf_HoBTsForEntityType ( @Guid, @UserId )";

                    using (var command = new SqlCommand(sql, connection))
                    {
                        command.Parameters.Add(new SqlParameter("@Guid", entityType.Guid));
                        command.Parameters.Add(new SqlParameter("@UserId", userId));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                EntityHoBT entityHoBT = new()
                                {
                                    RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                                    RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                    SchemaName = reader.GetString(reader.GetOrdinal("SchemaName")),
                                    ObjectName = reader.GetString(reader.GetOrdinal("ObjectName")),
                                    EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")).ToString(),
                                    ObjectType = reader.GetString(reader.GetOrdinal("ObjectType")),
                                    IsMainHoBT = reader.GetBoolean(reader.GetOrdinal("IsMainHoBT")),
                                    IsReadOnlyOffline = reader.GetBoolean(reader.GetOrdinal("IsReadOnlyOffline"))
                                };

                                entityHoBT.ObjectSecurity.Add(new ObjectSecurity()
                                {
                                    CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                    CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite")),
                                });

                                entityType.EntityHoBTs.Add(entityHoBT);
                            }
                        }
                    }

                    sql = $@"SELECT *
                        FROM SCore.tvf_PropertiesForEntityType ( @Guid, @UserId )";

                    using (var command = new SqlCommand(sql, connection))
                    {
                        command.Parameters.Add(new SqlParameter("@Guid", entityType.Guid));
                        command.Parameters.Add(new SqlParameter("@UserId", userId));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                EntityProperty entityProperty = new()
                                {
                                    RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                                    RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    LanguageLabelGuid = reader.GetGuid(reader.GetOrdinal("LanguageLabelGuid")).ToString(),
                                    EntityDataTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityDataTypeGuid")).ToString(),
                                    IsReadOnly = reader.GetBoolean(reader.GetOrdinal("IsReadOnly")),
                                    IsImmutable = reader.GetBoolean(reader.GetOrdinal("IsImmutable")),
                                    IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
                                    IsCompulsory = reader.GetBoolean(reader.GetOrdinal("IsCompulsory")),
                                    MaxLength = reader.GetInt32(reader.GetOrdinal("MaxLength")),
                                    Precision = reader.GetInt32(reader.GetOrdinal("Precision")),
                                    Scale = reader.GetInt32(reader.GetOrdinal("Scale")),
                                    DoNotTrackChanges = reader.GetBoolean(reader.GetOrdinal("DoNotTrackChanges")),
                                    EntityDataTypeName = reader.GetString(reader.GetOrdinal("EntityDataTypeName")),
                                    EntityPropertyGroupGuid = reader.GetGuid(reader.GetOrdinal("EntityPropertyGroupGuid")).ToString(),
                                    Label = reader.GetString(reader.GetOrdinal("Label")),
                                    DropDownListDefinitionGuid = reader.GetGuid(reader.GetOrdinal("DropDownListDefinitionGuid")).ToString(),
                                    IsObjectLabel = reader.GetBoolean(reader.GetOrdinal("IsObjectLabel")),
                                    IsParentRelationship = reader.GetBoolean(reader.GetOrdinal("IsParentRelationship")),
                                    EntityHoBTGuid = reader.GetGuid(reader.GetOrdinal("EntityHoBTGuid")).ToString(),
                                    SortOrder = reader.GetInt16(reader.GetOrdinal("SortOrder")),
                                    GroupSortOrder = reader.GetInt16(reader.GetOrdinal("GroupSortOrder"))
                                };

                                entityProperty.ObjectSecurity.Add(new ObjectSecurity()
                                {
                                    CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                    CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite")),
                                });

                                entityType.EntityProperties.Add(entityProperty);
                            }
                        }
                    }

                    foreach (EntityProperty entityProperty in entityType.EntityProperties)
                    {
                        sql = $@"SELECT epd.ID, epd.RowStatus, epd.Guid, epd.RowVersion, ep.Guid as ParentEntityPropertyID, dep.Guid as DependantPropertyID
                            FROM SCore.EntityPropertyDependants epd 
                            JOIN SCore.EntityProperties ep ON (ep.ID = epd.ParentEntityPropertyID)
                            JOIN SCore.EntityProperties dep on (dep.ID = epd.DependantPropertyID)
                            WHERE (ep.Guid = @ParentPropertyGuid)";

                        using (var command = new SqlCommand(sql, connection))
                        {
                            command.Parameters.Add(new SqlParameter("@ParentPropertyGuid", entityProperty.Guid));

                            using (var reader = await command.ExecuteReaderAsync())
                            {
                                while (await reader.ReadAsync())
                                {
                                    EntityPropertyDependant entityPropertyDependant = new()
                                    {
                                        RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                                        RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                        Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                        ParentEntityPropertyGuid = reader.GetGuid(reader.GetOrdinal("ParentEntityPropertyID")).ToString(),
                                        DependantEntityPropertyGuid = reader.GetGuid(reader.GetOrdinal("DependantPropertyID")).ToString()
                                    };

                                    entityProperty.DependantProperties.Add(entityPropertyDependant);
                                }
                            }
                        }
                    }

                    sql = $@"SELECT *
                        FROM [SCore].[tvf_QueriesForEntityType] (@Guid, @UserId)";

                    using (var command = new SqlCommand(sql, connection))
                    {
                        command.Parameters.Add(new SqlParameter("@Guid", guid));
                        command.Parameters.Add(new SqlParameter("@UserId", userId));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                EntityQuery entityQuery = new EntityQuery()
                                {
                                    RowStatus = reader.GetByte(reader.GetOrdinal("RowStatus")),
                                    RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Statement = reader.GetString(reader.GetOrdinal("Statement")),
                                    EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")).ToString(),
                                    IsDefaultCreate = reader.GetBoolean(reader.GetOrdinal("IsDefaultCreate")),
                                    IsDefaultRead = reader.GetBoolean(reader.GetOrdinal("IsDefaultRead")),
                                    IsDefaultUpdate = reader.GetBoolean(reader.GetOrdinal("IsDefaultUpdate")),
                                    IsDefaultDelete = reader.GetBoolean(reader.GetOrdinal("IsDefaultDelete")),
                                    IsScalarExecute = reader.GetBoolean(reader.GetOrdinal("IsScalarExecute")),
                                    EntityHoBTGuid = reader.GetGuid(reader.GetOrdinal("EntityHoBTGuid")).ToString(),
                                    IsDefaultValidation = reader.GetBoolean(reader.GetOrdinal("IsDefaultValidation")),
                                    IsDefaultDataPills = reader.GetBoolean(reader.GetOrdinal("IsDefaultDataPills")),
                                    IsDefaultProgressData = reader.GetBoolean(reader.GetOrdinal("IsProgressData"))
                                };

                                entityType.EntityQueries.Add(entityQuery);
                            }
                        }
                    }

                    foreach (EntityQuery entityQuery in entityType.EntityQueries) {
                        sql = $@"SELECT *
                        FROM SCore.tvf_ParametersForEntityQuery (@Guid, @UserId)";

                        using (var command = new SqlCommand(sql, connection))
                        {
                            command.Parameters.Add(new SqlParameter("@Guid", entityQuery.Guid));
                            command.Parameters.Add(new SqlParameter("@UserId", userId));

                            using (var reader3 = await command.ExecuteReaderAsync())
                            {
                                while (await reader3.ReadAsync())
                                {
                                    EntityQueryParameter entityQueryParameter = new()
                                    {
                                        RowStatus = reader3.GetByte(reader3.GetOrdinal("RowStatus")),
                                        RowVersion = Convert.ToBase64String(reader3.GetFieldValue<byte[]>(reader3.GetOrdinal("RowVersion"))),
                                        Guid = reader3.GetGuid(reader3.GetOrdinal("Guid")).ToString(),
                                        Name = reader3.GetString(reader3.GetOrdinal("Name")),
                                        MappedEntityPropertyGuid = reader3.GetGuid(reader3.GetOrdinal("MappedEntityPropertyGuid")).ToString()
                                    };

                                    EntityDataType entityDataType = new()
                                    {
                                        RowStatus = reader3.GetByte(reader3.GetOrdinal("EdtRowStatus")),
                                        RowVersion = Convert.ToBase64String(reader3.GetFieldValue<byte[]>(reader3.GetOrdinal("EdtRowVersion"))),
                                        Guid = reader3.GetGuid(reader3.GetOrdinal("EdtGuid")).ToString(),
                                        Name = reader3.GetString(reader3.GetOrdinal("EdtName")),
                                    };

                                    entityQueryParameter.EntityDataType = entityDataType;

                                    entityQuery.EntityQueryParameters.Add(entityQueryParameter);
                                }
                            }
                        }
                    }                    
                }
           
            ObjectSecurity? objectSecurity = entityType.ObjectSecurity.FirstOrDefault();

            if (objectSecurity != null) 
            {
                if (forRead)
                {
                    if (objectSecurity.CanRead == false)
                    {
                        string message = "You do not have permission to read objects of this type.";
                        throw new RpcException(new Grpc.Core.Status(StatusCode.PermissionDenied, message), message);
                    }
                }

                if (forWrite)
                {
                    if (objectSecurity.CanRead == false)
                    {
                        string message = "You do not have permission to create or modify objects of this type.";
                        throw new RpcException(new Grpc.Core.Status(StatusCode.PermissionDenied, message), message);
                    }
                }
            }

            return entityType;
        }

        #endregion

        #region Data Manipulation

        public async Task<DataObjectGetResponse> DataObjectGet(DataObjectGetRequest request)
        {
            DataObjectGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                Concursus.API.Core.EntityType entityType = await GetEntityType(request.EntityTypeGuid, true, false);               

                Concursus.API.Core.DataObject dataObject = new()
                {
                    EntityTypeGuid = request.EntityTypeGuid
                };

                // check read permissions for the current user and the requested data object guid.
                List<ObjectSecurity> securityList = new List<ObjectSecurity>();
                string securityStatement = "SELECT ObjectGuid, CanRead, CanWrite FROM SCore.ObjectSecurityForUser (@ObjectGuid, @UserId)";

                using (var command = CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@ObjectGuid", request.Guid.ToString()));
                    command.Parameters.Add(new SqlParameter("@UserId", _userId));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            ObjectSecurity objectSecurity = new ObjectSecurity()
                            {
                                ObjectGuid = reader.GetGuid(reader.GetOrdinal("ObjectGuid")).ToString(),
                                CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite"))
                            };

                            securityList.Add(objectSecurity);
                        }
                    }
                }

                ObjectSecurity? securityListItem = securityList.FirstOrDefault();

                if (securityListItem != null){
                    if (securityListItem.CanRead == false)
                    {
                        string message = "You do not have permission to read this object.";
                        throw new RpcException(new Grpc.Core.Status(StatusCode.PermissionDenied, message), message);
                    }
                }

                // foreach hobt order by IsMainHoBT desc
                foreach (EntityHoBT eh in entityType.EntityHoBTs.OrderByDescending(h => h.IsMainHoBT))
                {
                    dataObject = await ReadEntityHoBT(connection, dataObject, entityType, eh, request.EntityQueryGuid, request.Guid);
                }

                rsl.DataObject = dataObject;

                List<DataPill> dataPills = await ReadDataPills(entityType, dataObject, connection, null);

                if (dataPills != null)
                {
                    rsl.DataObject.DataPills.Add(dataPills);
                }

                ProgressData progressData = await ReadProgressData(entityType, dataObject, connection, null);

                if (progressData != null)
                {
                    rsl.DataObject.ProgressData = progressData;
                }

                if (entityType.HasDocuments)
                {
                    Components.SharePoint sharePoint = new(_configuration);
                    dataObject.SharePointUrl =  await sharePoint.GetSharePointLocation(entityType.Guid, rsl.DataObject, connection, null);
                }
            }

            return rsl;
        }

        private async Task<API.Core.DataObject> ReadEntityHoBT (SqlConnection connection, API.Core.DataObject dataObject, EntityType entityType, EntityHoBT hobt, string requestQueryGuid, string requestGuid)
        {
            try
            {
                EntityQuery readQuery = new();
                EntityQuery validationQuery;

                // get the read and validation queries for the HoBT
                foreach (EntityQuery eq in entityType.EntityQueries.Where(q => q.EntityHoBTGuid == hobt.Guid))
                {
                    if (eq.Guid == requestQueryGuid)
                    {
                        readQuery = eq;
                    }
                    else if (eq.IsDefaultRead == true && requestQueryGuid == "")
                    {
                        readQuery = eq;
                    }
                    else if (eq.IsDefaultValidation == true)
                    {
                        validationQuery = eq;
                    }
                }

                // Read the data from the data object 
                if (readQuery.Guid != "")
                {
                    string statement = (readQuery.Statement.Contains("WHERE")) ? readQuery.Statement[..readQuery.Statement.IndexOf("WHERE")] : readQuery.Statement;
                    string statementPredicate = "";

                    if (readQuery.Statement.Contains("ORDER BY"))
                    {
                        logger.LogError("Entity Framework Pre-Validation Error; The Entity Query cannot include the 'ORDER BY' clause.");
                    }

                    if (readQuery.Statement.Contains("OFFSET"))
                    {
                        logger.LogError("Entity Framework Pre-Validation Error; The Entity Query cannot include the 'OFFSET' clause.");
                    }

                    string guidParameterGuid = "B8FE15643BC4478B9CDE0F2B5FF6F503";
                    List<DataObjectCompositeFilter> dataObjectCompositeFilters = new List<DataObjectCompositeFilter>();
                    DataObjectCompositeFilter dataObjectCompositeFilter = new DataObjectCompositeFilter();
                    dataObjectCompositeFilter.Filters.Add(new DataObjectFilter()
                    {
                        ColumnName = "[root_hobt].[Guid]",
                        Operator = "eq",
                        Guid = guidParameterGuid,
                        Value = new() { StringValue = requestGuid.ToString() },
                    });
                    dataObjectCompositeFilters.Add(dataObjectCompositeFilter);

                    statementPredicate = DataObjectCompositeFilterListToPredicate(readQuery.Statement, dataObjectCompositeFilters);

                    using (var command = CreateCommand(statement + statementPredicate, connection))
                    {
                        // Build the parameters for the Query
                        command.Parameters.Add(new SqlParameter("@" + guidParameterGuid, requestGuid.ToString()));

                        // Run the Query
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                for (int i = 0; i < reader.FieldCount; i++)
                                {
                                    dataObject = ReadEntityProperty(reader, dataObject, i, entityType, hobt.Guid);
                                }
                            }
                        }
                    }

                    try{
                        // Get the validation results from the temp table.
                        List<Types.ValidationResult> validationResults = await RunObjectValidation(entityType, dataObject, connection, hobt);

                        ApplyValidationResults(ref dataObject, true, entityType, validationResults, hobt.Guid);
                    }
                    catch (Exception ex)
                    {
                        throw new Exception ("Exception occured while running object validation : " + ex.Message);
                    }
                }
                else
                {
                    throw new Exception("No read query was found for the entity type " + entityType.Name);
                }

                // before returning the object, ensure we got values for all the properties. 
                foreach (EntityProperty property in entityType.EntityProperties.Where(ep => ep.EntityHoBTGuid == hobt.Guid))
                {
                    if (property.Name.ToLower() == "rowstatus" && dataObject.RowStatus == 0)
                    {
                        throw new Exception("No data returned for the RowStatus or the RowStatus was 0.");
                    }
                    else if (property.Name.ToLower() == "rowversion" && dataObject.RowVersion == "")
                    {
                        throw new Exception("No data returned for the Row Version.");
                    }
                    else if (property.Name.ToLower() == "guid" && dataObject.Guid == "")
                    {
                        throw new Exception("No data returned for the record Guid.");
                    }
                    else
                    {
                        if ((dataObject.DataProperties.Where(dp => dp.EntityPropertyGuid == property.Guid).Any() == false)
                            && (property.Name.ToLower() != "guid")
                            && (property.Name.ToLower() != "rowversion")
                            && (property.Name.ToLower() != "rowstatus")
                            && (property.Name.ToLower() != "id"))
                        {
                            logger.LogWarning($"No data returned for property {property.Name}.");
                        }
                    }
                }

                return dataObject;
            }
            catch (Exception ex)
            {
                throw new Exception($"Error reading HoBT {hobt.ObjectName} : {ex.Message}.");
            }
        }

        private API.Core.DataObject ReadEntityProperty(SqlDataReader reader, API.Core.DataObject dataObject, int fieldIndex, EntityType entityType, string hobtGuid)
        {
            try {
                string fieldName = reader.GetName(fieldIndex).ToLower();
                               

                if (fieldName == "rowstatus")
                {
                    dataObject.RowStatus = reader.GetByte(fieldIndex);
                }
                else if (fieldName == "id")
                {
                    if (System.Type.GetTypeCode(reader.GetFieldType(fieldIndex)) == TypeCode.Int64)
                    {
                        dataObject.DatabaseId = reader.GetInt64(fieldIndex);
                    }
                    else
                    {
                        dataObject.DatabaseId = long.Parse(reader.GetInt32(fieldIndex).ToString());
                    }
                }
                else if (fieldName == "guid")
                {
                    dataObject.Guid = reader.GetGuid(fieldIndex).ToString();
                }
                else if (fieldName == "rowversion")
                {
                    dataObject.RowVersion = Convert.ToBase64String((byte[])reader.GetValue(reader.GetOrdinal("RowVersion")));
                }
                else
                {
                    EntityProperty? currentProperty = entityType.EntityProperties
                                                .Where(p => p.Name.ToLower() == fieldName && p.EntityHoBTGuid == hobtGuid)
                                                .FirstOrDefault();

                    if (currentProperty != null){                  
                        DataProperty property = new DataProperty()
                        {
                            EntityPropertyGuid = currentProperty.Guid,
                        };

                        ObjectSecurity? objectSecurity = currentProperty.ObjectSecurity.FirstOrDefault();
                        bool CanRead = false;
                        bool CanWrite = false;

                        if (objectSecurity != null)
                        {
                            CanRead = objectSecurity.CanRead;
                            CanWrite = objectSecurity.CanWrite;
                        }

                        if (CanRead == false)
                        {
                            property.IsRestricted = true;
                            property.IsReadOnly = true;
                            property.IsEnabled = false;
                        }
                        else
                        {
                            if (CanWrite == false)
                            {
                                property.IsRestricted = true;
                                property.IsReadOnly = true;
                                property.IsEnabled = true;
                            }

                            if (currentProperty.DropDownListDefinitionGuid != Guid.Empty.ToString())
                            {
                                StringValue stringValue;

                                if (reader.IsDBNull(fieldIndex))
                                {
                                    stringValue = new() { Value = Guid.Empty.ToString() };
                                }
                                else
                                {
                                    stringValue = new() { Value = reader.GetGuid(fieldIndex).ToString() };
                                }
                                
                                if (currentProperty.IsObjectLabel == true)
                                {
                                    dataObject.Label = reader.GetString(fieldIndex);
                                }
                                property.Value = Any.Pack(stringValue);
                            }
                            else
                            {
                                if (reader.IsDBNull(fieldIndex))
                                {
                                    property.Value = Any.Pack(new Empty());
                                }
                                else
                                {
                                    switch (System.Type.GetTypeCode(reader.GetFieldType(fieldIndex)))
                                    {
                                        case TypeCode.String:
                                            StringValue stringValue = new() { Value = reader.GetString(fieldIndex) };
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = reader.GetString(fieldIndex);
                                            }
                                            property.Value = Any.Pack(stringValue);
                                            break;
                                        case TypeCode.Int16:
                                            Int32Value int16Value = new() { Value = reader.GetInt16(fieldIndex) };
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = reader.GetInt16(fieldIndex).ToString();
                                            }
                                            property.Value = Any.Pack(int16Value);
                                            break;
                                        case TypeCode.Int32:
                                            Int32Value int32Value = new() { Value = reader.GetInt32(fieldIndex) };
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = reader.GetInt32(fieldIndex).ToString();
                                            }
                                            property.Value = Any.Pack(int32Value);
                                            break;
                                        case TypeCode.Int64:
                                            Int64Value int64Value = new() { Value = reader.GetInt64(fieldIndex) };
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = reader.GetInt64(fieldIndex).ToString();
                                            }
                                            property.Value = Any.Pack(int64Value);
                                            break;
                                        case TypeCode.Decimal:
                                            DoubleValue doubleValue = new() { Value = Double.Parse(reader.GetDecimal(fieldIndex).ToString()) };
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = reader.GetInt32(fieldIndex).ToString();
                                            }
                                            property.Value = Any.Pack(doubleValue);
                                            break;
                                        case TypeCode.Boolean:
                                            BoolValue boolValue = new() { Value = reader.GetBoolean(fieldIndex) };
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = reader.GetBoolean(fieldIndex).ToString();
                                            }
                                            property.Value = Any.Pack(boolValue);
                                            break;
                                        case TypeCode.DateTime:
                                            Timestamp timestampValue = Timestamp.FromDateTime(new DateTime(reader.GetDateTime(fieldIndex).Ticks, DateTimeKind.Utc));
                                            if (currentProperty.IsObjectLabel == true)
                                            {
                                                dataObject.Label = timestampValue.ToString();
                                            }
                                            property.Value = Any.Pack(timestampValue);
                                            break;
                                    }
                                }
                            }
                        }
                        dataObject.DataProperties.Add(property);
                    }
                    else
                    {
                        logger.LogInformation("There was no Entity Property that matched to the database field " + fieldName);
                    }
                }  
                     
            } catch (Exception ex)
            {
                throw new Exception("Failure reading property " + reader.GetName(fieldIndex).ToLower() + " : " + ex.Message);
            }

            return dataObject;
        }

        private void SetDataPropertyValidation (ref DataProperty dataProperty, Types.ValidationResult validationResult)
        {
            dataProperty.ValidationMessage = validationResult.Message;
            dataProperty.IsInvalid = validationResult.IsInvalid;
            dataProperty.IsReadOnly = (dataProperty.IsReadOnly ? dataProperty.IsReadOnly : validationResult.IsReadOnly);
            dataProperty.IsHidden = (dataProperty.IsHidden ? dataProperty.IsHidden : validationResult.IsHidden);
        }

        private async Task<List<DataPill>> ReadDataPills(Concursus.API.Core.EntityType entityType, Concursus.API.Core.DataObject dataObject, SqlConnection connection, SqlTransaction? transaction = null)
        {
            EntityQuery? query = new();
            List<DataPill> results = new List<DataPill>();

            query = entityType.EntityQueries.Where(q => q.IsDefaultDataPills == true).FirstOrDefault();

            if (query is not null)
            {
                using (var command = BuildCommandForEntityQuery(query, dataObject, new List<EntityQueryParameterValue>(), connection, transaction))
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            results.Add(new DataPill()
                            {
                                Value = reader.GetString(reader.GetOrdinal("Label")),
                                Class = reader.GetString(reader.GetOrdinal("Class")),
                                SortOrder = reader.GetInt32(reader.GetOrdinal("SortOrder"))
                            });
                        }
                    }
                }
            }

            return results;
        }

        private async Task<ProgressData> ReadProgressData(Concursus.API.Core.EntityType entityType, Concursus.API.Core.DataObject dataObject, SqlConnection connection, SqlTransaction? transaction = null)
        {
            EntityQuery? query = new();
            ProgressData result = new ();

            query = entityType.EntityQueries.Where(q => q.IsDefaultProgressData == true).FirstOrDefault();

            if (query is not null)
            {
                using (var command = BuildCommandForEntityQuery(query, dataObject, new List<EntityQueryParameterValue>(), connection, transaction))
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            result.FirstValue = reader.GetInt32(reader.GetOrdinal("FirstValue"));
                            result.FirstDescription = reader.GetString(reader.GetOrdinal("FirstDescription"));
                            result.FirstComplete = reader.GetBoolean(reader.GetOrdinal("FirstComplete"));
                            result.PreviousValue = reader.GetInt32(reader.GetOrdinal("PreviousValue"));
                            result.PreviousDescription = reader.GetString(reader.GetOrdinal("PreviousDescription"));
                            result.PreviousComplete = reader.GetBoolean(reader.GetOrdinal("PreviousComplete"));
                            result.MidValue = reader.GetInt32(reader.GetOrdinal("MidValue"));
                            result.MidDescription = reader.GetString(reader.GetOrdinal("MidDescription"));
                            result.MidComplete = reader.GetBoolean(reader.GetOrdinal("MidComplete"));
                            result.NextValue = reader.GetInt32(reader.GetOrdinal("NextValue"));
                            result.NextDescription = reader.GetString(reader.GetOrdinal("NextDescription"));
                            result.NextComplete = reader.GetBoolean(reader.GetOrdinal("NextComplete"));
                            result.LastValue = reader.GetInt32(reader.GetOrdinal("LastValue"));
                            result.LastDescription = reader.GetString(reader.GetOrdinal("LastDescription"));
                            result.LastComplete = reader.GetBoolean(reader.GetOrdinal("LastComplete"));
                        }
                    }
                }
            }

            return result;
        }

        public async Task<DataObjectListGetResponse> DataObjectListGet(DataObjectListGetRequest request)
        {
            // TODO: Add Security Checks 

            DataObjectListGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                Concursus.API.Core.EntityType entityType = await GetEntityType(request.EntityTypeGuid, true, false);

            EntityQuery readQuery = new();

            EntityProperty? currentProperty;

            foreach (EntityQuery eq in entityType.EntityQueries)
            {
                if (eq.Guid == request.EntityQueryGuid)
                {
                    readQuery = eq;
                    break;
                }
                else if (eq.IsDefaultRead == true && request.EntityQueryGuid == "")
                {
                    readQuery = eq;
                    break;
                }
            }

            if (readQuery.Guid != "")
            {
                string statement = (readQuery.Statement.Contains("WHERE")) ? readQuery.Statement[..readQuery.Statement.IndexOf("WHERE")] : readQuery.Statement;
                string statementPredicate = "";
                string statementSort = "";
                string statementOffset = "";

                if (readQuery.Statement.Contains("ORDER BY"))
                {
                    logger.LogError("Entity Framework Pre-Validation Error; The Entity Query cannot include the 'ORDER BY' clause.");
                }

                if (readQuery.Statement.Contains("OFFSET"))
                {
                    logger.LogError("Entity Framework Pre-Validation Error; The Entity Query cannot include the 'OFFSET' clause.");
                }

                statementPredicate = DataObjectCompositeFilterListToPredicate(readQuery.Statement, request.Predicate.ToList());

                statementPredicate = ReplacePredicateTokens(statementPredicate, request.ParentId, _userId);

                // Build the sorting statements. 
                foreach (DataObjectSort s in request.Sort)
                {
                    if (statementSort != "") { statementSort += ", "; } else { statementSort = " ORDER BY "; };

                    statementSort += " [" + s.ColumnName + "] " + (s.Direction == "Ascending" ? "ASC" : "DESC");
                }

                // Build the paging offset 
                if (request.PageSize > 0)
                {
                    statementOffset = " OFFSET " + (request.PageSize * (request.PageNumber - 1)) + " ROWS FETCH NEXT "
                        + request.PageSize + " ROWS ONLY ";
                }

                

                    using (var command = CreateCommand(statement + statementPredicate + statementSort + statementOffset, connection))
                    {
                        // Build the parameters for the Query
                        foreach (EntityQueryParameter eqp in readQuery.EntityQueryParameters)
                        {
                            EntityQueryParameterValue? entityQueryParameterValue = request.Parameters.Where(p => p.Name == eqp.Name).FirstOrDefault();
                            
                            if (entityQueryParameterValue != null){
                                Any? parameterValue = entityQueryParameterValue.Value;                        

                                switch (eqp.EntityDataType.Name)
                                {
                                    case "nvarchar":
                                        command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<StringValue>()));
                                        break;
                                    case "int":
                                        command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int32Value>()));
                                        break;
                                    case "bigint":
                                        command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int64Value>()));
                                        break;
                                    case "bit":
                                        command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<BoolValue>()));
                                        break;
                                }
                            }
                        }

                        command.Parameters.AddRange(DataObjectCompositeFilterListToSqlParameterList(request.Predicate.ToList()));

                        // Run the Query
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                Concursus.API.Core.DataObject dataObject = new()
                                {
                                    EntityTypeGuid = request.EntityTypeGuid
                                };

                                for (int i = 0; i < reader.FieldCount; i++)
                                {
                                    currentProperty = entityType.EntityProperties
                                        .Where(p => p.Name == reader.GetName(i))
                                        .FirstOrDefault();

                                    if (currentProperty != null)
                                    {
                                        DataProperty property = new DataProperty()
                                        {
                                            EntityPropertyGuid = currentProperty.Guid,
                                        };

                                        switch (reader.GetFieldType(1).ToString())
                                        {
                                            case "string":
                                                StringValue stringValue = new() { Value = reader.GetString(i) };
                                                property.Value = Any.Pack(stringValue);
                                                break;
                                            case "int16":
                                                Int32Value int16Value = new() { Value = reader.GetInt16(i) };
                                                property.Value = Any.Pack(int16Value);
                                                break;
                                            case "int32":
                                                Int32Value int32Value = new() { Value = reader.GetInt32(i) };
                                                property.Value = Any.Pack(int32Value);
                                                break;
                                            case "int64":
                                                Int64Value int64Value = new() { Value = reader.GetInt64(i) };
                                                property.Value = Any.Pack(int64Value);
                                                break;
                                            case "boolean":
                                                BoolValue boolValue = new() { Value = reader.GetBoolean(i) };
                                                property.Value = Any.Pack(boolValue);
                                                break;
                                            case "date":
                                                Timestamp timestampValue = Timestamp.FromDateTime(new DateTime(reader.GetDateTime(i).Ticks, DateTimeKind.Utc));
                                                property.Value = Any.Pack(timestampValue);
                                                break;
                                        }
                                    

                                        dataObject.DataProperties.Add(property);
                                    }
                                }
                            }
                            rsl.PageNumber = request.PageNumber;
                        }
                    }

                    using (var command = CreateCommand("SELECT COUNT(1) FROM " + statement[(statement.IndexOf("FROM") + 5)..] + " " + statementPredicate, connection))
                    {
                        rsl.TotalRows = (int)(command.ExecuteScalar() ?? 0);
                    }
                }
            }

            return rsl;
        }

        private SqlCommand BuildCommandForEntityQuery(EntityQuery entityQuery, Concursus.API.Core.DataObject dataObject, List<EntityQueryParameterValue> entityQueryParameterValues, SqlConnection connection, SqlTransaction? transaction)
        {
            var command = CreateCommand(entityQuery.Statement, connection, transaction);

            // Build the parameters for the Query
            foreach (EntityQueryParameter eqp in entityQuery.EntityQueryParameters)
            {
                try
                {

                
                if (eqp.Name == "@RowStatus")
                {
                    command.Parameters.Add(new SqlParameter(eqp.Name, dataObject.RowStatus));
                    continue;
                }
                else if (eqp.Name == "@Guid")
                {
                    command.Parameters.Add(new SqlParameter(eqp.Name, Guid.Parse(dataObject.Guid)));
                    continue;
                }
                else
                {
                    DataProperty? dataProperty = dataObject.DataProperties
                        .Where<DataProperty>(p => p.EntityPropertyGuid == eqp.MappedEntityPropertyGuid)
                        .FirstOrDefault();

                    Any? parameterValue = null;

                    if (dataProperty != null)
                    {
                        parameterValue = dataProperty.Value;
                    }   

                    if (parameterValue == null && entityQueryParameterValues.Count > 0)
                    {
                        EntityQueryParameterValue? entityQueryParameterValue = entityQueryParameterValues
                            .Where<EntityQueryParameterValue>(eqpv => eqpv.Name == eqp.Name)
                            .FirstOrDefault();

                        if (entityQueryParameterValue != null)
                        {
                            parameterValue = entityQueryParameterValue.Value;
                        }
                    }

                    if (parameterValue == null)
                    {
                        throw new Exception("No value for parameter " + eqp.Name);
                    }
                

                    switch (eqp.EntityDataType.Name)
                    {
                        case "NVARCHAR":
                        case "NVARCHAR(MAX)":
                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<StringValue>().Value));
                            break;
                        case "INT":
                        case "SMALLINT":
                        case "TINYINT":
                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int32Value>().Value));
                            break;
                        case "BIGINT":
                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int64Value>().Value));
                            break;
                        case "DOUBLE":
                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<DoubleValue>().Value));
                            break;
                        case "BIT":
                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<BoolValue>().Value));
                            break;
                        case "DATETIME2":
                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Timestamp>().ToDateTime()));
                            break;
                        case "UNIQUEIDENTIFIER":
                            command.Parameters.Add(new SqlParameter(eqp.Name, Guid.Parse(parameterValue.Unpack<StringValue>().Value)));
                            break;
                        default:
                                throw new NotImplementedException(eqp.EntityDataType.Name + " is not implimented.");
                    }
                
                }
                }
                catch (Exception ex)
                {
                    throw new Exception("Build Command Eception for parameter " + eqp.Name + " : " + ex.Message);
                }
            }

            return command;
        }

        private async Task<List<Types.ValidationResult>> RunObjectValidation(Concursus.API.Core.EntityType entityType, Concursus.API.Core.DataObject dataObject, SqlConnection connection, EntityHoBT entityHoBT, SqlTransaction? transaction = null)
        {
            EntityQuery? query = new();
            List<Types.ValidationResult> results = new List<Types.ValidationResult>();

            query = entityType.EntityQueries.Where(q => q.IsDefaultValidation == true && q.EntityHoBTGuid == entityHoBT.Guid).FirstOrDefault();

            if (query is not null)
            {
                using (var command = BuildCommandForEntityQuery(query, dataObject, new List<EntityQueryParameterValue>(), connection, transaction))
                { 
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            results.Add(new Types.ValidationResult()
                            {
                                TargetGuid = reader.GetGuid(reader.GetOrdinal("TargetGuid")),
                                TargetType = reader.GetString(reader.GetOrdinal("TargetType")).ToUpper() ?? "",
                                IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
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
                    Types.ValidationResult validationResult = new Types.ValidationResult()
                    {
                        TargetGuid = Guid.Parse(ep.Guid),
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

                  
                    existingValidationResult = results.Where(r => r.TargetType == "P" && r.TargetGuid == Guid.Parse(ep.Guid)).FirstOrDefault();
                
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
                            && dataObject.DatabaseId != 0
                            && PropertyHasValue(ep, dataProperty) == true
                        )
                        )
                    {
                        validationResult.IsReadOnly = true;
                        changed |= true;    
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

        private bool PropertyHasValue(EntityProperty entityProperty, DataProperty dataProperty)
        {
            if (dataProperty.Value is not null)
            {
                if (entityProperty.DropDownListDefinitionGuid != Guid.Empty.ToString())
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
                else
                {
                    return false;
                }
            }
            else
            { 
                return false; 
            }
        }

        private void ApplyValidationResults(ref Concursus.API.Core.DataObject dataObject, bool rowVersionCheckResult, Concursus.API.Core.EntityType entityType, List<Types.ValidationResult> validationResults, string hoBTGuid)
        {
            // reset all data properties to the entitiy property defaults.
            foreach (DataProperty dataProperty in dataObject.DataProperties)
            {
                EntityProperty? entityProperty = entityType.EntityProperties.Where(ep => ep.Guid == dataProperty.EntityPropertyGuid && ep.EntityHoBTGuid == hoBTGuid).FirstOrDefault();

                if (entityProperty is not null)
                {
                    dataProperty.IsReadOnly = entityProperty.IsReadOnly;
                    dataProperty.IsHidden = entityProperty.IsHidden;
                    dataProperty.IsInvalid = false;
                    dataProperty.ValidationMessage = "";
                }
            }
            
            // process the validation results. 
            foreach (Types.ValidationResult vr in validationResults)
            {
                string targetType = vr.TargetType ?? "";

                if (targetType.ToLower() == "p")
                {
                    DataProperty? dataProperty = dataObject.DataProperties.Where(p => p.EntityPropertyGuid == vr.TargetGuid.ToString()).FirstOrDefault();

                    if (dataProperty is not null)
                    {
                        SetDataPropertyValidation(ref dataProperty, vr);
                    }
                }

                if (targetType.ToLower() == "g")
                {
                    foreach (EntityProperty entityProperty in entityType.EntityProperties.Where(p => p.EntityPropertyGroupGuid == vr.TargetGuid.ToString()))
                    {
                        DataProperty? dataProperty = dataObject.DataProperties.Where(p => p.EntityPropertyGuid == entityProperty.Guid).FirstOrDefault();

                        if (dataProperty is not null)
                        {
                            SetDataPropertyValidation(ref dataProperty, vr);
                        }
                    }
                }

                if (targetType.ToLower() == "h")
                {
                    foreach (EntityProperty entityProperty in entityType.EntityProperties.Where(p => p.EntityHoBTGuid == vr.TargetGuid.ToString()))
                    {
                        DataProperty? dataProperty = dataObject.DataProperties.Where(p => p.EntityPropertyGuid == entityProperty.Guid).FirstOrDefault();

                        if (dataProperty is not null)
                        {
                            SetDataPropertyValidation(ref dataProperty, vr);
                        }
                    }
                }

                if (targetType.ToLower() == "e")
                {
                    foreach (EntityProperty entityProperty in entityType.EntityProperties.Where(p => p.EntityTypeGuid == vr.TargetGuid.ToString()))
                    {
                        DataProperty? dataProperty = dataObject.DataProperties.Where(p => p.EntityPropertyGuid == entityProperty.Guid).FirstOrDefault();

                        if (dataProperty is not null)
                        {
                            SetDataPropertyValidation(ref dataProperty, vr);
                        }
                    }
                }
            }

            if (validationResults.Where(v => v.IsInvalid == true).ToList().Count > 0)
            {
                dataObject.HasValidationMessages = true;
            }

        }

        private async Task<bool> CheckRowVersionMatches(Concursus.API.Core.EntityType entityType, string ProposedRowVersion, string RecordGuid, SqlConnection connection, SqlTransaction transaction)
        {
            bool matches = false;
            
            EntityHoBT? entityHoBT = entityType.EntityHoBTs.Where(h => h.IsMainHoBT == true).FirstOrDefault();

            if (entityHoBT != null)
            {
                string statement = $@"SELECT RowVersion FROM [{entityHoBT.SchemaName}].[{entityHoBT.ObjectName}] WHERE (Guid=@Guid)";

                using (var command = CreateCommand(statement, connection, transaction))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", RecordGuid));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        if (reader.HasRows == false)
                        {
                            // new record, return true
                            return true;
                        }
                        else
                        {
                            while (reader.Read())
                            {
                                string dbRowVersion = Convert.ToBase64String((byte[])reader.GetValue(reader.GetOrdinal("RowVersion")));

                                if (dbRowVersion == ProposedRowVersion)
                                {
                                    return true;
                                }
                            }
                        }
                    }
                }
            }

            return matches;
        }

        public async Task<DataObjectUpsertResponse> DataObjectUpsert(DataObjectUpsertRequest request)
        {
            DataObjectUpsertResponse rsl = new();
            List<Types.ValidationResult> validationResults = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                Concursus.API.Core.EntityType entityType = await GetEntityType(request.DataObject.EntityTypeGuid, connection, _userId, true, true);
                                
                using (var transaction = BeginTransaction(connection))
                {
                    foreach (EntityHoBT entityHoBT in entityType.EntityHoBTs)
                    {
                        validationResults = await RunObjectValidation(entityType, request.DataObject, connection, entityHoBT, transaction);
                                              
                        var rowversionCheck = await CheckRowVersionMatches(entityType, request.DataObject.RowVersion, request.DataObject.Guid, connection, transaction);

                        // IF the requests is not to validate only 
                        // AND there were no validation messages returned 
                        // THEN update the db record.
                        if (request.ValidateOnly == false && validationResults.Where(v => v.IsInvalid == true).ToList().Count == 0 && rowversionCheck == true)
                        {
                            EntityQuery query = new();

                            foreach (EntityQuery eq in entityType.EntityQueries.Where(eq => eq.EntityHoBTGuid == entityHoBT.Guid))
                            {
                                if (eq.Guid == request.EntityQueryGuid)
                                {
                                    query = eq;
                                    break;
                                }
                                else if (request.DataObject.Guid == "" && eq.IsDefaultCreate == true && request.EntityQueryGuid == "")
                                {
                                    query = eq;
                                    break;
                                }
                                else if (request.DataObject.Guid != "" && eq.IsDefaultUpdate == true && request.EntityQueryGuid == "")
                                {
                                    query = eq;
                                    break;
                                }
                            }

                            if (query.Guid != "")
                            {
                                using (var command = BuildCommandForEntityQuery(query, request.DataObject, request.EntityQueryParameterValues.ToList(), connection, transaction))
                                {
                                    await command.ExecuteScalarAsync();
                                }

                                if (entityType.HasDocuments)
                                {
                                    Components.SharePoint sharePoint = new(_configuration);
                                    await sharePoint.GetSharePointLocation(entityType.Guid, rsl.DataObject, connection, transaction);
                                }

                                CommitTransactionAsync(transaction);

                                //Re-query object for result
                                DataObjectGetResponse dataObjectGetResponse = await DataObjectGet(new DataObjectGetRequest()
                                {
                                    Guid = request.DataObject.Guid,
                                    EntityTypeGuid = request.DataObject.EntityTypeGuid
                                });
                                rsl.DataObject = dataObjectGetResponse.DataObject;
                            }
                        }
                        else
                        {
                            Concursus.API.Core.DataObject dataObject = request.DataObject;
                            ApplyValidationResults(ref dataObject, rowversionCheck, entityType, validationResults, entityHoBT.Guid);

                            List<DataPill> dataPills = await ReadDataPills(entityType, rsl.DataObject, connection, null);

                            if (dataPills != null)
                            {
                                dataObject.DataPills.Add(dataPills);
                            }

                            rsl.DataObject = dataObject;
                        }
                    }                    
                }           
            }

            return rsl;
        }

        public async Task<DataObjectDeleteResponse> DataObjectDelete(DataObjectDeleteRequest request)
        {
            //TODO: Add row version checks 

            DataObjectDeleteResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                Concursus.API.Core.EntityType entityType = await GetEntityType(request.EntityTypeGuid, true, true);
                                   
                using (var transaction = BeginTransaction(connection))
                {
                    var rowversionCheck = await CheckRowVersionMatches(entityType, request.ObjectRowVersion, request.ObjectGuid, connection, transaction);

                    EntityQuery query = new();

                    foreach (EntityQuery eq in entityType.EntityQueries)
                    {
                        if (eq.Guid == request.EntityQueryGuid)
                        {
                            query = eq;
                            break;
                        }
                        else if (eq.IsDefaultDelete == true && request.EntityQueryGuid == "")
                        {
                            query = eq;
                            break;
                        }
                    }

                    if (query.Guid != "")
                    {
                        using (var command = CreateCommand(query.Statement, connection, transaction))
                        {
                            // Build the parameters for the Query
                            foreach (EntityQueryParameter eqp in query.EntityQueryParameters)
                            {
                                EntityQueryParameterValue? entityQueryParameterValue = request.EntityQueryParameterValues
                                    .Where(eqpv => eqpv.Name == eqp.Name)
                                    .FirstOrDefault();

                                if (entityQueryParameterValue != null)
                                {
                                    Any parameterValue = entityQueryParameterValue.Value;
                                
                                    switch (eqp.EntityDataType.Name)
                                    {
                                        case "nvarchar":
                                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<StringValue>()));
                                            break;
                                        case "int":
                                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int32Value>()));
                                            break;
                                        case "bigint":
                                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int64Value>()));
                                            break;
                                        case "bit":
                                            command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<BoolValue>()));
                                            break;
                                    }
                                }
                            }

                            await command.ExecuteScalarAsync();
                        }

                        CommitTransactionAsync(transaction);

                        rsl.Success = true;
                    }
                }
            }

            return rsl;
        }

        public List<DataObjectCompositeFilter> DataObjectCompositeFilterListAddGuid (List<DataObjectCompositeFilter> dataObjectCompositeFilters)
        {
            List<DataObjectCompositeFilter> rsl = new();

            foreach(DataObjectCompositeFilter filter in dataObjectCompositeFilters)
            {
                rsl.Add(DataObjectCompositeFilterAddGuid(filter));
            }

            return rsl; 
        }

        public DataObjectCompositeFilter DataObjectCompositeFilterAddGuid(DataObjectCompositeFilter dataObjectCompositeFilter)
        {
            DataObjectCompositeFilter rsl = new();

            foreach (DataObjectCompositeFilter filter in dataObjectCompositeFilter.CompositeFilters)
            {
                rsl.CompositeFilters.Add(DataObjectCompositeFilterAddGuid(filter));
            }

            foreach (DataObjectFilter filter in dataObjectCompositeFilter.Filters)
            {
                filter.Guid = Guid.NewGuid().ToString();
                rsl.Filters.Add(filter);
            }

            return rsl;
        }

        public SqlParameter[] DataObjectCompositeFilterListToSqlParameterList (List<DataObjectCompositeFilter> predicate)
        {
            SqlParameter[] sqlParameters = new SqlParameter[0];

            if (predicate.Count > 0)
            {
                sqlParameters = DataObjectCompositeFilterToSqlParameterList(predicate[0]);
            }

            return sqlParameters;
        }

        public SqlParameter[] DataObjectCompositeFilterToSqlParameterList(DataObjectCompositeFilter predicate)
        {
            SqlParameter[] sqlParameters = new SqlParameter[0];

            foreach (DataObjectCompositeFilter gdcf in predicate.CompositeFilters)
            {
                sqlParameters.Concat(DataObjectCompositeFilterToSqlParameterList(gdcf));
            }

            foreach (DataObjectFilter gdf in predicate.Filters)
            {
                sqlParameters.Append(new SqlParameter(gdf.Guid, gdf.Value));
            }

            return sqlParameters;
        }

        public string DataObjectCompositeFilterListToPredicate(string sqlQuery, List<DataObjectCompositeFilter> dataObjectCompositeFilters, bool incudeSystem = false)
        {
            string predicate = "";
            int predicateIndex = sqlQuery.IndexOf("WHERE");

            if (predicateIndex > 0)
            {
                predicate = sqlQuery[predicateIndex..];

            }

            if (dataObjectCompositeFilters.Count > 0)
            {
                var predicate2 = DataObjectCompositeToSqlPredicate(dataObjectCompositeFilters[0], "");

                if (predicate != "" && predicate2 != "")
                {
                    predicate += " AND " + predicate2;
                }
                else
                {
                    predicate += predicate2;
                }

                if (predicate != "" && predicateIndex < 0)
                {
                    predicate = " WHERE " + predicate;
                }
            }

            // RowStatus Filter
            if (predicate == "")
            {
                predicate = " WHERE ";
            }
            else
            {
                predicate += " AND ";
            }

            if (incudeSystem)
            {
                predicate += "([root_hobt].[RowStatus] <> " + (int)Enums.RowStatus.Deleted + ")";
            }
            else
            {
                predicate += "(([root_hobt].[RowStatus] <> " + (int)Enums.RowStatus.Deleted + ") AND ([root_hobt].[RowStatus] <> " + (int)Enums.RowStatus.System + "))";
            }

            return predicate;
        }

        private string DataObjectCompositeToSqlPredicate(DataObjectCompositeFilter gridDataCompositeFilter, string LogicalOperator)
        {
            string predicateString = LogicalOperator + ((LogicalOperator != "") ? " (" : "");
            bool requireLogicOperator = false;

            foreach (DataObjectCompositeFilter gdcf in gridDataCompositeFilter.CompositeFilters)
            {
                predicateString += DataObjectCompositeToSqlPredicate(gdcf, requireLogicOperator ? gridDataCompositeFilter.LogicalOperator : "");
                requireLogicOperator = true;
            }

            foreach (DataObjectFilter gdf in gridDataCompositeFilter.Filters)
            {
                if (requireLogicOperator)
                {
                    predicateString += gridDataCompositeFilter.LogicalOperator;
                }
                predicateString += CreatePropertyStatement(gdf.ColumnName, gdf.Operator, gdf.Guid);

                requireLogicOperator = true;
            }

            predicateString += ((LogicalOperator != "") ? ") " : "");

            if (predicateString == " () ")
            {
                predicateString = "";
            }

            return predicateString;
        }

        public static string CreatePropertyStatement(string columnName, string operatorToken, string filterGuid)
        {
            if (columnName.Contains('[') == false)
            {
                columnName = "[" + columnName + "]";
            }
            
            string stmt = " (" + columnName + " ";
            filterGuid = filterGuid.Replace("-", "");

            switch (operatorToken)
            {
                case "eq":
                    stmt += " = @" + filterGuid;
                    break;
                case "neq":
                    stmt += " <> @" + filterGuid;
                    break;
                case "startswith":
                    stmt += " LIKE @" + filterGuid + " + N'%'";
                    break;
                case "contains":
                    stmt += " LIKE N'%' + @" + filterGuid + " + N'%'";
                    break;
                case "notsubstringof":
                    stmt += " NOT LIKE N'%' + @" + filterGuid + " + N'%'";
                    break;
                case "endswith":
                    stmt += " LIKE N'%' + @" + filterGuid;
                    break;
                case "isnull":
                    stmt += " IS NULL";
                    break;
                case "isnotnull":
                    stmt += " IS NOT NULL";
                    break;
                case "isempty":
                    stmt += " = N''";
                    break;
                case "isnotempty":
                    stmt += " <> N''";
                    break;
                case "isnullorempty":
                    stmt += " IS NULL OR [" + columnName + "] = N''";
                    break;
                case "isnotnullorempty":
                    stmt += " IS NOT NULL OR [" + columnName + "] <> N''";
                    break;
            }
            return stmt + ") ";
        }

        public string ReplacePredicateTokens(string sqlQuery, Int64 parentID, Int32 currentUserId)
        {
            if (sqlQuery.Contains("[[CURRENT_USER_ID]]"))
            {
                sqlQuery = sqlQuery.Replace("[[CURRENT_USER_ID]]", currentUserId.ToString());
            }

            sqlQuery = sqlQuery.Replace("[[ParentGuid]]", parentID.ToString());

            return sqlQuery;
        }

        #endregion

        #region Users
        public async Task<int> GetCurrentUserId(SqlConnection connection)
        {
            IIdentity? identity = user.Identity;
            String? identityName = "";

            if (identity != null)
            {
                identityName = identity.Name;
            }

            if (_userId == -1 && identityName != "" && identityName != null)
            {                
                string statement;         

                if (useLegacyUserTables)
                {
                    statement = "SELECT u.UserId " +
                        "FROM dbo.Users u " +
                        "JOIN dbo.Aspnet_Membership m on (m.UserId = u.MembershipId) " +
                        "WHERE (u.LoweredEmail = @UserEmail)";
                }
                else
                {
                    statement = "SELECT i.Id " +
                        "FROM SCore.Identities i " +
                        "WHERE (Lower(i.EmailAddress) = @UserEmail)";
                }

                using (var command = connection.CreateCommand())
                {
                    command.CommandText = statement;
                    command.Parameters.Add(new SqlParameter("@UserEmail", identityName.ToLower()));

                    var result = await command.ExecuteScalarAsync();

                    if (result is null)
                    {
                        var azureAppConfig = _configuration.GetSection("AzureAd");
                        var clientId = azureAppConfig.GetValue<string>("ClientId");
                        var tenantId = azureAppConfig.GetValue<string>("TenantId");
                        var clientSecret = azureAppConfig.GetValue<string>("ClientSecret");

                        GraphServiceClient graphClient;

                        var clientSecretCredential = new ClientSecretCredential(tenantId, clientId, clientSecret);
                        graphClient = new(clientSecretCredential);

                        var userRecord = await graphClient.Users[identityName]
                                .GetAsync();

                        if (userRecord != null) {

                            string createIdentityStatement = $@"EXECUTE SCore.UserCreate @EmailAddress = @EmailAddress, @FullName = @FullName, @FirstName = @FirstName, @LastName = @LastName, @MobileNo = @MobileNo, @IdentityID = @IdentityID OUT";

                            using (var command2 = connection.CreateCommand())
                            {
                                command2.CommandText = createIdentityStatement;
                                command2.Parameters.Add(new SqlParameter("@EmailAddress", userRecord.UserPrincipalName));
                                command2.Parameters.Add(new SqlParameter("@FullName", userRecord.DisplayName));
                                command2.Parameters.Add(new SqlParameter("@FirstName", userRecord.GivenName));
                                command2.Parameters.Add(new SqlParameter("@LastName", userRecord.Surname));
                                command2.Parameters.Add(new SqlParameter("@MobileNo", userRecord.MobilePhone));

                                SqlParameter identityId = new SqlParameter("@IdentityId", 0)
                                {
                                    Direction = System.Data.ParameterDirection.Output
                                };

                                command2.Parameters.Add(identityId);

                                await command2.ExecuteNonQueryAsync();

                                _userId = int.Parse(identityId.Value.ToString() ?? "0");
                            }
                        }
                    } 
                    else
                    {
                        _userId = int.Parse(result.ToString() ?? "0");
                    }                    
                }               
            }

            return _userId;
        }

        public async Task<Concursus.API.Core.User> GetUserInfo(UserInfoGetRequest request)
        {
            Concursus.API.Core.User? user = new();

            // Validation to make sure we don't end up with an object reference exception later. 
            if (string.IsNullOrEmpty(request.Username)
                && string.IsNullOrEmpty(request.Guid))
            {
                throw new Exception("No Username or Guid provided");
            }
            else
            {
                logger.LogTrace("Getting user info for " + (request.Username ?? "") + " " + (request.Guid ?? ""));
            }

            using (var connection = CreateConnection())
            {
                string statement;

                await OpenConnectionAsync(connection);

                if (useLegacyUserTables)
                {
                    statement = "SELECT u.UserId, m.Email, u.FirstName, u.Surname, u.Mobile " +
                            "FROM dbo.Users u " +
                            "JOIN dbo.Aspnet_Membership m on (m.UserId = u.MembershipId) ";

                    if (!string.IsNullOrEmpty(request.Username))
                    {
                        // catch if outlook is still presenting shoreengineering.co.uk
                        request.Username = request.Username.ToLower().Replace("shoreengineering.co.uk", "wemakeshore.co.uk");

                        statement += "WHERE (u.LoweredEmail = @UserEmail)";
                    }
                    else
                    {
                        statement += "WHERE (u.UserGuid = @UserGuid)";
                    }
                }
                else
                {
                    statement = "SELECT i.ID as UserId, i.EmailAddress as Email, N'' as FirstName, N'' as Surname, N'' as Mobile " +
                            "FROM SCore.Identities i " +
                            "JOIN dbo.Aspnet_Membership m on (m.UserId = u.MembershipId) " +
                            "WHERE (LOWER(i.EmailAddress = @UserEmail)";
                }

                using (var command = CreateCommand(statement, connection))
                {
                    if (!string.IsNullOrEmpty(request.Username))
                    {
                        command.Parameters.Add(new SqlParameter("UserEmail", request.Username.ToLower()));
                    }
                    else
                    {
                        command.Parameters.Add(new SqlParameter("UserGuid", request.Guid));
                    }

                    object? scalarResult = await command.ExecuteScalarAsync();

                    if (scalarResult != null){
                        _userId = int.Parse(scalarResult.ToString() ?? "0");
                    }                    

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            user = new()
                            {
                                Email = reader.GetString(reader.GetOrdinal("Email")),
                                UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                                FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
                                LastName = reader.GetString(reader.GetOrdinal("LastName")),
                                MobileNo = reader.GetString(reader.GetOrdinal("MobileNo")),
                                OnHoliday = false,
                            };
                        }
                    }

                    if (user.Email == "")
                    {
                        statement = "EXECUTE SCore.UserCreate" +
                            "@EmailAddress = @EmailAddress, @FullName = @FullName, @FirstName = @FirstName, @Surname = @Surname " +
                            "@MobileNo = @MobileNo, @IdentityID = @IdentityID OUT";

                        int identityId;

                        using (var command2 = CreateCommand(statement, connection))
                        {
                            string loweredUsername = (request.Username ?? "").ToLower();
                            command2.Parameters.Add(new SqlParameter("EmailAddress", loweredUsername));
                            command2.Parameters.Add(new SqlParameter("FullName", loweredUsername));
                            command2.Parameters.Add(new SqlParameter("FirstName", ""));
                            command2.Parameters.Add(new SqlParameter("LastName", ""));
                            command2.Parameters.Add(new SqlParameter("MobileNo", ""));

                            SqlParameter identityParam = new()
                            {
                                ParameterName = "IdentityID",
                                Direction = System.Data.ParameterDirection.Output
                            };

                            command2.Parameters.Add(identityParam);

                            await command2.ExecuteNonQueryAsync();

                            identityId = int.Parse(identityParam.Value.ToString() ?? "0");
                        }

                    }
                }

                if (user.Email == ""){
                    throw new Exception("Failed to obtain user.");
                }

                return user;
            }
        }

        #endregion

        #region Preferences

        public async Task<UserPreferences> GetUserPreferences(int userId)
        {
            UserPreferences rsl;

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                using (var transaction = BeginTransaction(connection, System.Data.IsolationLevel.ReadCommitted))
                {
                    rsl = await GetUserPreferences(userId, connection, transaction);
                }
            }

            return rsl;
        }

        public async Task<UserPreferences> GetUserPreferences(int userId, SqlConnection connection, SqlTransaction transaction)
        {
            UserPreferences rsl = new();
            string statement;

            statement = "SELECT up.ID, up.RowVersion, up.AutoFileMinutes, up.AutoFile, up.PromptOnSend, " +
                "up.MoveToFiledItems, up.SentMailboxesToCheck, up.IsEmergencyContact, up.DefaultFilingFolderId " +
                "FROM SCore.UserPreferences up" +
                "WHERE (up.ID = @userId)";

            using (var command = CreateCommand(statement, connection, transaction))
            {
                command.Parameters.Add(new SqlParameter("userId", userId));

                using (var reader = await command.ExecuteReaderAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        rsl = new()
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            RowVersion = reader.GetString(reader.GetOrdinal("RowVersion")),
                            AutoFileMinutes = reader.GetInt32(reader.GetOrdinal("AutoFileMinutes")),
                            AutoFile = reader.GetBoolean(reader.GetOrdinal("AutoFile")),
                            PromptOnSend = reader.GetBoolean(reader.GetOrdinal("PromptOnSend")),
                            MoveToFiledItems = reader.GetBoolean(reader.GetOrdinal("MoveToFiledItems")),
                            SentMailboxesToCheck = reader.GetString(reader.GetOrdinal("SendMailBocesToCheck")),
                            IsEmergencyContact = reader.GetBoolean(reader.GetOrdinal("IsEmergencyContact")),
                            DefaultFilingFolderId = reader.GetInt32(reader.GetOrdinal("DefaultFilingFolderId")),
                        };
                    }
                }
            }

            return rsl;
        }

        public async Task<UserPreferencesUpdateResponse> UserPreferencesUpdate(UserPreferencesUpdateRequest request)
        {
            //TODO: Add Row Version Check 

            //TODO: Add Validation

            UserPreferencesUpdateResponse rsl = new();

            try
            {
                //ValidationAndControl.UserPreferences vc = new(_user);
                //vc.ProcessObjectForService(request.UserPreferences, _serviceBase);

                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    using (var transaction = BeginTransaction(connection))
                    {
                        string statement = "UPDATE SCore.UserPreferences SET " +
                        "AutoFile = @AutoFile, " +
                        "AutoFileMinutes = @AutoFileMinutes, " +
                        "MoveToFiledItems = @MovedToFiledItems, " +
                        "PromptOnSend = @PromptOnSend, " +
                        "SharedMailboxesToCheck = @SharedMailboxesToCheck, " +
                        "DefaultFilingFolderId = @DefaultFilingFolderId " +
                        "WHERE (ID = @UserId)";

                        using (var command = CreateCommand(statement, connection, transaction))
                        {
                            command.Parameters.Add(new SqlParameter("AutoFile", request.UserPreferences.AutoFile));
                            command.Parameters.Add(new SqlParameter("AutoFileMinutes", request.UserPreferences.AutoFileMinutes));
                            command.Parameters.Add(new SqlParameter("MoveToFiledItems", request.UserPreferences.MoveToFiledItems));
                            command.Parameters.Add(new SqlParameter("PromptOnSend", request.UserPreferences.PromptOnSend));
                            command.Parameters.Add(new SqlParameter("SharedMailboxesToCheck", request.UserPreferences.SentMailboxesToCheck));
                            command.Parameters.Add(new SqlParameter("DefaultFilingFolderId", request.UserPreferences.DefaultFilingFolderId));
                            command.Parameters.Add(new SqlParameter("UserId", request.UserPreferences.Id));

                            await command.ExecuteNonQueryAsync();
                        }

                        statement = "SELECT up.ID, up.RowVersion, up.AutoFileMinutes, up.AutoFile, up.PromptOnSend, " +
                            "up.MoveToFiledItems, up.SentMailboxesToCheck, up.IsEmergencyContact, up.DefaultFilingFolderId " +
                            "FROM SCore.UserPreferences up" +
                            "WHERE (up.ID = @UserId)";

                        using (var command = CreateCommand(statement, connection))
                        {
                            command.Parameters.Add(new SqlParameter("UserId", request.UserPreferences.Id));

                            using (var reader = command.ExecuteReader())
                            {
                                while (reader.Read())
                                {
                                    rsl.UserPreferences = new()
                                    {
                                        Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                        RowVersion = reader.GetString(reader.GetOrdinal("RowVersion")),
                                        AutoFileMinutes = reader.GetInt32(reader.GetOrdinal("AutoFileMinutes")),
                                        AutoFile = reader.GetBoolean(reader.GetOrdinal("AutoFile")),
                                        PromptOnSend = reader.GetBoolean(reader.GetOrdinal("PromptOnSend")),
                                        MoveToFiledItems = reader.GetBoolean(reader.GetOrdinal("MoveToFiledItems")),
                                        SentMailboxesToCheck = reader.GetString(reader.GetOrdinal("SendMailBocesToCheck")),
                                        IsEmergencyContact = reader.GetBoolean(reader.GetOrdinal("IsEmergencyContact")),
                                        DefaultFilingFolderId = reader.GetInt32(reader.GetOrdinal("DefaultFilingFolderId")),
                                    };
                                }
                            }
                        }

                        await transaction.CommitAsync();
                    }
                }
            }
            catch (RpcException ex)
            {
                logger.LogException(ex);

                throw;
            }
            catch (Exception ex)
            {
                logger.LogException(ex);

                throw new RpcException(new Grpc.Core.Status(StatusCode.Unknown, "SQL Exception: " + ex.Message), ex.Message);
            }

            return rsl;
        }

        #endregion

        #region Scheduler

        public async Task<ScheduleItemsGetResponse> ScheduleItemsGet(ScheduleItemsGetRequest request)
        {
            ScheduleItemsGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                
                string securityStatement = "SELECT * FROM SCore.tvf_ScheduleItems (@UserId)";

                using (var command = CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", _userId));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            API.Core.ScheduleItem scheduleItem = new API.Core.ScheduleItem();
                            scheduleItem.Id = reader.GetInt64(reader.GetOrdinal("Id"));
                                scheduleItem.Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString();
                                scheduleItem.Title = reader.GetString(reader.GetOrdinal("Title"));
                                scheduleItem.Description = reader.GetString(reader.GetOrdinal("Description"));
                                scheduleItem.IsAllDay = reader.GetBoolean(reader.GetOrdinal("IsAllDay"));
                                scheduleItem.RecurrenceRule = reader.GetString(reader.GetOrdinal("RecurrenceRule"));
                                scheduleItem.RecurrenceId = reader.GetInt32(reader.GetOrdinal("RecurrenceId"));
                                scheduleItem.RecurrenceExceptions = reader.GetString(reader.GetOrdinal("RecurrenceExceptions"));
                                scheduleItem.StartTimezone = reader.GetString(reader.GetOrdinal("StartTimezone"));
                                scheduleItem.EndTimezone = reader.GetString(reader.GetOrdinal("EndTimezone"));
                                scheduleItem.UserId = reader.GetInt32(reader.GetOrdinal("UserId"));
                                scheduleItem.StatusId = reader.GetInt32(reader.GetOrdinal("StatusId"));
                                scheduleItem.TypeId = reader.GetInt32(reader.GetOrdinal("TypeId"));
                                scheduleItem.JobActivityId = reader.GetInt64(reader.GetOrdinal("JobActivityId"));
                            
                            scheduleItem.Start = Timestamp.FromDateTime(reader.GetDateTime(reader.GetOrdinal("Start")).ToUniversalTime());
                            scheduleItem.End = Timestamp.FromDateTime(reader.GetDateTime(reader.GetOrdinal("End")).ToUniversalTime());

                            rsl.ScheduleItems.Add(scheduleItem);

                        }
                    }
                }
            }

            return rsl;
        }

        public async Task<ScheduleItemTypesGetResponse> ScheduleItemTypesGet(ScheduleItemTypesGetRequest request)
        {
            ScheduleItemTypesGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);


                string securityStatement = "SELECT * FROM SCore.ScheduleItemTypes";

                using (var command = CreateCommand(securityStatement, connection))
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            API.Core.ScheduleItemType scheduleItemType = new API.Core.ScheduleItemType()
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Color = reader.GetString(reader.GetOrdinal("Colour"))
                            };

                            rsl.ScheduleItemTypes.Add(scheduleItemType);

                        }
                    }
                }
            }

            return rsl;
        }

        public async Task<ScheduleItemStatusGetResponse> ScheduleItemStatusGet(ScheduleItemStatusGetRequest request)
        {
            ScheduleItemStatusGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.ScheduleItemStatus";

                using (var command = CreateCommand(securityStatement, connection))
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            API.Core.ScheduleItemStatus scheduleItemStatus = new API.Core.ScheduleItemStatus()
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Color = reader.GetString(reader.GetOrdinal("Colour"))
                            };

                            rsl.ScheduleItemStatus.Add(scheduleItemStatus);

                        }
                    }
                }
            }

            return rsl;
        }

        #endregion

        public async Task<OrganisationalUnitsGetResponse> OrganisationalUnitsGet(OrganisationalUnitsGetRequest request)
        {
            OrganisationalUnitsGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.tvf_OrganisationalUnitsGet(@UserId);";

                using (var command = CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", _userId));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            API.Core.OrganisationalUnit organisationalUnit = new API.Core.OrganisationalUnit()
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                ParentOrganisationalUnitGuid = reader.GetGuid(reader.GetOrdinal("ParentOrganisationalUnitGuid")).ToString()
                            };

                            rsl.OrganisationalUnits.Add(organisationalUnit);

                        }
                    }
                }
            }

            return rsl;
        }

        public async Task<UsersGetResponse> UsersGet(UsersGetRequest request)
        {
            UsersGetResponse rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.UsersGet;";

                using (var command = CreateCommand(securityStatement, connection))
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            API.Core.User user = new API.Core.User()
                            {
                                UserId = reader.GetInt32(reader.GetOrdinal("ID")),
                                Email = reader.GetString(reader.GetOrdinal("EmailAddress")),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                FullName = reader.GetString(reader.GetOrdinal("FullName"))
                            };

                            rsl.Users.Add(user);

                        }
                    }
                }
            }

            return rsl;
        }
    }
}