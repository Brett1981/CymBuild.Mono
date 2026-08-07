using Concursus.Components.Shared.Classes;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Xunit;

namespace Concursus.PWA.Tests
{
    public class ShoreInputTests
    {
        [Fact]
        public void IntValueBinding_ShouldUpdateDataPropertyAndInvokeEvents()
        {
            // Arrange
            var dataProperty = new API.Core.DataProperty
            {
                Value = Any.Pack(new Int32Value { Value = 0 })
            };
            var component = new TestShoreInput
            {
                DataProperty = dataProperty,
                OnError = EventCallback.Factory.Create<Exception>(this, ex => Assert.Fail("Error should not be thrown")),
                DataPropertyChanged = EventCallback.Factory.Create<API.Core.DataProperty>(this, dp => { /* handle change */ }),
                InputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args =>
                {
                    Assert.Equal(dataProperty.Value, args.NewValue);
                })
            };

            // Act
            component.IntValueBinding = 42;

            // Assert
            Assert.Equal(42, component.IntValueBinding);
            Assert.Equal(42, dataProperty.Value.Unpack<Int32Value>().Value);
        }

        [Fact]
        public void StringValueBinding_ShouldUpdateDataPropertyAndInvokeEvents()
        {
            // Arrange
            var dataProperty = new API.Core.DataProperty
            {
                Value = Any.Pack(new StringValue { Value = "" })
            };
            var component = new TestShoreInput
            {
                DataProperty = dataProperty,
                OnError = EventCallback.Factory.Create<Exception>(this, ex => Assert.Fail("Error should not be thrown")),
                DataPropertyChanged = EventCallback.Factory.Create<API.Core.DataProperty>(this, dp => { /* handle change */ }),
                InputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args =>
                {
                    Assert.Equal(dataProperty.Value, args.NewValue);
                })
            };

            // Act
            component.StringValueBinding = "New String";

            // Assert
            Assert.Equal("New String", component.StringValueBinding);
            Assert.Equal("New String", dataProperty.Value.Unpack<StringValue>().Value);
        }

        [Fact]
        public void BoolValueBinding_ShouldUpdateDataPropertyAndInvokeEvents()
        {
            // Arrange
            var dataProperty = new API.Core.DataProperty
            {
                Value = Any.Pack(new BoolValue { Value = false })
            };
            var component = new TestShoreInput
            {
                DataProperty = dataProperty,
                OnError = EventCallback.Factory.Create<Exception>(this, ex => Assert.Fail("Error should not be thrown")),
                DataPropertyChanged = EventCallback.Factory.Create<API.Core.DataProperty>(this, dp => { /* handle change */ }),
                InputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args =>
                {
                    Assert.Equal(dataProperty.Value, args.NewValue);
                })
            };

            // Act
            component.BoolValueBinding = true;

            // Assert
            Assert.True(component.BoolValueBinding);
            Assert.True(dataProperty.Value.Unpack<BoolValue>().Value);
        }

        [Fact]
        public void DateTimeValueBinding_ShouldUpdateDataPropertyAndInvokeEvents()
        {
            // Arrange
            var initialDateTime = new DateTime(2023, 1, 1);
            var dataProperty = new API.Core.DataProperty
            {
                Value = Any.Pack(Timestamp.FromDateTime(initialDateTime.ToUniversalTime()))
            };
            var component = new TestShoreInput
            {
                DataProperty = dataProperty,
                OnError = EventCallback.Factory.Create<Exception>(this, ex => Assert.Fail("Error should not be thrown")),
                DataPropertyChanged = EventCallback.Factory.Create<API.Core.DataProperty>(this, dp => { /* handle change */ }),
                InputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args =>
                {
                    Assert.Equal(dataProperty.Value, args.NewValue);
                })
            };

            // Act
            var newDateTime = new DateTime(2023, 2, 2);
            component.DateTimeValueBinding = newDateTime;

            // Assert
            Assert.Equal(newDateTime, component.DateTimeValueBinding);
            Assert.Equal(newDateTime, dataProperty.Value.Unpack<Timestamp>().ToDateTime());
        }

        [Fact]
        public void DoubleValueBinding_ShouldUpdateDataPropertyAndInvokeEvents()
        {
            // Arrange
            var dataProperty = new API.Core.DataProperty
            {
                Value = Any.Pack(new DoubleValue { Value = 0.0 })
            };
            var component = new TestShoreInput
            {
                DataProperty = dataProperty,
                OnError = EventCallback.Factory.Create<Exception>(this, ex => Assert.Fail("Error should not be thrown")),
                DataPropertyChanged = EventCallback.Factory.Create<API.Core.DataProperty>(this, dp => { /* handle change */ }),
                InputUpdated = EventCallback.Factory.Create<InputUpdatedArgs>(this, args =>
                {
                    Assert.Equal(dataProperty.Value, args.NewValue);
                })
            };

            // Act
            component.DoubleValueBinding = 3.14;

            // Assert
            Assert.Equal(3.14, component.DoubleValueBinding);
            Assert.Equal(3.14, dataProperty.Value.Unpack<DoubleValue>().Value);
        }

        [Fact]
        public void SetDefaultWindowParameters_ShouldExecuteWithoutError()
        {
            // Arrange
            var component = new TestShoreInput();

            // Act & Assert
            var exception = Record.Exception(() => component.SetDefaultWindowParameters());
            Assert.Null(exception); // Asserts no exception was thrown
        }

        [Fact]
        public void NavigateToDetailPage_ShouldExecuteWithoutError()
        {
            // Arrange
            var component = new TestShoreInput();

            // Act & Assert
            var exception = Record.Exception(() => component.NavigateToDetailPage());
            Assert.Null(exception); // Asserts no exception was thrown
        }

        [Fact]
        public void SetDetailWindowParameters_ShouldExecuteWithoutError()
        {
            // Arrange
            var component = new TestShoreInput();

            // Act & Assert
            var exception = Record.Exception(() => component.SetDetailWindowParameters());
            Assert.Null(exception); // Asserts no exception was thrown
        }

        [Fact]
        public async Task OnError_ShouldCaptureAndHandleExceptions()
        {
            // Arrange
            var component = new TestShoreInput();
            Exception capturedException = null;

            // Set up OnError callback to capture the exception
            component.OnError = EventCallback.Factory.Create<Exception>(this, ex =>
            {
                capturedException = ex;
                return Task.CompletedTask;
            });

            // Act: Manually invoke OnError with an exception
            var testException = new Exception("Test error");
            await component.OnError.InvokeAsync(testException);

            // Assert
            Assert.NotNull(capturedException);
            Assert.Equal("Test error", capturedException.Message);
        }
    }
}