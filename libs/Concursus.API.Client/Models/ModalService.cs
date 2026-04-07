using Concursus.API.Client.Models;

public class ModalService
{
    // Dictionary to map modal IDs to their DataObjectReferences
    private Dictionary<string, (DataObjectReference DataObjectReference, DateTime Timestamp)> _modals = new();

    public void RegisterModal(string modalId, DataObjectReference dataObjectReference)
    {
        //before updating the dictionary, check if the modalId already exists or if the DataObjectReference.EntityTypeGuid already
        //exists in _modals. If it does, Update this record with the new DataObjectReference
        foreach (var keyValuePair in GetOpenModals().ToList())
        {
            if (keyValuePair.Value.DataObjectReference.EntityTypeGuid == dataObjectReference.EntityTypeGuid)
            {
                UpdateModalDataObjectReference(keyValuePair.Key, dataObjectReference);
                return;
            }
        }
        // Update the dictionary to associate the modal ID with its DataObjectReference
        _modals[modalId] = (dataObjectReference, DateTime.UtcNow);
    }

    public void UnregisterModal(string modalId)
    {
        _modals.Remove(modalId);
    }

    public void ResetModalService()
    {
        _modals.Clear();
    }

    // Update the DataObjectReference if the modalId exists
    public bool UpdateModalDataObjectReference(string modalId, DataObjectReference newDataObjectReference)
    {
        if (_modals.ContainsKey(modalId))
        {
            _modals[modalId] = (newDataObjectReference, DateTime.UtcNow);
            return true; // Successfully updated
        }
        return false; // Modal ID not found
    }

    // Method to get detailed information about open modals
    public IReadOnlyDictionary<string, (DataObjectReference DataObjectReference, DateTime Timestamp)> GetOpenModals()
    {
        return _modals;
    }

    // Method to get the latest entry
    public (string ModalId, DataObjectReference DataObjectReference)? GetLatestModal()
    {
        if (_modals.Count == 0)
        {
            return null;
        }

        var latest = _modals.MaxBy(m => m.Value.Timestamp);
        return (latest.Key, latest.Value.DataObjectReference);
    }



    /// <summary>
    /// Replaces GetLatestModal().
    /// 
    /// Previously, we were returning the GUID for the last created modal.
    /// This is incorrect, hence why some grids never showed any value.
    /// To do this, we simply get the last created modal with MinBy().
    /// 
    /// Note: This might cause problems where there are 2 > modals at the time.
    /// 
    /// </summary>
    /// <returns></returns>
    public (string ModalId, DataObjectReference DataObjectReference)? GetParentModal()
    {
        if (_modals.Count == 0)
        {
            return null;
        }

        var latest = _modals.MinBy(m => m.Value.Timestamp);
        return (latest.Key, latest.Value.DataObjectReference);
    }

    public (DataObjectReference DataObjectReference, DateTime Timestamp)? RetrieveModalByModalId(string modalId)
    {
        if (_modals.TryGetValue(modalId, out var modalInfo))
        {
            return modalInfo;
        }

        return null; // Return null if the modal ID does not exist
    }

    // Function to retrieve a modal by DataObjectGuid
    public (string ModalId, DataObjectReference DataObjectReference, DateTime Timestamp)? RetrieveModalByDataObjectReference(Guid DataObjectGuid)
    {
        foreach (var modal in _modals)
        {
            if (modal.Value.DataObjectReference.DataObjectGuid == DataObjectGuid)
            {
                return (modal.Key, modal.Value.DataObjectReference, modal.Value.Timestamp);
            }
        }

        return null; // Return null if no matching modal is found
    }

    // Function to retrieve the latest modal by EntityTypeGuid
    public (string ModalId, DataObjectReference DataObjectReference, DateTime Timestamp)? RetrieveModalByEntityTypeGuid(Guid EntityTypeGuid)
    {
        var latestModal = _modals
            .Where(m => m.Value.DataObjectReference.EntityTypeGuid == EntityTypeGuid)
            .OrderByDescending(m => m.Value.Timestamp)
            .FirstOrDefault();

        if (latestModal.Equals(default(KeyValuePair<string, (DataObjectReference, DateTime)>)))
        {
            return null; // Return null if no matching modal is found
        }
        else
        {
            return (latestModal.Key, latestModal.Value.DataObjectReference, latestModal.Value.Timestamp);
        }
    }

    // Function to retrieve the DataObjectGuid by EntityTypeGuid - this ensures the Guid will not be
    // empty when there is an actual guid we can use.
    public Guid? RetrieveDataObjectGuidByEntityTypeGuid(Guid entityTypeGuid)
    {
        var modal = _modals.Values
            .Where(m => m.DataObjectReference.EntityTypeGuid == entityTypeGuid)
            .OrderByDescending(m => m.Timestamp)
            .FirstOrDefault();

        return modal.Equals(default((DataObjectReference, DateTime)))
            ? (Guid?)null
            : modal.DataObjectReference.DataObjectGuid;
    }
}