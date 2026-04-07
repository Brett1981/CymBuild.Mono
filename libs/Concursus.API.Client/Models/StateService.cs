namespace Concursus.API.Client.Models
{
    public class StateService
    {
        #region Public Properties

        public string ChildRecordGuid { get; set; } = Guid.Empty.ToString();
        public string ChildRecordItem { get; set; } = Guid.Empty.ToString();
        public string ChildRecordType { get; set; } = Guid.Empty.ToString();
        public string OriginalRecordGuid { get; set; } = Guid.Empty.ToString();
        public string OriginalRecordItem { get; set; } = Guid.Empty.ToString();
        public string OriginalRecordType { get; set; } = Guid.Empty.ToString();

        #endregion Public Properties

        #region Private Properties

        private Stack<Dictionary<string, string>> StateReferences { get; set; } = new Stack<Dictionary<string, string>>();

        #endregion Private Properties

        /*
           ======== [ OE: CBLD-483] =========
            Utilise the "stack" data type (Last in First out).

            + Idea is that when we open a modal, we create a new entry into the stack.
            + Closing the last open modal should pop the last entry of the stack.
            + This in idea should ensure that we always have references to the correct values across nested modals.

         */

        public void AddNewStateReference(string EntityTypeGuid, string OriginalRecordGuid)
        {
            var stateToPush = new Dictionary<string, string>();

            //Add original record type + guid.
            stateToPush.Add("OriginalRecordType", EntityTypeGuid);
            stateToPush.Add("OriginalRecordGuid", OriginalRecordGuid);

            //Add it to the stack.
            StateReferences.Push(stateToPush);
        }

        public Dictionary<string, string> GetContextReference()
        {
            if (!IsStateReferenceStackEmpty())
                return StateReferences.Pop(); //Use pop to ensure the element in removed
            else
                return new Dictionary<string, string>();
        }

        public bool IsStateReferenceStackEmpty()
        {
            if (StateReferences.Count > 0)
                return false;

            return true;
        }

        /*
            [OE: CBLD-490]
            Updates an existing reference - by logic, this should always be the last element
            going into the stack.
         */

        public bool UpdateExistingStateReference(string EntityTypeGuid, string OriginalRecordGuid)
        {
            //Check if the stack is empty first.
            if (IsStateReferenceStackEmpty())
                return false;
            //Also check for empty guids as we do not want to set these.
            else if (EntityTypeGuid == Guid.Empty.ToString() || OriginalRecordGuid == Guid.Empty.ToString())
                return false;

            //Get the reference for the current modal.
            var RefToUpdate = StateReferences.Peek();

            //Check to ensure that we are indeed updating the correct reference.
            //Do this by comparing the record type.
            if (RefToUpdate["OriginalRecordType"] == EntityTypeGuid)
            {
                RefToUpdate["OriginalRecordGuid"] = OriginalRecordGuid;
                return true;
            }

            return false; //Return empty if the reference was not updated!
        }

        /* There should be no need to have this function - what is opened must be closed,
            therefore the stack should always get cleared by the user - given they don't find
            a way to close grids they shouldn't.
        */

        // Resets the stack.
        //public void ClearStateReferences()
        //{
        //    this.StateReferences.Clear();
        //}
    }
}