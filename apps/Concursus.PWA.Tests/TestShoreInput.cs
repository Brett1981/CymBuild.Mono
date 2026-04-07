using Concursus.PWA.Shared;

namespace Concursus.PWA.Tests
{
    public class TestShoreInput : ShoreInput
    {
        // Expose all protected properties as public for testing

        public new int IntValueBinding
        {
            get => base.IntValueBinding;
            set => base.IntValueBinding = value;
        }

        public new string StringValueBinding
        {
            get => base.StringValueBinding;
            set => base.StringValueBinding = value;
        }

        public new bool BoolValueBinding
        {
            get => base.BoolValueBinding;
            set => base.BoolValueBinding = value;
        }

        public new DateTime? DateTimeValueBinding
        {
            get => base.DateTimeValueBinding;
            set => base.DateTimeValueBinding = value;
        }

        public new double DoubleValueBinding
        {
            get => base.DoubleValueBinding;
            set => base.DoubleValueBinding = value;
        }

        // Expose all protected methods as public for testing

        public new void SetDefaultWindowParameters()
        {
            base.SetDefaultWindowParameters();
        }

        public new void SetDetailWindowParameters()
        {
            base.SetDetailWindowParameters();
        }

        public new void NavigateToDetailPage()
        {
            base.NavigateToDetailPage();
        }

        public new void HandleModelOnClick()
        {
            base.HandleModelOnClick();
        }
    }
}