// wwwroot/js/Index.razor.js
// Blazor add-in pane helper: safe item reading across Read/Compose and host differences.

export async function getEmailData(dotNetHelper) {
    try {
        if (!window.Office || !Office.context || !Office.context.mailbox) {
            console.error("Office.context.mailbox not available.");
            return;
        }

        const item = Office.context.mailbox.item;
        if (!item) {
            console.error("No mailbox item available.");
            return;
        }

        const subject = safeString(item.subject);
        const bodyContent = await tryGetBodyText(item);

        const toRecipients = await getRecipients(item, "toRecipients");
        const ccRecipients = await getRecipients(item, "ccRecipients");
        const bccRecipients = await getRecipients(item, "bccRecipients");

        const attachments = await tryGetAttachments(item);
        const customProperties = await loadRelevantCustomProperties(item);

        const emailData = {
            ItemType: item.itemType ?? null,
            Subject: subject,
            Body: bodyContent,
            Meeting: {
                SeriesId: item.seriesId ?? null,
                StartDateTime: item.start ?? null,
                EndDateTime: item.end ?? null
            },
            Sender: {
                SenderName: item.sender?.displayName ?? null,
                SenderEmail: item.sender?.emailAddress ?? null
            },
            ItemId: item.itemId ?? null,
            ConversationId: item.conversationId ?? null,
            ToRecipients: toRecipients,
            CcRecipients: ccRecipients,
            BccRecipients: bccRecipients,
            Attachments: attachments,
            CustomProperties: customProperties
        };

        await dotNetHelper.invokeMethodAsync("ReceiveEmailData", emailData);
        await logMailboxAndSettings(dotNetHelper);
    } catch (err) {
        console.error("Error in getEmailData:", err);
    }
}

function safeString(value) {
    return (value === undefined || value === null) ? "" : String(value);
}

async function tryGetBodyText(item) {
    try {
        if (item?.body?.getAsync) {
            return await new Promise((resolve) => {
                item.body.getAsync("text", (result) => {
                    if (result && result.status === "succeeded") resolve(result.value ?? "");
                    else resolve("");
                });
            });
        }
    } catch (e) {
        console.error("tryGetBodyText error:", e);
    }
    return "";
}

async function getRecipients(item, propName) {
    try {
        const prop = item?.[propName];

        if (Array.isArray(prop)) {
            return prop.map(r => ({ Name: r?.displayName ?? null, Email: r?.emailAddress ?? null }));
        }

        if (prop?.getAsync) {
            const values = await new Promise((resolve) => {
                prop.getAsync((ar) => resolve(ar && ar.status === "succeeded" ? (ar.value ?? []) : []));
            });

            return (values ?? []).map(r => ({ Name: r?.displayName ?? null, Email: r?.emailAddress ?? null }));
        }
    } catch (e) {
        console.error(`getRecipients(${propName}) error:`, e);
    }
    return [];
}

async function tryGetAttachments(item) {
    try {
        const atts = item?.attachments;
        if (!Array.isArray(atts) || atts.length === 0) return [];

        const results = await Promise.all(atts.map(att => {
            return new Promise((resolve) => {
                // We only return metadata here (content retrieval is usually blocked/slow and not needed for listing)
                resolve({
                    AttachmentId: att.id,
                    AttachmentName: att.name,
                    AttachmentType: att.attachmentType,
                    Inline: att.isInline ?? false
                });
            });
        }));

        return results.filter(Boolean);
    } catch (e) {
        console.error("tryGetAttachments error:", e);
        return [];
    }
}

async function loadRelevantCustomProperties(item) {
    try {
        if (!item?.loadCustomPropertiesAsync) return {};

        return await new Promise((resolve) => {
            item.loadCustomPropertiesAsync((result) => {
                if (!result || result.status !== "succeeded") return resolve({});

                const props = result.value;
                resolve({
                    CymBuildOutlookFilingHistory: props.get("CymBuildOutlookFilingHistory") ?? null,
                    CymBuildOutlookFilingDestination: props.get("CymBuildOutlookFilingDestination") ?? null,
                    DoNotFile: props.get("DoNotFile") ?? null
                });
            });
        });
    } catch (e) {
        console.error("loadRelevantCustomProperties error:", e);
        return {};
    }
}

async function logMailboxAndSettings(dotNetHelper) {
    try {
        if (!window.Office || !Office.context?.mailbox) return;

        const mailbox = Office.context.mailbox;
        const settings = Office.context.roamingSettings;

        const mailboxInfo = {
            userProfile: {
                displayName: mailbox.userProfile?.displayName ?? null,
                emailAddress: mailbox.userProfile?.emailAddress ?? null,
                id: mailbox.userProfile?.id ?? null
            }
        };

        const settingsInfo = {};
        try {
            settingsInfo.LastFiledLocation = settings.get("LastFiledLocation");
            settingsInfo.ButtonsExpanded = settings.get("ButtonsExpanded");
        } catch { }

        const combinedInfo = { mailboxInfo, settingsInfo };
        await dotNetHelper.invokeMethodAsync("ReceiveMailboxAndSettingsData", combinedInfo);
    } catch (e) {
        console.error("logMailboxAndSettings error:", e);
    }
}

export async function checkSharedMailbox() {
    return new Promise((resolve) => {
        try {
            if (!window.Office || !Office.context?.mailbox?.item) {
                resolve(null);
                return;
            }

            const item = Office.context.mailbox.item;

            if (item.getSharedPropertiesAsync) {
                item.getSharedPropertiesAsync((result) => {
                    if (result && result.status === Office.AsyncResultStatus.Succeeded && result.value) {
                        resolve({
                            owner: result.value.owner,
                            delegatePermissions: JSON.stringify(result.value.delegatePermissions)
                        });
                    } else {
                        resolve(null);
                    }
                });
            } else {
                const userEmail = Office.context.mailbox.userProfile?.emailAddress ?? null;
                resolve({ owner: userEmail, delegatePermissions: "FullAccess" });
            }
        } catch (e) {
            console.error("checkSharedMailbox error:", e);
            resolve(null);
        }
    });
}

// Graph token helper (Office SSO)
// NOTE: This returns a Graph token only when Office can issue one.
// If it returns a token with aud=api://... then your request isn't being honoured.
window.getGraphAccessToken = async function (opts) {
    const forceRefresh = !!(opts && opts.forceRefresh);

    if (!window.OfficeRuntime?.auth?.getAccessToken) {
        throw new Error("OfficeRuntime.auth.getAccessToken is not available in this host.");
    }

    return await OfficeRuntime.auth.getAccessToken({
        allowSignInPrompt: true,
        allowConsentPrompt: true,
        forMSGraphAccess: true,
        forceRefresh
    });
};

// Notification helper
window.showNotification = function (message) {
    try {
        const item = Office?.context?.mailbox?.item;
        if (!item?.notificationMessages?.addAsync) return;

        item.notificationMessages.addAsync("notification", {
            type: "informationalMessage",
            message: String(message ?? ""),
            icon: "icon16",
            persistent: true
        });
    } catch (e) {
        console.error("showNotification error:", e);
    }
};

// Wire item changed -> Blazor (safe init)
function registerItemChangedHandler() {
    try {
        if (!window.Office || typeof Office.onReady !== "function") return;

        Office.onReady((info) => {
            try {
                if (!info || info.host !== Office.HostType.Outlook) return;

                const mailbox = Office.context?.mailbox;
                if (!mailbox?.addHandlerAsync) return;

                mailbox.addHandlerAsync(Office.EventType.ItemChanged, () => {
                    try {
                        DotNet.invokeMethodAsync("CymBuild_Outlook_Addin", "ItemChanged");
                    } catch (e) {
                        console.error("DotNet ItemChanged invoke failed:", e);
                    }
                });
            } catch (e) {
                console.error("Office.onReady handler init failed:", e);
            }
        });
    } catch (e) {
        console.error("registerItemChangedHandler error:", e);
    }
}

registerItemChangedHandler();
