using Concursus.EF.Types;
using CymBuild_Outlook_Common.Dto;
using CymBuild_Outlook_Common.Helpers;
using CymBuild_Outlook_Common.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_Outlook_API.Data
{
    public class AppDbContext : DbContext
    {
        private readonly LoggingHelper _loggingHelper;

        public AppDbContext(DbContextOptions<AppDbContext> options, LoggingHelper loggingHelper) : base(options)
        {
            _loggingHelper = loggingHelper;
        }

        public DbSet<Message> Messages { get; set; }
        public DbSet<EntityType> EntityTypes { get; set; }
        public DbSet<OutlookCalendarEvent> OutlookCalendarEvents { get; set; }
        public DbSet<OutlookEmailMailbox> OutlookEmailMailboxes { get; set; }
        public DbSet<OutlookEmail> OutlookEmails { get; set; }
        public DbSet<OutlookEmailConversation> OutlookEmailConversations { get; set; }
        public DbSet<OutlookEmailFromAddress> OutlookEmailFromAddresses { get; set; }
        public DbSet<Preference> Preferences { get; set; }
        public DbSet<RowStatus> RowStatuses { get; set; }
        public DbSet<TargetObject> TargetObjects { get; set; }
        public DbSet<OutlookEmailSysNotFiled> OutlookEmailsSysNotFiled { get; set; }
        public DbSet<OutlookEmailSysReadyToFile> OutlookEmailsSysReadyToFile { get; set; }
        public DbSet<SharePointDetail> SharePointDetails { get; set; }
        public DbSet<FilingRecordSearchResult> FilingRecordSearchResults { get; set; }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            // Optional: Configuring database options if not using DI
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Define RecordSearchResult as a keyless entity
            modelBuilder.Entity<RecordSearchResult>().HasNoKey();
            // Configure SharePointDetail as a keyless entity
            modelBuilder.Entity<SharePointDetail>().HasNoKey();

            // Assuming 'tvf_RecordSearch' is the name of your TVF in the database
            modelBuilder.Entity<RecordSearchResult>().ToFunction("tvf_RecordSearch");

            // Configure relationships
            modelBuilder.Entity<TargetObject>()
                .HasOne(t => t.EntityType)
                .WithMany()
                .HasForeignKey(t => t.EntityTypeId);

            // Ensure other navigation properties are configured properly
            modelBuilder.Entity<TargetObject>().Ignore(t => t.CalendarEvents);
            modelBuilder.Entity<TargetObject>().Ignore(t => t.Emails);

            // Define FilingRecordSearchResult as a keyless entity
            modelBuilder.Entity<FilingRecordSearchResult>().HasNoKey();
        }

        public async Task<List<SharePointDetail>> GetSharePointDetailsForObject(DataObject dataObject)
        {
            var results = Set<SharePointDetail>().FromSqlRaw(@"
                SELECT * FROM [SCore].[tvf_GetSharePointDetailsForObject] (@EntityTypeGuid, @ObjectID, @ParentObjectID)",
                new SqlParameter("@EntityTypeGuid", dataObject.EntityTypeGuid),
                new SqlParameter("@ObjectID", dataObject.DatabaseId),
                new SqlParameter("@ParentObjectID", -1));

            return await results.ToListAsync();
        }

        public async Task<TargetObjectDto> GetTargetObjectAsync(Guid id)
        {
            var sql = @"
                SELECT TOP(1)
                    t.ID, t.EntityTypeId, t.FilingLocation,
                    t.Guid, t.Name, t.Number, t.RowStatus AS RowStatusID,
                    t.RowVersion, e.Guid AS EntityTypeGuid,
                    e.Name AS EntityTypeName, e.RowStatus AS EntityTypeRowStatus,
                    e.RowVersion AS EntityTypeRowVersion
                FROM [SOffice].[TargetObjects] AS [t]
                INNER JOIN [SOffice].[EntityTypes] AS [e] ON [t].[EntityTypeId] = [e].[ID]
                WHERE [t].[Guid] = @id";

            var parameter = new SqlParameter("@id", id);
            TargetObjectDto targetObject = null;

            try
            {
                await Database.OpenConnectionAsync();

                using (var command = Database.GetDbConnection().CreateCommand())
                {
                    command.CommandText = sql;
                    command.CommandType = System.Data.CommandType.Text;
                    command.Parameters.Add(parameter);

                    using (var result = await command.ExecuteReaderAsync())
                    {
                        if (await result.ReadAsync())
                        {
                            targetObject = new TargetObjectDto
                            {
                                ID = result.GetInt64(result.GetOrdinal("ID")),
                                EntityTypeID = result.GetInt32(result.GetOrdinal("EntityTypeId")),
                                FilingLocation = result.GetString(result.GetOrdinal("FilingLocation")),
                                Guid = result.GetGuid(result.GetOrdinal("Guid")),
                                Name = result.GetString(result.GetOrdinal("Name")),
                                Number = result.GetString(result.GetOrdinal("Number")),
                                RowStatus = result.GetByte(result.GetOrdinal("RowStatusID")),
                                RowVersion = (byte[])result["RowVersion"],
                                EntityTypeGuid = result.GetGuid(result.GetOrdinal("EntityTypeGuid")),
                                EntityTypeName = result.GetString(result.GetOrdinal("EntityTypeName")),
                                EntityTypeRowStatus = result.GetByte(result.GetOrdinal("EntityTypeRowStatus")),
                                EntityTypeRowVersion = (byte[])result["EntityTypeRowVersion"]
                            };
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"Error fetching target object with ID {id}", ex, "GetTargetObjectAsync()");
                throw;
            }
            finally
            {
                await Database.CloseConnectionAsync();
            }

            return targetObject;
        }

        // Method to call the TVF
        public IQueryable<RecordSearchResult> SearchRecords(int userId, string searchString, Guid entityTypeGuid, string toAddressesCSV, string fromAddress, string subject)
        {
            var formattedSearchString = StringHelpers.PrepareSQLFullTextSearchString(searchString);

            if (!string.IsNullOrEmpty(formattedSearchString))
            {
                formattedSearchString = "%" + formattedSearchString + "%";
            }

            _loggingHelper.LogInfo($"SearchRecords called with parameters: userId={userId}, searchString={formattedSearchString}, entityTypeGuid={entityTypeGuid}, toAddressesCSV={toAddressesCSV}, fromAddress={fromAddress}, subject={subject}", "SearchRecords()");

            try
            {
                var results = Set<RecordSearchResult>().FromSqlRaw(
                    "SELECT * FROM SOffice.tvf_RecordSearch(@UserId, @SearchString, @EntityTypeGuid, @ToAddressesCSV, @FromAddress, @Subject)",
                    new SqlParameter("@UserId", userId),
                    new SqlParameter("@SearchString", formattedSearchString ?? (object)DBNull.Value),
                    new SqlParameter("@EntityTypeGuid", entityTypeGuid),
                    new SqlParameter("@ToAddressesCSV", toAddressesCSV ?? (object)DBNull.Value),
                    new SqlParameter("@FromAddress", fromAddress ?? (object)DBNull.Value),
                    new SqlParameter("@Subject", subject ?? (object)DBNull.Value));

                _loggingHelper.LogInfo($"Query executed successfully, result count: {results.Count()}", "SearchRecords()");

                foreach (var result in results)
                {
                    _loggingHelper.LogInfo($"Result: ID={result.ID}, Name={result.Name}, EntityTypeName={result.EntityTypeName}, ConversationMatch={result.ConversationMatch}, ToMatch={result.ToMatch}, FromMatch={result.FromMatch}, RecordMatch={result.RecordMatch}", "SearchRecords()");
                }

                return results;
            }
            catch (SqlException ex)
            {
                _loggingHelper.LogError($"SQL error executing SearchRecords: ", ex, "SearchRecords()");
                throw;
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"Error executing SearchRecords: ", ex, "SearchRecords()");
                throw;
            }
        }

        public async Task<int> UpsertOutlookCalendarEvent(CalendarEventUpsertDto upsertDto)
        {
            // Prepare the parameters
            var parameters = new[]
            {
                new SqlParameter("@TargetObjectGuid", upsertDto.TargetObjectGuid),
                new SqlParameter("@Mailbox", upsertDto.Mailbox),
                new SqlParameter("@ExchangeImmutableID", upsertDto.ExchangeImmutableID ?? (object)DBNull.Value),
                new SqlParameter("@Title", upsertDto.Title),
                new SqlParameter("@StartDateTime", upsertDto.StartDateTime),
                new SqlParameter("@EndDateTime", upsertDto.EndDateTime),
                new SqlParameter("@IsAllDay", upsertDto.IsAllDay),
                new SqlParameter("@Recurrence", upsertDto.Recurrence ?? (object)DBNull.Value),
                new SqlParameter("@LastUpdateSource", upsertDto.LastUpdateSource ?? (object)DBNull.Value),
                new SqlParameter("@Guid", upsertDto.Guid)
            };

            // Call the stored procedure
            var result = await Database.ExecuteSqlRawAsync("EXEC SOffice.OutlookCalendarEventsUpsert @TargetObjectGuid, @Mailbox, @ExchangeImmutableID, @Title, @StartDateTime, @EndDateTime, @IsAllDay, @Recurrence, @LastUpdateSource, @Guid", parameters);

            return result;
        }

        public async Task<int> UpdateEmailSysProcessing(EmailSysProcessingUpdateDto updateDto)
        {
            // Prepare the parameters
            var parameters = new[]
            {
                new SqlParameter("@DeliveryReceiptReceived", updateDto.DeliveryReceiptReceived),
                new SqlParameter("@ReadReceiptReceived", updateDto.ReadReceiptReceived),
                new SqlParameter("@FiledDateTime", updateDto.FiledDateTime),
                new SqlParameter("@Guid", updateDto.Guid)
            };

            // Execute the stored procedure
            var result = await Database.ExecuteSqlRawAsync(
                "EXEC SOffice.OutlookEmail_SysProcessingUpdate @DeliveryReceiptReceived, @ReadReceiptReceived, @FiledDateTime, @Guid",
                parameters);

            return result;
        }

        public async Task<int> UpsertOutlookEmail(EmailUpsertDto upsertDto)
        {
            var parameters = new[]
            {
                new SqlParameter("@TargetObjectGuid", upsertDto.TargetObjectGuid),
                new SqlParameter("@Mailbox", upsertDto.Mailbox),
                new SqlParameter("@MessageID", upsertDto.MessageID),
                new SqlParameter("@ConversationID", upsertDto.ConversationID),
                new SqlParameter("@FromAddress", upsertDto.FromAddress),
                new SqlParameter("@ToAddresses", upsertDto.ToAddresses),
                new SqlParameter("@Subject", upsertDto.Subject),
                new SqlParameter("@SentDateTime", upsertDto.SentDateTime),
                new SqlParameter("@DeliveryReceiptRequested", upsertDto.DeliveryReceiptRequested),
                new SqlParameter("@DeliveryReceiptReceived", upsertDto.DeliveryReceiptReceived),
                new SqlParameter("@ReadReceiptRequested", upsertDto.ReadReceiptRequested),
                new SqlParameter("@ReadReceiptReceived", upsertDto.ReadReceiptReceived),
                new SqlParameter("@DoNotFile", upsertDto.DoNotFile),
                new SqlParameter("@IsReadyToFile", upsertDto.IsReadyToFile),
                new SqlParameter("@FiledDateTime", upsertDto.FiledDateTime as object ?? DBNull.Value),
                new SqlParameter("@FilingLocationUrl", upsertDto.FilingLocationUrl ?? (object)DBNull.Value),
                new SqlParameter("@Description", upsertDto.Description),
                new SqlParameter("@Guid", upsertDto.Guid)
            };

            return await Database.ExecuteSqlRawAsync(
                "EXEC SOffice.OutlookEmailsUpsert @TargetObjectGuid, @Mailbox, @MessageID, @ConversationID, @FromAddress, @ToAddresses, @Subject, @SentDateTime, @DeliveryReceiptRequested, @DeliveryReceiptReceived, @ReadReceiptRequested, @ReadReceiptReceived, @DoNotFile, @IsReadyToFile, @FiledDateTime, @FilingLocationUrl, @Description, @Guid",
                parameters);
        }

        public async Task<int> UpsertTargetObject(TargetObjectUpsertDto upsertDto)
        {
            var parameters = new[]
            {
                new SqlParameter("@EntityTypeGuid", upsertDto.EntityTypeGuid),
                new SqlParameter("@RecordGuid", upsertDto.RecordGuid),
                new SqlParameter("@Number", upsertDto.Number ?? (object)DBNull.Value),
                new SqlParameter("@Name", upsertDto.Name ?? (object)DBNull.Value),
                new SqlParameter("@FilingLocation", upsertDto.FilingLocation ?? (object)DBNull.Value)
            };

            return await Database.ExecuteSqlRawAsync(
                "EXEC SOffice.TargetObjectUpsert @EntityTypeGuid, @RecordGuid, @Number, @Name, @FilingLocation",
                parameters);
        }

        public async Task<List<FilingRecordSearchResult>> SearchFiledRecordsAsync(string messageId)
        {
            return await FilingRecordSearchResults
                .FromSqlInterpolated($"SELECT * FROM SOffice.tvf_FiledRecordSearch({messageId})")
                .ToListAsync();
        }
    }
}