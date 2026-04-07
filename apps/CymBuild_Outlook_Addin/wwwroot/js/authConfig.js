// Config object to be passed to Msal on creation
//const msalConfig = {
//    auth: {
//        clientId: "e551c05f-19f7-435c-9842-c039ab8a4e0c",
//        authority: "https://login.microsoftonline.com/260244d9-d475-4990-9550-997fbd6ade67",
//        redirectUri: "https://bre.socotec.co.uk:9603/authentication/login-callback",
//        navigateToLoginRequestUrl: false,
//    },
//    cache: {
//        cacheLocation: "sessionStorage", // This configures where your cache will be stored
//        storeAuthStateInCookie: false, // Set this to "true" if you are having issues on IE11 or Edge
//        claimsBasedCachingEnabled: true // Enable claims-based caching
//    },
//    system: {
//        loggerOptions: {
//            loggerCallback: (level, message, containsPii) => {
//                if (containsPii) {
//                    return;
//                }
//                switch (level) {
//                    case msal.LogLevel.Error:
//                        console.error(message);
//                        return;
//                    case msal.LogLevel.Info:
//                        console.info(message);
//                        return;
//                    case msal.LogLevel.Verbose:
//                        console.debug(message);
//                        return;
//                    case msal.LogLevel.Warning:
//                        console.warn(message);
//                        return;
//                }
//            }
//        }
//    }
//};

// Add here scopes for id token to be used at MS Identity Platform endpoints.
const loginRequest = {
    scopes: ["User.Read"]
};

// Add here the endpoints for MS Graph API services you would like to use.
const graphConfig = {
    graphMeEndpoint: "https://graph.microsoft.com/v1.0/me",
    graphMailEndpoint: "https://graph.microsoft.com/v1.0/me/messages"
};

// Add here scopes for access token to be used at MS Graph API endpoints.
const tokenRequest = {
    scopes: ["api://e551c05f-19f7-435c-9842-c039ab8a4e0c/access_as_user", "Mail.Read"],
    forceRefresh: false // Set this to "true" to skip a cached token and go to the server to get a new token
};

const silentRequest = {
    scopes: ["openid", "profile", "User.Read", "Mail.Read", "User.ReadWrite.All", "Mail.ReadWrite", "Mail.ReadWrite.Shared"]
};