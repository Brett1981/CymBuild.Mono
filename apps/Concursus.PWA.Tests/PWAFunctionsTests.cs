using Concursus.API.Client.Models;
using Concursus.Components.Shared.Helpers;
using Concursus.PWA.Classes;
using Concursus.PWA.Shared;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Forms;
using Microsoft.JSInterop;
using Moq;
using Xunit;
using static Concursus.PWA.Shared.MessageDisplay;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests
{
    public class PWAFunctionsTests
    {
        [Theory]
        [InlineData("123e4567-e89b-12d3-a456-426614174000", true)] // Valid GUID
        [InlineData("not-a-guid", false)] // Invalid GUID
        public void IsGuid_ShouldReturnCorrectResult(string value, bool expectedResult)
        {
            // Act
            bool result = PWAFunctions.IsGuid(value);

            // Assert
            Assert.Equal(expectedResult, result);
        }

        [Theory]
        [InlineData("123.45", true)] // Valid number
        [InlineData("abc", false)] // Invalid number
        public void IsNumber_ShouldReturnCorrectResult(string value, bool expectedResult)
        {
            // Act
            bool result = PWAFunctions.IsNumber(value);

            // Assert
            Assert.Equal(expectedResult, result);
        }

        [Theory]
        [InlineData("https://example.com/first/second", "first")]
        [InlineData("https://example.com/", "")]
        [InlineData("https://example.com/onlyone", "onlyone")]
        public void GetFirstUrlSegment_ShouldReturnCorrectSegment(string url, string expectedSegment)
        {
            // Act
            string result = PWAFunctions.GetFirstUrlSegment(url);

            // Assert
            Assert.Equal(expectedSegment, result);
        }

        [Theory]
        [InlineData("valid-filename.txt", "valid-filename.txt")]
        [InlineData("invalid/filename.txt", "invalidfilename.txt")]
        [InlineData("filename with spaces.txt", "filename with spaces.txt")] // Updated expected output
        [InlineData("file:name.txt", "filename.txt")]
        public void SanitizeFileName_ShouldRemoveIllegalCharacters(string input, string expectedOutput)
        {
            // Act
            var result = PWAFunctions.SanitizeFileName(input);

            // Assert
            Assert.Equal(expectedOutput, result);
        }

        [Theory]
        [InlineData("123e4567-e89b-12d3-a456-426614174000", "123e4567-e89b-12d3-a456-426614174000")] // Valid GUID
        [InlineData("invalid-guid", "00000000-0000-0000-0000-000000000000")] // Invalid GUID
        [InlineData("", "00000000-0000-0000-0000-000000000000")] // Empty string
        public void ParseAndReturnEmptyGuidIfInvalid_ShouldReturnCorrectGuid(string input, string expectedOutput)
        {
            // Act
            var result = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(input);

            // Assert
            Assert.Equal(Guid.Parse(expectedOutput), result);
        }

        [Theory]
        [InlineData("9f0db80e-a96a-4273-b23e-15fc9f2e4a01", "Account Folders")]
        [InlineData("d42eac7e-705c-4d17-bf6b-28d7fde1fe4f", "Enquiry Folders")]
        [InlineData("non-existent-guid", "")] // GUID not in list should return empty
        public void GetSharePointSiteDropDownNameFromGuid_ShouldReturnCorrectSiteName(string siteGuid, string expectedName)
        {
            // Act
            var result = PWAFunctions.GetSharePointSiteDropDownNameFromGuid(siteGuid);

            // Assert
            Assert.Equal(expectedName, result);
        }

        [Theory]
        [InlineData("https://example.com/https://last.com", "https://last.com")]
        [InlineData("https://example.com/path", "https://example.com/path")]
        [InlineData("http://no-https.com", "http://no-https.com")]
        [InlineData("https://example.com/https", "https")]
        public void ExtractLastHttps_ShouldReturnCorrectSubstring(string input, string expected)
        {
            // Act
            var result = PWAFunctions.ExtractLastHttps(input);

            // Assert
            Assert.Equal(expected, result);
        }

        [Fact]
        public void NavigateToCorrectPage_ShouldConstructUrlAndNavigateCorrectly()
        {
            // Arrange
            var navManager = new TestNavigationManager();
            var dataObjectReference = new DataObjectReference(Guid.NewGuid().ToString(), Guid.NewGuid().ToString());
            string returnUrl = "https://return.url";
            bool isWindowed = false;

            // Act
            PWAFunctions.NavigateToCorrectPage(navManager, dataObjectReference, returnUrl, isWindowed);

            // Assert
            Assert.Contains(dataObjectReference.DataObjectGuid.ToString(), navManager.NavigatedUri);
        }

        [Fact]
        public async Task StartDownload_ShouldInvokeJavaScriptWithCorrectParameters()
        {
            // Arrange
            var jsRuntimeMock = new Mock<IJSRuntime>();
            string downloadUrl = "data:text/csv;base64,SGVhZGVyMSxIZWFkZXIyClJvdzEsUm93Mg==";
            string fileName = "Export.csv";

            // Use InvokeAsync<object> instead of InvokeVoidAsync for mocking
            jsRuntimeMock
                .Setup(js => js.InvokeAsync<object>("triggerFileDownload", It.Is<object[]>(args =>
                    args.Length == 2 &&
                    args[0].Equals(fileName) &&
                    args[1].ToString() == downloadUrl)))
                .Returns(ValueTask.FromResult<object>(null))
                .Verifiable();

            // Act
            await PWAFunctions.StartDownload(jsRuntimeMock.Object, downloadUrl, fileName);

            // Assert
            jsRuntimeMock.Verify(js => js.InvokeAsync<object>("triggerFileDownload", It.Is<object[]>(args =>
                args.Length == 2 &&
                args[0].Equals(fileName) &&
                args[1].ToString() == downloadUrl)), Times.Once);
        }

        [Fact]
        public void UnPackGoogleProtoBufTypes_ShouldReturnUnpackedStringValue()
        {
            // Arrange
            var packedValue = Any.Pack(new StringValue { Value = "Test String" });

            // Act
            var result = PWAFunctions.UnPackGoogleProtoBufTypes(packedValue);

            // Assert
            Assert.Equal("Test String", result);
        }

        [Fact]
        public void UnPackGoogleProtoBufTypes_ShouldReturnUnpackedIntValue()
        {
            // Arrange
            var packedValue = Any.Pack(new Int32Value { Value = 42 });

            // Act
            var result = PWAFunctions.UnPackGoogleProtoBufTypes(packedValue);

            // Assert
            Assert.Equal(42, result);
        }

        [Fact]
        public async Task GenerateCsvDownload_ShouldCallJsRuntimeWithCorrectParameters()
        {
            // Arrange
            var jsRuntimeMock = new Mock<IJSRuntime>();
            string csvContent = "Header1,Header2\nRow1,Row2";
            string fileName = "Export.csv";
            string expectedDataUrl = "data:text/csv;base64,SGVhZGVyMSxIZWFkZXIyClJvdzEsUm93Mg==";

            // Set up the mock to expect InvokeAsync<object>
            jsRuntimeMock
                .Setup(js => js.InvokeAsync<object>("triggerFileDownload", It.Is<object[]>(args =>
                    args.Length == 2 &&
                    args[0].Equals(fileName) &&
                    args[1].ToString().StartsWith("data:text/csv;base64,"))))
                .Returns(ValueTask.FromResult<object>(null))
                .Verifiable();

            // Act
            await PWAFunctions.GenerateCsvDownload(csvContent, jsRuntimeMock.Object, fileName);

            // Assert
            jsRuntimeMock.Verify(js => js.InvokeAsync<object>("triggerFileDownload", It.Is<object[]>(args =>
                args.Length == 2 &&
                args[0].Equals(fileName) &&
                args[1].ToString().StartsWith("data:text/csv;base64,"))), Times.Once);
        }

        [Fact]
        public async Task DisplayMessageAsync_ShouldInvokeOnErrorWithCorrectException()
        {
            // Arrange
            Exception capturedException = null;
            PWAFunctions.OnError = EventCallback.Factory.Create<Exception>(this, (Exception ex) =>
            {
                capturedException = ex;
                return Task.CompletedTask;
            });

            string message = "Test message";
            ShowMessageType messageType = ShowMessageType.Information;

            // Act
            await PWAFunctions.DisplayMessageAsync(message, messageType);

            // Assert
            Assert.NotNull(capturedException);
            Assert.Equal(message, capturedException.Message);
            Assert.Equal(messageType, capturedException.Data["MessageType"]);
        }

        [Fact]
        public async Task EnsureDataObjectReferenceAsync_ShouldReturnCorrectDataObjectReference()
        {
            // Arrange
            var dataObject = new API.Core.DataObject
            {
                Guid = Guid.NewGuid().ToString(),
                EntityTypeGuid = Guid.NewGuid().ToString()
            };
            var modalServiceMock = new Mock<ModalService>();

            // Act
            var result = await PWAFunctions.EnsureDataObjectReferenceAsync(dataObject, null, modalService: modalServiceMock.Object);

            // Assert
            Assert.Equal(dataObject.Guid.ToString(), result.DataObjectGuid.ToString());
            Assert.Equal(dataObject.EntityTypeGuid, result.EntityTypeGuid.ToString());
        }

        [Fact]
        public void PrepareStateChanges_ShouldUpdateStateServiceCorrectly()
        {
            // Arrange
            var guid = Guid.NewGuid().ToString();
            var entityTypeGuid = Guid.NewGuid().ToString();

            // Create a DataObject with the expected Guid and EntityTypeGuid
            var dataObject = new API.Core.DataObject
            {
                Guid = guid,
                EntityTypeGuid = entityTypeGuid
            };
            var editContext = new EditContext(dataObject);
            var stateService = new StateService();

            // Scenario 1: Both OriginalRecordGuid and parentRecordGuid are empty, so Original
            // properties should be set
            string emptyParentRecordGuid = Guid.Empty.ToString();

            // Act
            PWAFunctions.PrepareStateChanges(editContext, stateService, emptyParentRecordGuid);

            // Assert Scenario 1
            Assert.Equal(dataObject.EntityTypeGuid, stateService.OriginalRecordType);
            Assert.Equal(dataObject.Guid, stateService.OriginalRecordGuid);

            // Scenario 2: parentRecordGuid does not match OriginalRecordGuid, so Child properties
            // should be set
            string parentRecordGuid = Guid.NewGuid().ToString(); // Different from stateService.OriginalRecordGuid after Scenario 1

            // Act
            PWAFunctions.PrepareStateChanges(editContext, stateService, parentRecordGuid);

            // Assert Scenario 2
            Assert.Equal(dataObject.EntityTypeGuid, stateService.ChildRecordType);
            Assert.Equal(dataObject.Guid, stateService.ChildRecordGuid);
        }

        [Fact]
        public void ResetStateService_ShouldClearStateServiceProperties()
        {
            // Arrange
            var stateService = new StateService
            {
                OriginalRecordGuid = Guid.NewGuid().ToString(),
                OriginalRecordType = Guid.NewGuid().ToString(),
                ChildRecordGuid = Guid.NewGuid().ToString(),
            };

            // Act
            PWAFunctions.ResetStateService(stateService);

            // Assert
            Assert.Equal(Guid.Empty.ToString(), stateService.OriginalRecordGuid);
            Assert.Equal(Guid.Empty.ToString(), stateService.OriginalRecordType);
            Assert.Equal(Guid.Empty.ToString(), stateService.ChildRecordGuid);
        }

        [Fact]
        public void GetValueByEntityPropertyGuid_ShouldReturnCorrectValue()
        {
            // Arrange
            var editPage = new EditPage();
            var guid = Guid.NewGuid().ToString();
            editPage.dataObject.DataProperties.Add(new API.Core.DataProperty
            {
                EntityPropertyGuid = guid,
                Value = Any.Pack(new Int32Value { Value = 100 })
            });

            // Act
            var result = PWAFunctions.GetValueByEntityPropertyGuid(editPage, guid, WellKnownType.Int32);

            // Assert
            Assert.Equal(100, result);
        }

        [Fact]
        public void ProcessDataObjectReference_ShouldReturnCorrectSerializedReference()
        {
            // Arrange
            var modalServiceMock = new Mock<ModalService>();
            var parentDataObjectReference = new DataObjectReference(Guid.NewGuid().ToString(), Guid.NewGuid().ToString());
            var parentGuid = Guid.NewGuid().ToString();
            var entityTypeGuid = Guid.NewGuid().ToString();

            // Act
            var (resultReference, serializedReference) = PWAFunctions.ProcessDataObjectReference(
                modalServiceMock.Object, parentDataObjectReference, parentGuid, entityTypeGuid);

            // Assert
            Assert.Equal(parentGuid, resultReference.DataObjectGuid.ToString());
            Assert.Equal(entityTypeGuid, resultReference.EntityTypeGuid.ToString());
            Assert.Contains(parentGuid, serializedReference);
            Assert.Contains(entityTypeGuid, serializedReference);
        }
    }
}