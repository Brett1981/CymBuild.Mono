/* wwwroot/js/auth.js
   Office SSO auth helper for Outlook Add-ins

   IMPORTANT:
   - Office SSO may return an *add-in/API* audience token (aud=api://... or your clientId),
     even when forMSGraphAccess=true, depending on host support and configuration.
   - Only treat a token as a Graph token if aud indicates Microsoft Graph.

   Exposes globals used by Blazor:
     - window.authenticateUser()     : primes SSO cache
     - window.getGraphTokenPopup(req): legacy name - returns GRAPH token if possible, else null
     - window.getGraphAccessToken(o) : returns GRAPH token if possible, else null
     - window.getSsoToken(opts)      : ALWAYS returns SSO token (often for your API/add-in)
     - window.clearCachedTokens()
*/

(function () {
    "use strict";

    // -----------------------------
    // Simple in-memory token cache
    // -----------------------------
    let _cachedSsoToken = null;
    let _cachedSsoExpUtcMs = 0;

    let _cachedGraphToken = null;
    let _cachedGraphExpUtcMs = 0;

    function _nowUtcMs() { return Date.now(); }

    function _isValid(token, expUtcMs, minValiditySeconds = 60) {
        if (!token) return false;
        if (!expUtcMs) return false;
        return (expUtcMs - _nowUtcMs()) > (minValiditySeconds * 1000);
    }

    function _tryGetJwtPayload(token) {
        try {
            const parts = (token || "").split(".");
            if (parts.length < 2) return null;

            let payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
            while (payload.length % 4) payload += "=";

            return JSON.parse(atob(payload));
        } catch {
            return null;
        }
    }

    function _tryGetJwtExpUtcMs(token) {
        const payload = _tryGetJwtPayload(token);
        return (payload && typeof payload.exp === "number") ? payload.exp * 1000 : 0;
    }

    function _getAud(token) {
        const payload = _tryGetJwtPayload(token);
        return payload?.aud || "";
    }

    function _getScp(token) {
        const payload = _tryGetJwtPayload(token);
        return payload?.scp || "";
    }

    // Graph audience can show as GUID (Graph resource) or a URL-ish string in some tenants
    function _isGraphAudience(token) {
        const aud = String(_getAud(token) || "").toLowerCase();
        return aud === "00000003-0000-0000-c000-000000000000" || aud.includes("graph.microsoft.com");
    }

    function clearCachedTokens() {
        _cachedSsoToken = null;
        _cachedSsoExpUtcMs = 0;
        _cachedGraphToken = null;
        _cachedGraphExpUtcMs = 0;
    }

    // -----------------------------
    // Office SSO access token
    // -----------------------------
    async function _getAccessTokenFromOffice(options) {
        const opts = options || {};

        const runtimeAuth = (window.OfficeRuntime && window.OfficeRuntime.auth && window.OfficeRuntime.auth.getAccessToken)
            ? window.OfficeRuntime.auth
            : null;

        const officeAuth = (window.Office && window.Office.auth && window.Office.auth.getAccessToken)
            ? window.Office.auth
            : null;

        if (!runtimeAuth && !officeAuth) {
            throw new Error("Office SSO API not available (OfficeRuntime.auth/Office.auth). Ensure Office.js is loaded and you are running inside Outlook.");
        }

        const accessTokenOptions = {
            allowSignInPrompt: opts.allowSignInPrompt !== false,
            allowConsentPrompt: opts.allowConsentPrompt !== false,
            forMSGraphAccess: opts.forMSGraphAccess === true, // explicit
            forceRefresh: !!opts.forceRefresh
        };

        console.log("[auth.js] getAccessToken request:", accessTokenOptions);

        if (runtimeAuth) {
            return await runtimeAuth.getAccessToken(accessTokenOptions);
        }

        // Older callback form
        return await new Promise((resolve, reject) => {
            try {
                officeAuth.getAccessToken(accessTokenOptions, (result) => {
                    if (result && result.status === "succeeded") resolve(result.value);
                    else reject((result && result.error) ? result.error : (result || new Error("Unknown Office.auth.getAccessToken error")));
                });
            } catch (e) {
                reject(e);
            }
        });
    }

    // Always returns the SSO token (often for your API/add-in)
    async function getSsoToken(options) {
        const opts = options || {};

        if (!opts.forceRefresh && _isValid(_cachedSsoToken, _cachedSsoExpUtcMs, 60)) {
            console.log("[auth.js] Using cached SSO token.");
            return _cachedSsoToken;
        }

        const token = await _getAccessTokenFromOffice({
            forMSGraphAccess: false, // IMPORTANT: this requests the default add-in/API token
            allowSignInPrompt: opts.allowSignInPrompt !== false,
            allowConsentPrompt: opts.allowConsentPrompt !== false,
            forceRefresh: !!opts.forceRefresh
        });

        if (!token) throw new Error("Office SSO returned an empty token.");

        _cachedSsoToken = token;
        _cachedSsoExpUtcMs = _tryGetJwtExpUtcMs(token);

        console.log("[auth.js] SSO token acquired.",
            "aud=", _getAud(token),
            "scp=", _getScp(token),
            "exp=", _cachedSsoExpUtcMs ? new Date(_cachedSsoExpUtcMs).toISOString() : "unknown");

        return token;
    }

    // Returns a Graph token ONLY if the host actually issues one; otherwise returns null
    async function getGraphAccessToken(options) {
        const opts = options || {};

        if (!opts.forceRefresh && _isValid(_cachedGraphToken, _cachedGraphExpUtcMs, 60)) {
            console.log("[auth.js] Using cached GRAPH token.");
            return _cachedGraphToken;
        }

        const token = await _getAccessTokenFromOffice({
            forMSGraphAccess: true,
            allowSignInPrompt: opts.allowSignInPrompt !== false,
            allowConsentPrompt: opts.allowConsentPrompt !== false,
            forceRefresh: !!opts.forceRefresh
        });

        if (!token) return null;

        const aud = _getAud(token);
        const scp = _getScp(token);

        console.log("[auth.js] Candidate GRAPH token acquired.",
            "aud=", aud,
            "scp=", scp);

        if (!_isGraphAudience(token)) {
            // This is the key: host gave us a non-Graph token even though we asked.
            console.warn("[auth.js] Host did NOT return a Graph-audience token. You must call Graph via your API using OBO.",
                "aud=", aud,
                "scp=", scp);
            return null;
        }

        _cachedGraphToken = token;
        _cachedGraphExpUtcMs = _tryGetJwtExpUtcMs(token);

        console.log("[auth.js] GRAPH token accepted.",
            "exp=", _cachedGraphExpUtcMs ? new Date(_cachedGraphExpUtcMs).toISOString() : "unknown");

        return token;
    }

    // -----------------------------
    // Public API expected by Blazor
    // -----------------------------
    async function authenticateUser() {
        console.log("[auth.js] authenticateUser() starting (SSO)...");
        const token = await getSsoToken({ forceRefresh: false });
        console.log("[auth.js] authenticateUser() complete. token:", token ? "[present]" : "[missing]");
    }

    // Legacy name: your .NET calls getGraphTokenPopup(...)
    // We now return a real Graph token if possible, else null (so C# can fall back to API/OBO).
    async function getTokenPopup(request) {
        const req = request || {};
        const forceRefresh = !!req.forceRefresh;

        console.log("[auth.js] getGraphTokenPopup() called. Requested scopes (ignored by Office SSO):", req.scopes);

        return await getGraphAccessToken({
            forceRefresh,
            allowSignInPrompt: true,
            allowConsentPrompt: true
        });
    }

    async function getUserId() {
        const graphToken = await getGraphAccessToken({ forceRefresh: false });

        if (!graphToken) {
            throw new Error("No Graph token available in this host. Retrieve /me via your API (OBO) instead.");
        }

        const headers = new Headers();
        headers.append("Authorization", `Bearer ${graphToken}`);
        headers.append("Prefer", 'IdType="ImmutableId"');

        const response = await fetch("https://graph.microsoft.com/v1.0/me", { method: "GET", headers });

        if (!response.ok) {
            const text = await response.text().catch(() => "");
            throw new Error(`Graph /me failed: ${response.status} ${response.statusText}. ${text}`);
        }

        const data = await response.json();
        return data.id;
    }

    window.addEventListener("error", function (event) {
        console.error("[auth.js] JavaScript Error:", event.message, event.error);
    });

    // Export globals expected by your Blazor code
    window.authenticateUser = authenticateUser;

    // Keep your existing name (Index.razor.cs calls getGraphTokenPopup)
    window.getGraphTokenPopup = getTokenPopup;

    window.getUserId = getUserId;

    // New explicit helpers
    window.getSsoToken = getSsoToken;                 // always returns SSO token (API/add-in)
    window.getGraphAccessToken = getGraphAccessToken; // returns Graph token or null

    window.clearCachedTokens = clearCachedTokens;
})();
