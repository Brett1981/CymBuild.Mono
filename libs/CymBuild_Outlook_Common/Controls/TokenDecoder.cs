using System.Text;
using System.Text.Json;

namespace CymBuild_Outlook_Common.Controls
{
    public class TokenDecoder
    {
        private readonly LoggingHelper _loggingHelper;

        public TokenDecoder(LoggingHelper loggingHelper)
        {
            _loggingHelper = loggingHelper;
        }

        public string DecodeUserIdFromToken(string token)
        {
            _loggingHelper.LogInfo("Decoding User ID from token.", "DecodeUserIdFromToken()");

            var payload = GetJwtPayload(token);

            if (payload.TryGetValue("oid", out var userIdClaim))
            {
                var userId = userIdClaim?.ToString();
                _loggingHelper.LogInfo($"Decoded User ID: {userId}", "DecodeUserIdFromToken()");
                return userId;
            }

            _loggingHelper.LogError("Checking Token and UserID", new Exception("Invalid token or user ID not found."), "DecodeUserIdFromToken()");
            return "Invalid token or user ID not found.";
        }

        public string DecodeMailBoxFromToken(string token)
        {
            _loggingHelper.LogInfo("Decoding MailBox from token.", "DecodeMailBoxFromToken()");

            var payload = GetJwtPayload(token);

            if (payload.TryGetValue("upn", out var mailBoxClaim))
            {
                var mailBox = mailBoxClaim?.ToString();
                _loggingHelper.LogInfo($"Decoded MailBox: {mailBox}", "DecodeMailBoxFromToken()");
                return mailBox;
            }

            _loggingHelper.LogError("Checking token and User MailBox", new Exception("Invalid token or user MailBox not found."), "DecodeMailBoxFromToken()");
            return "Invalid token or user MailBox not found.";
        }

        public string DecodeScopesFromToken(string token)
        {
            _loggingHelper.LogInfo("Decoding Scopes from token.", "DecodeScopesFromToken()");

            var payload = GetJwtPayload(token);

            if (payload.TryGetValue("scp", out var scopesClaim))
            {
                var scopes = scopesClaim?.ToString();
                _loggingHelper.LogInfo($"Decoded Scopes: {scopes}", "DecodeScopesFromToken()");
                return scopes;
            }

            _loggingHelper.LogError("Checking token and Scopes", new Exception("Invalid token or scopes not found."), "DecodeScopesFromToken()");
            return "Invalid token or scopes not found.";
        }

        public string DecodeUserNameFromToken(string token)
        {
            _loggingHelper.LogInfo("Decoding UserName from token.", "DecodeUserNameFromToken()");

            var payload = GetJwtPayload(token);

            if (payload.TryGetValue("name", out var nameClaim))
            {
                var userName = nameClaim?.ToString();
                _loggingHelper.LogInfo($"Decoded UserName: {userName}", "DecodeUserNameFromToken()");
                return userName;
            }

            _loggingHelper.LogError("Checking token and UserName", new Exception("Invalid token or user name not found."), "DecodeUserNameFromToken()");
            return "Invalid token or user name not found.";
        }

        private Dictionary<string, object> GetJwtPayload(string token)
        {
            try
            {
                var parts = token.Split('.');
                if (parts.Length != 3)
                {
                    _loggingHelper.LogError("Check Format of JWT Token", new Exception("Invalid JWT token format."), "GetJwtPayload()");
                    throw new InvalidOperationException("Invalid JWT token.");
                }

                var payload = parts[1];
                var jsonBytes = ParseBase64WithoutPadding(payload);

                _loggingHelper.LogInfo($"Decoded JWT payload: {Encoding.UTF8.GetString(jsonBytes)}", "GetJwtPayload()");

                return JsonSerializer.Deserialize<Dictionary<string, object>>(jsonBytes);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"Exception while decoding JWT payload: ", ex, "GetjwtPayload()");
                return new Dictionary<string, object>();
            }
        }

        private static byte[] ParseBase64WithoutPadding(string base64)
        {
            switch (base64.Length % 4)
            {
                case 2: base64 += "=="; break;
                case 3: base64 += "="; break;
            }
            return Convert.FromBase64String(base64);
        }
    }
}