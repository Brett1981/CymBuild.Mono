using Concursus.API.Core;
using Concursus.PWA.Helpers;

namespace Concursus.PWA.Services
{
    public class GenericEntityService
    {
        private readonly IndexedDbHelper _indexedDbHelper;

        public GenericEntityService(IndexedDbHelper indexedDbHelper)
        {
            _indexedDbHelper = indexedDbHelper;
        }

        // Initialize the IndexedDB
        public async Task InitializeDatabaseAsync(string dbName)
        {
            await _indexedDbHelper.InitializeDatabaseAsync(dbName);
        }

        // Fetch from gRPC and store in IndexedDB
        public async Task FetchAndStoreEntityAsync<TGrpcEntity, TEntity>(Func<Task<TGrpcEntity>> fetchFromGrpc, string storeName)
            where TEntity : class
        {
            var grpcEntity = await fetchFromGrpc();
            var entity = MapGrpcEntityToEntity<TGrpcEntity, TEntity>(grpcEntity);
            await _indexedDbHelper.AddItemAsync(storeName, entity);
        }

        // Load from IndexedDB
        public async Task<TEntity> LoadEntityAsync<TEntity>(string storeName, string guid) where TEntity : class
        {
            return await _indexedDbHelper.GetItemAsync<TEntity>(storeName, guid);
        }

        // Update entity in IndexedDB
        public async Task UpdateEntityAsync<TEntity>(string storeName, string guid, Action<TEntity> updateAction) where TEntity : class
        {
            var entity = await _indexedDbHelper.GetItemAsync<TEntity>(storeName, guid);
            if (entity != null)
            {
                updateAction(entity);
                await _indexedDbHelper.UpdateItemAsync(storeName, entity);
            }
        }

        // Delete entity from IndexedDB
        public async Task DeleteEntityAsync(string storeName, string guid)
        {
            await _indexedDbHelper.DeleteItemAsync(storeName, guid);
        }

        // Mapping functions for all gRPC message types to their respective C# objects

        private TEntity MapGrpcEntityToEntity<TGrpcEntity, TEntity>(TGrpcEntity grpcEntity)
        {
            if (typeof(TGrpcEntity) == typeof(EntityProperty) && typeof(TEntity) == typeof(EntityProperty))
            {
                return (TEntity)(object)MapEntityProperty(grpcEntity as EntityProperty);
            }
            else if (typeof(TGrpcEntity) == typeof(EntityDataType) && typeof(TEntity) == typeof(EntityDataType))
            {
                return (TEntity)(object)MapEntityDataType(grpcEntity as EntityDataType);
            }
            else if (typeof(TGrpcEntity) == typeof(EntityHoBT) && typeof(TEntity) == typeof(EntityHoBT))
            {
                return (TEntity)(object)MapEntityHoBT(grpcEntity as EntityHoBT);
            }
            else if (typeof(TGrpcEntity) == typeof(EntityPropertyGroup) && typeof(TEntity) == typeof(EntityPropertyGroup))
            {
                return (TEntity)(object)MapEntityPropertyGroup(grpcEntity as EntityPropertyGroup);
            }
            else if (typeof(TGrpcEntity) == typeof(EntityQuery) && typeof(TEntity) == typeof(EntityQuery))
            {
                return (TEntity)(object)MapEntityQuery(grpcEntity as EntityQuery);
            }
            else if (typeof(TGrpcEntity) == typeof(EntityType) && typeof(TEntity) == typeof(EntityType))
            {
                return (TEntity)(object)MapEntityType(grpcEntity as EntityType);
            }
            else if (typeof(TGrpcEntity) == typeof(GridDefinition) && typeof(TEntity) == typeof(GridDefinition))
            {
                return (TEntity)(object)MapGridDefinition(grpcEntity as GridDefinition);
            }
            else if (typeof(TGrpcEntity) == typeof(GridViewDefinition) && typeof(TEntity) == typeof(GridViewDefinition))
            {
                return (TEntity)(object)MapGridViewDefinition(grpcEntity as GridViewDefinition);
            }
            else if (typeof(TGrpcEntity) == typeof(Group) && typeof(TEntity) == typeof(Group))
            {
                return (TEntity)(object)MapGroup(grpcEntity as Group);
            }
            else if (typeof(TGrpcEntity) == typeof(Language) && typeof(TEntity) == typeof(Language))
            {
                return (TEntity)(object)MapLanguage(grpcEntity as Language);
            }
            else if (typeof(TGrpcEntity) == typeof(LanguageLabel) && typeof(TEntity) == typeof(LanguageLabel))
            {
                return (TEntity)(object)MapLanguageLabel(grpcEntity as LanguageLabel);
            }
            else if (typeof(TGrpcEntity) == typeof(User) && typeof(TEntity) == typeof(User))
            {
                return (TEntity)(object)MapUser(grpcEntity as User);
            }
            else if (typeof(TGrpcEntity) == typeof(UserPreferences) && typeof(TEntity) == typeof(UserPreferences))
            {
                return (TEntity)(object)MapUserPreferences(grpcEntity as UserPreferences);
            }
            else
            {
                throw new InvalidOperationException("Unsupported entity type");
            }
        }

        private EntityProperty MapEntityProperty(EntityProperty grpcEntity)
        {
            var entity = new EntityProperty
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name,
                LanguageLabelGuid = grpcEntity.LanguageLabelGuid,
                EntityDataTypeGuid = grpcEntity.EntityDataTypeGuid,
                IsReadOnly = grpcEntity.IsReadOnly,
                IsImmutable = grpcEntity.IsImmutable,
                IsHidden = grpcEntity.IsHidden,
                IsCompulsory = grpcEntity.IsCompulsory,
                MaxLength = grpcEntity.MaxLength,
                Precision = grpcEntity.Precision,
                Scale = grpcEntity.Scale,
                DoNotTrackChanges = grpcEntity.DoNotTrackChanges,
                EntityPropertyGroupGuid = grpcEntity.EntityPropertyGroupGuid,
                SortOrder = grpcEntity.SortOrder,
                GroupSortOrder = grpcEntity.GroupSortOrder,
                EntityTypeGuid = grpcEntity.EntityTypeGuid,
                EntityDataTypeName = grpcEntity.EntityDataTypeName,
                Label = grpcEntity.Label,
                IsObjectLabel = grpcEntity.IsObjectLabel,
                DropDownListDefinitionGuid = grpcEntity.DropDownListDefinitionGuid,
                IsParentRelationship = grpcEntity.IsParentRelationship,
                EntityHoBTGuid = grpcEntity.EntityHoBTGuid,
                IsDetailWindowed = grpcEntity.IsDetailWindowed,
                DetailPageUri = grpcEntity.DetailPageUri,
                ForeignEntityTypeGuid = grpcEntity.ForeignEntityTypeGuid,
                IsUpperCase = grpcEntity.IsUpperCase,
                InformationPageUri = grpcEntity.InformationPageUri,
                SqlDefaultValueStatement = grpcEntity.SqlDefaultValueStatement,
                FixedDefaultValue = grpcEntity.FixedDefaultValue,
                IsIncludedInformation = grpcEntity.IsIncludedInformation,
                ShowOnMobile = grpcEntity.ShowOnMobile,
                IsAlwaysVisibleInGroup = grpcEntity.IsAlwaysVisibleInGroup,
                IsAlwaysVisibleInGroupMobile = grpcEntity.IsAlwaysVisibleInGroupMobile,
            };

            // Add ObjectSecurity
            foreach (var security in grpcEntity.ObjectSecurity)
            {
                entity.ObjectSecurity.Add(MapObjectSecurity(security));
            }

            // Add DependantProperties
            foreach (var dependantProperty in grpcEntity.DependantProperties)
            {
                entity.DependantProperties.Add(MapEntityPropertyDependant(dependantProperty));
            }

            // Add PropertyActions
            foreach (var action in grpcEntity.PropertyActions)
            {
                entity.PropertyActions.Add(MapEntityPropertyActions(action));
            }

            return entity;
        }

        private EntityDataType MapEntityDataType(EntityDataType grpcEntity)
        {
            return new EntityDataType
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name
            };
        }

        private EntityHoBT MapEntityHoBT(EntityHoBT grpcEntity)
        {
            var entity = new EntityHoBT
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                SchemaName = grpcEntity.SchemaName,
                ObjectName = grpcEntity.ObjectName,
                EntityTypeGuid = grpcEntity.EntityTypeGuid,
                ObjectType = grpcEntity.ObjectType,
                IsMainHoBT = grpcEntity.IsMainHoBT,
                IsReadOnlyOffline = grpcEntity.IsReadOnlyOffline
            };

            // Add ObjectSecurity
            foreach (var security in grpcEntity.ObjectSecurity)
            {
                entity.ObjectSecurity.Add(MapObjectSecurity(security));
            }

            return entity;
        }

        private EntityPropertyGroup MapEntityPropertyGroup(EntityPropertyGroup grpcEntity)
        {
            return new EntityPropertyGroup
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name,
                IsHidden = grpcEntity.IsHidden,
                SortOrder = grpcEntity.SortOrder,
                LanguageLabelGuid = grpcEntity.LanguageLabelGuid,
                Label = grpcEntity.Label,
                Layout = grpcEntity.Layout,
                IsCollapsable = grpcEntity.IsCollapsable,
                IsDefaultCollapsed = grpcEntity.IsDefaultCollapsed,
                IsDefaultCollapsedMobile = grpcEntity.IsDefaultCollapsedMobile,
                ShowOnMobile = grpcEntity.ShowOnMobile,
            };
        }

        private EntityQuery MapEntityQuery(EntityQuery grpcEntity)
        {
            var entity = new EntityQuery
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name,
                Statement = grpcEntity.Statement,
                EntityTypeGuid = grpcEntity.EntityTypeGuid,
                IsDefaultCreate = grpcEntity.IsDefaultCreate,
                IsDefaultRead = grpcEntity.IsDefaultRead,
                IsDefaultUpdate = grpcEntity.IsDefaultUpdate,
                IsDefaultDelete = grpcEntity.IsDefaultDelete,
                IsScalarExecute = grpcEntity.IsScalarExecute,
                EntityHoBTGuid = grpcEntity.EntityHoBTGuid,
                IsDefaultValidation = grpcEntity.IsDefaultValidation,
                IsDefaultDataPills = grpcEntity.IsDefaultDataPills,
                IsDefaultProgressData = grpcEntity.IsDefaultProgressData
            };

            // Add EntityQueryParameters
            foreach (var parameter in grpcEntity.EntityQueryParameters)
            {
                entity.EntityQueryParameters.Add(MapEntityQueryParameter(parameter));
            }

            return entity;
        }

        private EntityQueryParameter MapEntityQueryParameter(EntityQueryParameter grpcEntity)
        {
            return new EntityQueryParameter
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name,
                EntityDataType = MapEntityDataType(grpcEntity.EntityDataType),
                MappedEntityPropertyGuid = grpcEntity.MappedEntityPropertyGuid
            };
        }

        private EntityType MapEntityType(EntityType grpcEntity)
        {
            var entity = new EntityType
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name,
                IsReadOnlyOffline = grpcEntity.IsReadOnlyOffline,
                IsRequiredSystemData = grpcEntity.IsRequiredSystemData,
                HasDocuments = grpcEntity.HasDocuments,
                LanguageLabelGuid = grpcEntity.LanguageLabelGuid,
                DoNotTrackChanges = grpcEntity.DoNotTrackChanges,
                Label = grpcEntity.Label,
                IconCss = grpcEntity.IconCss
            };

            // Add EntityProperties
            foreach (var property in grpcEntity.EntityProperties)
            {
                entity.EntityProperties.Add(MapEntityProperty(property));
            }

            // Add ObjectSecurity
            foreach (var security in grpcEntity.ObjectSecurity)
            {
                entity.ObjectSecurity.Add(MapObjectSecurity(security));
            }

            // Add EntityQueries
            foreach (var query in grpcEntity.EntityQueries)
            {
                entity.EntityQueries.Add(MapEntityQuery(query));
            }

            // Add EntityPropertyGroups
            foreach (var group in grpcEntity.EntityPropertyGroups)
            {
                entity.EntityPropertyGroups.Add(MapEntityPropertyGroup(group));
            }

            // Add EntityHoBTs
            foreach (var hobt in grpcEntity.EntityHoBTs)
            {
                entity.EntityHoBTs.Add(MapEntityHoBT(hobt));
            }

            return entity;
        }

        private GridDefinition MapGridDefinition(GridDefinition grpcEntity)
        {
            var entity = new GridDefinition
            {
                Id = grpcEntity.Id,
                RowVersion = grpcEntity.RowVersion,
                Code = grpcEntity.Code,
                Name = grpcEntity.Name,
                PageUri = grpcEntity.PageUri,
                TabName = grpcEntity.TabName,
                ShowAsTiles = grpcEntity.ShowAsTiles,
                Guid = grpcEntity.Guid
            };

            // Add Views
            foreach (var view in grpcEntity.Views)
            {
                entity.Views.Add(MapGridViewDefinition(view));
            }

            return entity;
        }

        private GridViewDefinition MapGridViewDefinition(GridViewDefinition grpcEntity)
        {
            var entity = new GridViewDefinition
            {
                Id = grpcEntity.Id,
                RowVersion = grpcEntity.RowVersion,
                Code = grpcEntity.Code,
                Name = grpcEntity.Name,
                DetailPageUri = grpcEntity.DetailPageUri,
                DefaultSortColumnName = grpcEntity.DefaultSortColumnName,
                GridDefinitionId = grpcEntity.GridDefinitionId,
                SqlQuery = grpcEntity.SqlQuery,
                SecurableCode = grpcEntity.SecurableCode,
                DisplayOrder = grpcEntity.DisplayOrder,
                DisplayGroupName = grpcEntity.DisplayGroupName,
                MetricSqlQuery = grpcEntity.MetricSqlQuery,
                ShowMetric = grpcEntity.ShowMetric,
                Guid = grpcEntity.Guid,
                GridDefinitionGuid = grpcEntity.GridDefinitionGuid,
                IsDetailWindowed = grpcEntity.IsDetailWindowed,
                EntityTypeGuid = grpcEntity.EntityTypeGuid,
                MetricTypeGuid = grpcEntity.MetricTypeGuid,
                MetricMin = grpcEntity.MetricMin,
                MetricMax = grpcEntity.MetricMax,
                MetricMinorUnit = grpcEntity.MetricMinorUnit,
                MetricMajorUnit = grpcEntity.MetricMajorUnit,
                MetricStartAngle = grpcEntity.MetricStartAngle,
                MetricEndAngle = grpcEntity.MetricEndAngle,
                MetricReversed = grpcEntity.MetricReversed,
                MetricRange1Min = grpcEntity.MetricRange1Min,
                MetricRange1Max = grpcEntity.MetricRange1Max,
                MetricRange1ColourHex = grpcEntity.MetricRange1ColourHex,
                MetricRange2Min = grpcEntity.MetricRange2Min,
                MetricRange2Max = grpcEntity.MetricRange2Max,
                MetricRange2ColourHex = grpcEntity.MetricRange2ColourHex,
                DrawIconCss = grpcEntity.DrawIconCss,
                IsDefaultSortDescending = grpcEntity.IsDefaultSortDescending,
                AllowNew = grpcEntity.AllowNew,
                GridViewTypeId = grpcEntity.GridViewTypeId
            };

            // Add Columns
            foreach (var column in grpcEntity.Columns)
            {
                entity.Columns.Add(MapGridViewColumnDefinition(column));
            }

            // Add GridViewActions
            foreach (var action in grpcEntity.GridViewActions)
            {
                entity.GridViewActions.Add(MapGridViewAction(action));
            }

            return entity;
        }

        private Group MapGroup(Group grpcEntity)
        {
            return new Group
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name
            };
        }

        private Language MapLanguage(Language grpcEntity)
        {
            return new Language
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name,
                Locale = grpcEntity.Locale
            };
        }

        private LanguageLabel MapLanguageLabel(LanguageLabel grpcEntity)
        {
            var entity = new LanguageLabel
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Name = grpcEntity.Name
            };

            // Add LanguageLabelTranslations
            foreach (var translation in grpcEntity.LanguageLabelTranslations)
            {
                entity.LanguageLabelTranslations.Add(MapLanguageLabelTranslation(translation));
            }

            return entity;
        }

        private User MapUser(User grpcEntity)
        {
            var entity = new User
            {
                UserId = grpcEntity.UserId,
                Email = grpcEntity.Email,
                FirstName = grpcEntity.FirstName,
                LastName = grpcEntity.LastName,
                OnHoliday = grpcEntity.OnHoliday,
                MobileNo = grpcEntity.MobileNo,
                Guid = grpcEntity.Guid,
                FullName = grpcEntity.FullName
            };

            // Add UserGroups
            foreach (var group in grpcEntity.UserGroups)
            {
                entity.UserGroups.Add(MapUserGroup(group));
            }

            return entity;
        }

        private UserPreferences MapUserPreferences(UserPreferences grpcEntity)
        {
            return new UserPreferences
            {
                Id = grpcEntity.Id,
                Guid = grpcEntity.Guid,
                SystemLanguageID = grpcEntity.SystemLanguageID,
                WidgetLayout = grpcEntity.WidgetLayout,
            };
        }

        private ObjectSecurity MapObjectSecurity(ObjectSecurity grpcObjectSecurity)
        {
            return new ObjectSecurity
            {
                RowStatus = grpcObjectSecurity.RowStatus,
                RowVersion = grpcObjectSecurity.RowVersion,
                Guid = grpcObjectSecurity.Guid,
                DataObjectGuid = grpcObjectSecurity.DataObjectGuid,
                UserGuid = grpcObjectSecurity.UserGuid,
                GroupGuid = grpcObjectSecurity.GroupGuid,
                GroupName = grpcObjectSecurity.GroupName,
                CanRead = grpcObjectSecurity.CanRead,
                CanWrite = grpcObjectSecurity.CanWrite,
                UserIdentity = grpcObjectSecurity.UserIdentity,
                GroupIdentity = grpcObjectSecurity.GroupIdentity,
                //DefaultGroupIdentity = grpcObjectSecurity.DefaultGroupIdentity,
                Id = grpcObjectSecurity.Id
            };
        }

        private EntityPropertyDependant MapEntityPropertyDependant(EntityPropertyDependant grpcEntity)
        {
            return new EntityPropertyDependant
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                ParentEntityPropertyGuid = grpcEntity.ParentEntityPropertyGuid,
                DependantEntityPropertyGuid = grpcEntity.DependantEntityPropertyGuid
            };
        }

        private EntityPropertyActions MapEntityPropertyActions(EntityPropertyActions grpcEntity)
        {
            return new EntityPropertyActions
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Statement = grpcEntity.Statement
            };
        }

        private GridViewColumnDefinition MapGridViewColumnDefinition(GridViewColumnDefinition grpcEntity)
        {
            return new GridViewColumnDefinition
            {
                Id = grpcEntity.Id,
                RowVersion = grpcEntity.RowVersion,
                Name = grpcEntity.Name,
                ColumnOrder = grpcEntity.ColumnOrder,
                Title = grpcEntity.Title,
                IsPrimaryKey = grpcEntity.IsPrimaryKey,
                IsHidden = grpcEntity.IsHidden,
                IsFiltered = grpcEntity.IsFiltered,
                IsCombo = grpcEntity.IsCombo,
                GridViewDefinitionId = grpcEntity.GridViewDefinitionId,
                Guid = grpcEntity.Guid,
                GridViewDefinitionGuid = grpcEntity.GridViewDefinitionGuid,
                IsLongitude = grpcEntity.IsLongitude,
                IsLatitude = grpcEntity.IsLatitude,
                Width = grpcEntity.Width,
                DisplayFormat = grpcEntity.DisplayFormat
            };
        }

        private GridViewActions MapGridViewAction(GridViewActions grpcEntity)
        {
            return new GridViewActions
            {
                Title = grpcEntity.Title,
                Statement = grpcEntity.Statement,
                Guid = grpcEntity.Guid
            };
        }

        private LanguageLabelTranslation MapLanguageLabelTranslation(LanguageLabelTranslation grpcEntity)
        {
            return new LanguageLabelTranslation
            {
                RowStatus = grpcEntity.RowStatus,
                RowVersion = grpcEntity.RowVersion,
                Guid = grpcEntity.Guid,
                Text = grpcEntity.Text,
                LanguageLabelGuid = grpcEntity.LanguageLabelGuid,
                LanguageGuid = grpcEntity.LanguageGuid
            };
        }

        private UserGroup MapUserGroup(UserGroup grpcEntity)
        {
            return new UserGroup
            {
                Id = grpcEntity.Id,
                RowVersion = grpcEntity.RowVersion,
                GroupId = grpcEntity.GroupId,
                UserId = grpcEntity.UserId,
                GroupName = grpcEntity.GroupName,
                Guid = grpcEntity.Guid,
                GroupGuid = grpcEntity.GroupGuid,
                UserGuid = grpcEntity.UserGuid
            };
        }
    }
}