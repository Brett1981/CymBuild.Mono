using System.Security.Claims;

namespace CymBuild_Outlook_API.Services
{
    public interface IUserClaimsService
    {
        Task<IEnumerable<Claim>> GetClaimsForUserAsync(string email);
    }

    public class UserClaimsService : IUserClaimsService
    {
        private readonly CoreServices_API _coreServicesApi;

        public UserClaimsService(CoreServices_API coreServicesApi)
        {
            _coreServicesApi = coreServicesApi;
        }

        public async Task<IEnumerable<Claim>> GetClaimsForUserAsync(string email)
        {
            var user = await _coreServicesApi.GetUserInfo(email);

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, user.Email),
                new Claim(ClaimTypes.Email, user.Email),
                // Add more claims as needed
                new Claim(ClaimTypes.GivenName, user.FirstName),
                new Claim(ClaimTypes.Surname, user.LastName)
            };

            return claims;
        }
    }
}