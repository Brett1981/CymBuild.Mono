using Concursus.API.Sage.Models;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Concursus.API.Sage.API
{
    public class Sage200ApiService
    {
        private readonly HttpClient _httpClient;

        public Sage200ApiService(string accessToken)
        {
            _httpClient = new HttpClient();
            // Assuming Bearer token is used for authentication
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        }

        public async Task<bool> SendInvoiceToSage(SalesInvoice invoice)
        {
            /*
             Posting a sales invoice does not actually create a 'sales invoice' entity, but a Posted Transaction of type
             'TradingAccountEntryTypeInvoice', therefore it is not possible to 'get' a sales invoice using the same API endpoint
             after it has been posted. Posting a sales invoice returns a URN (Unique Reference Number) that can be used to find
             the corresponding posted transaction.

             */

            var json = JsonSerializer.Serialize(invoice);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync("https://api.columbus.sage.com/uk/sage200extra/accounts/v1/sales_invoices", content);
            //Response will contain the URN of the posted transaction
            var urn = await response.Content.ReadAsStringAsync();

            return response.IsSuccessStatusCode;
        }

        public async Task<string> GetInvoiceDetailsAsync(string invoiceId)
        {
            // Replace the URL with the actual endpoint for fetching invoice details
            var requestUrl = $"https://api.columbus.sage.com/uk/sage200extra/accounts/v1/sales_posted_transactions/{invoiceId}";

            var response = await _httpClient.GetAsync(requestUrl);

            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                return content; // This will be a JSON string containing the invoice details
            }
            else
            {
                // Handle errors or unsuccessful responses accordingly
                throw new Exception($"Failed to retrieve invoice details. Status code: {response.StatusCode}");
            }
        }

        public async Task<string> GetContactsAsync()
        {
            // Replace with the actual endpoint for fetching contacts/accounts
            var requestUrl = "https://api.columbus.sage.com/uk/sage200/accounts/v1/customers";

            var response = await _httpClient.GetAsync(requestUrl);

            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                return content; // This will be a JSON string containing the contact/account details
            }
            else
            {
                // Handle errors or unsuccessful responses accordingly
                throw new Exception($"Failed to retrieve contact details. Status code: {response.StatusCode}");
            }
        }

        // Example method for fetching a specific contact/account by ID
        public async Task<string> GetContactByIdAsync(string contactId)
        {
            var requestUrl = $"https://api.columbus.sage.com/uk/sage200/accounts/v1/customers/{contactId}";

            var response = await _httpClient.GetAsync(requestUrl);

            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                return content;
            }
            else
            {
                throw new Exception($"Failed to retrieve contact details for ID {contactId}. Status code: {response.StatusCode}");
            }
        }

        public async Task<bool> CreateCustomerAsync(Customer customer)
        {
            var json = JsonSerializer.Serialize(customer);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            // Replace with the actual endpoint for creating a customer
            var response = await _httpClient.PostAsync("https://api.columbus.sage.com/uk/sage200/accounts/v1/customers", content);

            return response.IsSuccessStatusCode;
        }
    }
}