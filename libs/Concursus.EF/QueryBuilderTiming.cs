using Microsoft.Data.SqlClient;
using System.Diagnostics;

namespace Concursus.EF
{
    public static class QueryBuilderTiming
    {
        private static string FormatParams(SqlCommand cmd)
        {
            if (cmd.Parameters.Count == 0) return "";
            var sb = new System.Text.StringBuilder();
            foreach (SqlParameter p in cmd.Parameters)
            {
                var val = p.Value is null ? "NULL" : p.Value.ToString();
                sb.AppendLine($"@{p.ParameterName} = '{val}'");
            }
            return sb.ToString();
        }

        public static async Task<SqlDataReader> ExecuteReaderTimedAsync(SqlCommand cmd, string tag = "")
        {
            var sw = Stopwatch.StartNew();
            try { return await cmd.ExecuteReaderAsync(); }
            finally
            {
                sw.Stop();
                Console.WriteLine($"[SQL {tag}] {sw.ElapsedMilliseconds} ms\n{cmd.CommandText}\n{FormatParams(cmd)}");
            }
        }

        public static async Task<object?> ExecuteScalarTimedAsync(SqlCommand cmd, string tag = "")
        {
            var sw = Stopwatch.StartNew();
            try { return await cmd.ExecuteScalarAsync(); }
            finally
            {
                sw.Stop();
                Console.WriteLine($"[SQL (scalar) {tag}] {sw.ElapsedMilliseconds} ms\n{cmd.CommandText}\n{FormatParams(cmd)}");
            }
        }

        public static async Task<int> ExecuteNonQueryTimedAsync(SqlCommand cmd, string tag = "")
        {
            var sw = Stopwatch.StartNew();
            try { return await cmd.ExecuteNonQueryAsync(); }
            finally
            {
                sw.Stop();
                Console.WriteLine($"[SQL (nonquery) {tag}] {sw.ElapsedMilliseconds} ms\n{cmd.CommandText}\n{FormatParams(cmd)}");
            }
        }
    }
}