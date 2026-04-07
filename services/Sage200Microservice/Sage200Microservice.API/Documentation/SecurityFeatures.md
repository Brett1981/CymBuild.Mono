# Security Features Documentation

## CORS Policy Implementation

The Cross-Origin Resource Sharing (CORS) policy has been implemented to control which domains can access the API resources. This is a critical security feature that helps prevent unauthorized cross-origin requests.

### Configuration

The CORS policy is configured in `appsettings.json` under the `Cors` section:

```json
"Cors": {
  "Enabled": true,
  "AllowedOrigins": [
    "https://admin.sage200app.com",
    "https://client.sage200app.com"
  ],
  "AllowedMethods": [
    "GET",
    "POST",
    "PUT",
    "DELETE",
    "OPTIONS",
    "PATCH"
  ],
  "AllowedHeaders": [
    "Content-Type",
    "Authorization",
    "X-Api-Key",
    "X-Requested-With",
    "Accept"
  ],
  "ExposedHeaders": [
    "X-Pagination",
    "X-Rate-Limit-Remaining",
    "X-Rate-Limit-Reset"
  ],
  "AllowCredentials": false,
  "PreflightMaxAgeInSeconds": 600
}
```

### Implementation Details

The CORS policy is implemented using the following components:

1. **CorsOptions Class**: Defines the configuration options for CORS policy.
2. **CorsConfig Class**: Contains extension methods to register and configure CORS services.
3. **Program.cs Integration**: CORS services are added in the service configuration and middleware pipeline.

### Usage

To modify the CORS policy:

1. Update the `Cors` section in `appsettings.json` for each environment.
2. For development environments, you may want to allow more origins.
3. For production, strictly limit the allowed origins to trusted domains only.

## Security Headers Implementation

Security headers are HTTP response headers that provide an additional layer of security by helping to mitigate certain types of attacks, such as Cross-Site Scripting (XSS), clickjacking, and other code injection attacks.

### Configuration

Security headers are configured in `appsettings.json` under the `SecurityHeaders` section:

```json
"SecurityHeaders": {
  "Enabled": true,
  "ContentSecurityPolicy": "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'",
  "XFrameOptions": "DENY",
  "XContentTypeOptions": "nosniff",
  "ReferrerPolicy": "strict-origin-when-cross-origin",
  "XXssProtection": "1; mode=block",
  "StrictTransportSecurity": "max-age=31536000; includeSubDomains",
  "HstsPreload": true,
  "PermissionsPolicy": "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()",
  "RemoveServerHeader": true,
  "ExcludedEndpoints": [
    "/health",
    "/metrics",
    "/swagger"
  ]
}
```

### Implemented Security Headers

1. **Content-Security-Policy (CSP)**: Controls which resources the browser is allowed to load.
2. **X-Frame-Options**: Prevents clickjacking attacks by controlling whether the page can be displayed in an iframe.
3. **X-Content-Type-Options**: Prevents MIME type sniffing.
4. **Referrer-Policy**: Controls how much referrer information is included with requests.
5. **X-XSS-Protection**: Enables browser's built-in XSS filtering.
6. **Strict-Transport-Security (HSTS)**: Forces browsers to use HTTPS for the specified domain.
7. **Permissions-Policy**: Controls which browser features and APIs can be used.

### Implementation Details

The security headers are implemented using the following components:

1. **SecurityHeadersOptions Class**: Defines the configuration options for security headers.
2. **SecurityHeadersMiddleware Class**: Middleware that adds security headers to HTTP responses.
3. **SecurityHeadersConfig Class**: Contains extension methods to register and configure security headers services.
4. **Program.cs Integration**: Security headers services are added in the service configuration and middleware pipeline.

### Usage

To modify the security headers:

1. Update the `SecurityHeaders` section in `appsettings.json` for each environment.
2. For development environments, you may want to relax some policies.
3. For production, use strict security headers to provide maximum protection.
4. Use the `ExcludedEndpoints` property to exclude certain paths from having security headers applied.

## Best Practices

### CORS Best Practices

1. **Limit Origins**: Only allow trusted domains in the `AllowedOrigins` list.
2. **Avoid Wildcards**: Avoid using `*` in production environments.
3. **Limit Methods**: Only allow necessary HTTP methods.
4. **Limit Headers**: Only expose headers that are needed by client applications.
5. **Credentials**: Only enable `AllowCredentials` if cross-origin authentication is required.

### Security Headers Best Practices

1. **Content Security Policy**: Regularly review and update the CSP to ensure it's as restrictive as possible.
2. **HSTS**: Use long max-age values in production (at least 1 year).
3. **X-Frame-Options**: Use `DENY` unless you specifically need to allow framing.
4. **Permissions Policy**: Restrict access to browser features that your application doesn't need.
5. **Regular Testing**: Use tools like [securityheaders.com](https://securityheaders.com) to test your security headers.

## Environment-Specific Configurations

Different environments may require different security configurations:

### Development

- More relaxed CORS policy
- Less restrictive CSP
- HSTS might be disabled

### Production

- Strict CORS policy with specific origins
- Comprehensive CSP
- HSTS enabled with long max-age
- All security headers enabled

## Monitoring and Compliance

- Regularly audit the security headers and CORS policy.
- Monitor for any security-related issues or violations.
- Keep up to date with security best practices and update configurations accordingly.