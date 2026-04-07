using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Rendering;
using System.Collections.ObjectModel;

namespace Concursus.Components.Shared.Classes
{
    public class CustomErrorBoundary : ErrorBoundaryBase
    {
        #region Public Constructors

        public CustomErrorBoundary()
        {
            MaximumErrorCount = 2;
        }

        #endregion Public Constructors

        #region Public Properties

        public new Exception? CurrentException => base.CurrentException;
        public ObservableCollection<Exception> ExceptionRecorderService { get; } = new();

        #endregion Public Properties

        #region Protected Methods

        protected override void BuildRenderTree(RenderTreeBuilder builder)
        {
            if (CurrentException is null)
            {
                builder.AddContent(0, ChildContent);
            }
            else
            {
                RenderErrorContent(builder);
            }
        }

        protected override Task OnErrorAsync(Exception exception)
        {
            Console.WriteLine("CustomErrorBoundary: OnErrorAsync called.");
            if (CurrentException is not null)
            {
                Console.WriteLine($"CustomErrorBoundary: CurrentException already set: {CurrentException.Message}");
                return Task.CompletedTask;
            }
            ExceptionRecorderService.Add(exception);
            return Task.CompletedTask;
        }

        #endregion Protected Methods

        #region Private Methods

        private void RecoverAndClearErrors()
        {
            Recover();
            ExceptionRecorderService.Clear();
        }

        // ReSharper disable once MethodTooLong
        private void RenderErrorContent(RenderTreeBuilder builder)
        {
            if (ErrorContent is not null)
            {
                builder.AddContent(1, ErrorContent(CurrentException ?? new Exception()));
            }
            else
            {
                builder.OpenElement(2, "div");
                builder.AddAttribute(3, "class", "text-danger border border-danger p-3");
                builder.AddContent(4, "Custom Error Boundary.");
                builder.AddContent(5, innerBuilder =>
                {
                    innerBuilder.OpenElement(6, "button");
                    innerBuilder.AddAttribute(7, "type", "button");
                    innerBuilder.AddAttribute(8, "class", "btn btn-link");
                    innerBuilder.AddAttribute(9, "onclick", RecoverAndClearErrors);
                    innerBuilder.AddContent(10, "Continue");
                    innerBuilder.CloseElement();
                });
                builder.CloseElement();
            }
        }

        #endregion Private Methods
    }
}