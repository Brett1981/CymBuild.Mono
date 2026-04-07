using Concursus.Common.Shared.Extensions;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.EF
{
    internal static class Notifications
    {
        #region Public Methods

        public static async Task NotificationAdd(
    Core entityFramework,
    string notificationTypeCode,
    int forUserId,
    bool isToast,
    bool isEmail,
    string toEmailAddress = "",
    string subject = "",
    string body = "",
    string attachedFile = "",
    long linkedRecordId = -1)
        {
            if (string.IsNullOrEmpty(notificationTypeCode))
                throw new ArgumentException("Notification type code cannot be null or empty.", nameof(notificationTypeCode));

            using var connection = entityFramework.CreateConnection();
            await entityFramework.OpenConnectionAsync(connection);

            // Use a transaction to ensure atomicity of the operation
            await connection.ExecuteInTransaction(async transaction =>
            {
                int notificationTypeId;

                // Retrieve the NotificationTypeId
                string selectStatement = "SELECT nt.Id FROM SCore.NotificationTypes WHERE nt.Code = @Code";

                using (var selectCommand = connection.CreateCommandWithParametersTransaction(selectStatement, CommandType.Text, transaction,
                    new SqlParameter("Code", notificationTypeCode)))
                {
                    notificationTypeId = (await selectCommand.ExecuteScalarAsync()) as int? ?? -1;
                    if (notificationTypeId == -1)
                        throw new InvalidOperationException($"Notification type '{notificationTypeCode}' not found.");
                }

                // Insert the notification
                string insertStatement = @"
            INSERT INTO SCore.Notifications
            (NotificationTypeId, ForUserId, IsToast, IsEmail, ToEmailAddress, Subject, Body, AttachedFile, LinkedRecordId)
            VALUES
            (@NotificationTypeId, @ForUserId, @IsToast, @IsEmail, @ToEmailAddress, @Subject, @Body, @AttachedFile, @LinkedRecordId)";

                using (var insertCommand = connection.CreateCommandWithParametersTransaction(insertStatement, CommandType.Text, transaction,
                    new SqlParameter("NotificationTypeId", notificationTypeId),
                    new SqlParameter("ForUserId", forUserId),
                    new SqlParameter("IsToast", isToast),
                    new SqlParameter("IsEmail", isEmail),
                    new SqlParameter("ToEmailAddress", toEmailAddress),
                    new SqlParameter("Subject", subject),
                    new SqlParameter("Body", body),
                    new SqlParameter("AttachedFile", attachedFile),
                    new SqlParameter("LinkedRecordId", linkedRecordId)))
                {
                    await insertCommand.ExecuteNonQueryAsync();
                }
            });
        }

        #endregion Public Methods
    }
}