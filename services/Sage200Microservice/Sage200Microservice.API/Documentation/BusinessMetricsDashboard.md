# Business Metrics Dashboard Documentation

## Overview

The Business Metrics Dashboard provides real-time insights into key business metrics for the Sage 200 API Microservice. It visualizes data related to customers, invoices, revenue, and API usage to help stakeholders make informed decisions.

## Features

### Data Collection

The dashboard collects and displays the following metrics:

1. **Customer Metrics**
   - Total number of customers
   - New customers in the last 24 hours, 7 days, and 30 days
   - Daily new customer trends

2. **Invoice Metrics**
   - Total number of invoices
   - Pending vs. completed invoices
   - New invoices in the last 24 hours, 7 days, and 30 days
   - Daily new invoice trends

3. **Revenue Metrics**
   - Total revenue
   - Revenue in the last 24 hours, 7 days, and 30 days
   - Average invoice value
   - Daily revenue trends

4. **API Usage Metrics**
   - Total API requests in the last 24 hours
   - Top API keys by usage
   - Top endpoints by usage
   - Hourly API request trends

### Dashboard Sections

The dashboard is organized into four main sections:

1. **Overview**: Provides a high-level summary of key metrics
2. **Customers**: Detailed customer acquisition and growth metrics
3. **Invoices**: Detailed invoice and revenue metrics
4. **API Usage**: Detailed API usage metrics and trends

## Implementation Details

### Backend Components

1. **BusinessMetricsService**
   - Background service that collects metrics at regular intervals
   - Exposes metrics through Prometheus for monitoring systems
   - Configurable collection interval and retention period

2. **BusinessMetricsController**
   - REST API endpoints for retrieving business metrics
   - Provides summary and detailed metrics for dashboard consumption
   - Implements caching for improved performance

### Frontend Components

1. **Dashboard UI**
   - Responsive web interface built with HTML, CSS, and JavaScript
   - Uses Bootstrap for layout and styling
   - Uses Chart.js for data visualization
   - Auto-refreshes data at configurable intervals

2. **Charts and Visualizations**
   - Line charts for trend analysis
   - Bar charts for comparative analysis
   - Doughnut charts for distribution analysis
   - Data tables for detailed information

## Configuration

The business metrics collection and dashboard are configured in the `appsettings.json` file under the `BusinessMetrics` section:

```json
"BusinessMetrics": {
  "Enabled": true,
  "CollectionIntervalSeconds": 60,
  "RetentionDays": 90,
  "MetricsToCollect": [
    "TotalCustomers",
    "NewCustomers",
    "TotalInvoices",
    "PendingInvoices",
    "CompletedInvoices",
    "TotalRevenue",
    "AverageInvoiceValue",
    "ApiKeyUsage",
    "EndpointUsage"
  ]
}
```

### Configuration Options

- **Enabled**: Enables or disables the business metrics collection
- **CollectionIntervalSeconds**: The interval at which metrics are collected (in seconds)
- **RetentionDays**: The number of days to retain metrics data
- **MetricsToCollect**: The list of metrics to collect

## Accessing the Dashboard

The business metrics dashboard is available at the following URL:

```
https://your-api-domain/business-dashboard
```

## Integration with Monitoring Systems

The business metrics are exposed through Prometheus metrics, which can be integrated with monitoring systems like Grafana for more advanced visualization and alerting.

### Prometheus Metrics

The following Prometheus metrics are exposed:

- `sage200_total_customers`: Total number of customers
- `sage200_new_customers_last_24h`: Number of new customers in the last 24 hours
- `sage200_total_invoices`: Total number of invoices
- `sage200_pending_invoices`: Number of pending invoices
- `sage200_completed_invoices`: Number of completed invoices
- `sage200_total_revenue`: Total revenue from all invoices
- `sage200_average_invoice_value`: Average invoice value
- `sage200_api_key_usage`: API key usage count (labeled by client name and key ID)
- `sage200_endpoint_usage`: Endpoint usage count (labeled by endpoint and method)

## Security Considerations

- The dashboard is protected by the same security mechanisms as the rest of the API
- Access to the dashboard can be restricted using API key authentication
- Sensitive business data is not exposed through the dashboard
- All dashboard requests are logged in the audit log

## Best Practices

1. **Regular Monitoring**: Check the dashboard regularly to identify trends and anomalies
2. **Data Validation**: Validate dashboard data against other sources periodically
3. **Performance Optimization**: Monitor dashboard performance and optimize as needed
4. **Security**: Restrict access to the dashboard to authorized personnel only
5. **Customization**: Customize the dashboard to focus on metrics most relevant to your business

## Troubleshooting

### Common Issues

1. **Dashboard Not Loading**
   - Check if the API is running
   - Verify that the business metrics service is enabled
   - Check browser console for JavaScript errors

2. **Missing or Incomplete Data**
   - Verify that the metrics collection service is running
   - Check the logs for any errors during data collection
   - Ensure that the database contains the necessary data

3. **Performance Issues**
   - Consider increasing the refresh interval
   - Optimize database queries used for metrics collection
   - Implement additional caching mechanisms

## Future Enhancements

1. **User-Specific Dashboards**: Allow users to create customized dashboards
2. **Advanced Analytics**: Add predictive analytics and forecasting
3. **Export Capabilities**: Allow exporting dashboard data to CSV or PDF
4. **Mobile App**: Create a mobile app version of the dashboard
5. **Real-Time Alerts**: Add real-time alerting for critical metrics