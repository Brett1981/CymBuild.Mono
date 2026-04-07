using Microsoft.Data.SqlClient;

namespace Concursus.API.EntityFramework
{
    internal static class Notifications
    {
        public static async void NotificationAdd(
            Core entityFramework,
            string notificationTypeCode,
            int forUserId,
            bool isToast,
            bool isEmail,
            string toEmailAddress = "",
            string subject = "",
            string body = "",
            string attachedFile = "",
            long linkedRecordId = -1
            )
        {
            /*
             * no try catch block, if this fails we want the process calling it to fail. 
            */
            int notificationTypeId = -1;

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                using (var transaction = entityFramework.BeginTransaction(connection))
                {
                    string statement = "SELECT nt.Id from SCore.NotificationTypes WHERE (nt.Code = @Code)";

                    using (var command = entityFramework.CreateCommand(statement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("Code", notificationTypeCode));

                        notificationTypeId = int.Parse(command.ExecuteScalarAsync().ToString() ?? "0");
                    }

                    statement = "INSERT INTO SCore.Notifications " +
                "(NotificationTypeId, ForUserId, IsToast, IsEmail, ToEmailAddress, Subject, Body, AttachedFile, LinkedRecordId)" +
                "VALUES (@NotificationTypeId, @ForUserId, @IsToast, @IsEmail, @ToEmailAddress, @Subject, @Body, @AttachedFile, @LinkedRecordId)";

                    using (var command = entityFramework.CreateCommand(statement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("NotificationTypeId", notificationTypeId));
                        command.Parameters.Add(new SqlParameter("ForUserId", forUserId));
                        command.Parameters.Add(new SqlParameter("IsToast", isToast));
                        command.Parameters.Add(new SqlParameter("IsEmail", isEmail));
                        command.Parameters.Add(new SqlParameter("ToEmailAddress", toEmailAddress));
                        command.Parameters.Add(new SqlParameter("Subject", subject));
                        command.Parameters.Add(new SqlParameter("Body", body));
                        command.Parameters.Add(new SqlParameter("AttachedFile", attachedFile));
                        command.Parameters.Add(new SqlParameter("LinkedRecordId", linkedRecordId));

                        command.ExecuteNonQuery();
                    }

                    await transaction.CommitAsync();
                }
            }
        }
    }
}
