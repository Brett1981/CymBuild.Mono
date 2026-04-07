# Monitoring and Alerting Documentation

## Error Monitoring Implementation

The error monitoring system has been implemented to detect, aggregate, and alert on critical errors in the application. This system helps identify issues early and ensures that the appropriate teams are notified when problems occur.

### Configuration

Error monitoring is configured in `appsettings.json` under the `ErrorMonitoring` section:

```json
"ErrorMonitoring": {
  "Enabled": true,
  "MonitoredSeverityLevels": [ "Error", "Critical", "Fatal" ],
  "AggregationWindowMinutes": 5,
  "MinimumAlertIntervalMinutes": 15,
  "IncludeStackTraces": true,
  "MaxErrorsPerAlert": 10,
  "AlertThresholds": {
    "ErrorCountThreshold": 5,
    "ErrorRateThreshold": 1.0,
    "ErrorPercentageThreshold": 5.0
  },
  "NotificationChannels": {
    "Email": {
      "Enabled": true,
      "SmtpServer": "smtp.example.com",
      "SmtpPort": 587,
      "SmtpUsername": "alerts@example.com",
      "SmtpPassword": "password",
      "UseSsl": true,
      "FromAddress": "alerts@example.com",
      "ToAddresses": [
        "admin@example.com",
        "operations@example.com"
      ],
      "SubjectTemplate": "[{Severity}] Sage200Microservice Alert: {ErrorCount} errors detected"
    },
    "Slack": {
      "Enabled": true,
      "WebhookUrl": "https://hooks.slack.com/services/your/webhook/url",
      "Channel": "#alerts",
      "Username": "Error Monitor",
      "IconEmoji": ":warning:"
    },
    "Webhook": {
      "Enabled": false,
      "Url": "https://example.com/webhook",
      "AuthHeaderName": "Authorization",
      "AuthHeaderValue": "Bearer your-token"
    }
  },
  "AlertRules": [
    {
      "Name": "Database Errors",
      "Description": "Critical errors related to database operations",
      "ErrorMessagePattern": "Database",
      "SeverityLevels": [ "Critical", "Fatal" ],
      "ErrorCountThreshold": 2,
      "PriorityLevel": 1,
      "NotificationChannels": [ "Email", "Slack" ]
    },
    {
      "Name": "API Authentication Errors",
      "Description": "Errors related to API authentication",
      "ErrorMessagePattern": "Authentication",
      "SeverityLevels": [ "Error", "Critical" ],
      "ErrorCountThreshold": 5,
      "PriorityLevel": 2,
      "NotificationChannels": [ "Email", "Slack" ]
    },
    {
      "Name": "Sage API Errors",
      "Description": "Errors related to Sage API integration",
      "ErrorMessagePattern": "Sage API",
      "SeverityLevels": [ "Error", "Critical", "Fatal" ],
      "ErrorCountThreshold": 3,
      "PriorityLevel": 2,
      "NotificationChannels": [ "Email", "Slack" ]
    }
  ]
}
```

### Implementation Details

The error monitoring system is implemented using the following components:

1. **ErrorMonitoringOptions Class**: Defines the configuration options for error monitoring.
2. **ErrorMonitoringService Class**: Background service that monitors errors and sends alerts.
3. **ErrorEvent Class**: Represents an error event with timestamp, severity, message, and stack trace.
4. **Program.cs Integration**: Error monitoring services are added in the service configuration.

### Alert Rules

Alert rules define when and how alerts are triggered. Each rule can have:

1. **Name and Description**: Identifies the rule and its purpose.
2. **ErrorMessagePattern**: Pattern to match in error messages.
3. **SeverityLevels**: List of severity levels to match.
4. **ErrorCountThreshold**: Minimum number of errors to trigger an alert.
5. **PriorityLevel**: Priority of the alert (1-5, where 1 is highest).
6. **NotificationChannels**: List of channels to use for notifications.

### Notification Channels

The system supports multiple notification channels:

1. **Email**: Sends alerts via SMTP.
2. **Slack**: Sends alerts to a Slack channel via webhook.
3. **Webhook**: Sends alerts to a custom webhook endpoint.

### Usage

To record errors for monitoring:

```csharp
// Inject the ErrorMonitoringService
private readonly ErrorMonitoringService _errorMonitor;

public YourService(ErrorMonitoringService errorMonitor)
{
    _errorMonitor = errorMonitor;
}

// Record an error
try
{
    // Your code here
}
catch (Exception ex)
{
    _errorMonitor.RecordError("Error", ex.Message, ex.StackTrace);
    throw;
}
```

## Health Check Dashboard Implementation

The health check dashboard provides a visual interface for monitoring the health of the application and its dependencies. It helps identify issues and provides real-time status information.

### Configuration

Health check dashboard is configured in `appsettings.json` under the `HealthCheckDashboard` section:

```json
"HealthCheckDashboard": {
  "Enabled": true,
  "EndpointPath": "/health-dashboard",
  "ApiEndpointPath": "/health",
  "IncludeDetails": true,
  "IncludeErrorMessages": true,
  "IncludeExceptions": false,
  "RefreshIntervalSeconds": 30,
  "AllowUnauthenticatedAccess": true,
  "AllowedRoles": [ "Administrator", "Operations" ]
}
```

### Implementation Details

The health check dashboard is implemented using the following components:

1. **HealthCheckDashboardOptions Class**: Defines the configuration options for the health check dashboard.
2. **HealthCheckDashboardExtensions Class**: Contains extension methods to register and configure health check dashboard services.
3. **Program.cs Integration**: Health check dashboard services are added in the service configuration and middleware pipeline.

### Health Checks

The following health checks are implemented:

1. **Database Health Check**: Monitors the database connection.
2. **Memory Health Check**: Monitors the process memory usage.
3. **Disk Storage Health Check**: Monitors available disk space.
4. **Sage API Health Check**: Monitors the Sage API connectivity.

### Dashboard Features

The health check dashboard provides the following features:

1. **Real-time Status**: Shows the current status of all health checks.
2. **Auto-refresh**: Automatically refreshes the dashboard at configurable intervals.
3. **Detailed Information**: Shows detailed information about each health check.
4. **Error Messages**: Shows error messages when health checks fail.
5. **Tags**: Groups health checks by tags for easier navigation.

### Access Control

Access to the health check dashboard can be restricted:

1. **AllowUnauthenticatedAccess**: If false, requires authentication.
2. **AllowedRoles**: List of roles that are allowed to access the dashboard.

### Endpoints

The health check dashboard provides two endpoints:

1. **Dashboard Endpoint**: HTML interface for viewing health status (default: `/health-dashboard`).
2. **API Endpoint**: JSON API for programmatic access to health status (default: `/health`).

## Integration with Existing Monitoring

The error monitoring and health check dashboard integrate with the existing monitoring infrastructure:

1. **OpenTelemetry**: Error events are tracked with OpenTelemetry for distributed tracing.
2. **Prometheus**: Health check metrics are exposed for Prometheus scraping.
3. **Grafana**: Dashboards can be created in Grafana to visualize health check metrics.
4. **Serilog**: Error events are logged with Serilog for centralized logging.

## Best Practices

### Error Monitoring Best Practices

1. **Severity Levels**: Use appropriate severity levels for different types of errors.
2. **Alert Thresholds**: Set appropriate thresholds to avoid alert fatigue.
3. **Error Aggregation**: Group similar errors to reduce noise.
4. **Alert Rules**: Create specific rules for different types of errors.
5. **Notification Channels**: Use multiple channels for critical alerts.

### Health Check Best Practices

1. **Check Dependencies**: Include all critical dependencies in health checks.
2. **Appropriate Status**: Use appropriate status levels (Healthy, Degraded, Unhealthy).
3. **Timeout Configuration**: Set appropriate timeouts for health checks.
4. **Regular Monitoring**: Regularly review health check results.
5. **Dashboard Access**: Restrict access to the dashboard to authorized personnel.

## Environment-Specific Configurations

Different environments may require different monitoring configurations:

### Development

- Lower alert thresholds for early detection
- More detailed error information
- Unrestricted dashboard access

### Production

- Higher alert thresholds to reduce noise
- Limited error details for security
- Restricted dashboard access
- Multiple notification channels for critical alerts

## Monitoring and Compliance

- Regularly review alert rules and thresholds
- Monitor alert frequency and adjust thresholds as needed
- Ensure compliance with security and privacy requirements
- Document all monitoring configurations and changes