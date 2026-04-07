// Ignore Spelling: Concursus cts

using Microsoft.AspNetCore.Components;

namespace Concursus.Components.Shared.Helpers
{
    public abstract class DisposeSafeComponentBase : ComponentBase, IDisposable, IAsyncDisposable
    {
        private readonly List<IDisposable> _disposables = new();
        private readonly List<IAsyncDisposable> _asyncDisposables = new();
        private readonly List<Timer> _timers = new();
        private CancellationTokenSource? _cts;

        /// <summary>
        /// Registers an IDisposable instance for automatic disposal.
        /// </summary>
        protected void RegisterDisposable(IDisposable disposable)
        {
            if (disposable is Timer timer)
                _timers.Add(timer);
            else
                _disposables.Add(disposable);
        }

        /// <summary>
        /// Registers an IAsyncDisposable instance for automatic disposal.
        /// </summary>
        protected void RegisterAsyncDisposable(IAsyncDisposable asyncDisposable)
        {
            _asyncDisposables.Add(asyncDisposable);
        }

        /// <summary>
        /// Optionally stores a cancellation token source for clean shutdown.
        /// </summary>
        protected void RegisterCancellationToken(CancellationTokenSource cts)
        {
            _cts = cts;
        }

        /// <summary>
        /// Ensures safe disposal of all tracked resources.
        /// </summary>
        public virtual void Dispose()
        {
            foreach (var d in _disposables)
                d?.Dispose();

            foreach (var timer in _timers)
                timer?.Dispose();

            _cts?.Cancel();
            _cts?.Dispose();
        }

        public virtual async ValueTask DisposeAsync()
        {
            foreach (var asyncDisposable in _asyncDisposables)
            {
                if (asyncDisposable != null)
                    await asyncDisposable.DisposeAsync();
            }
        }
    }
}