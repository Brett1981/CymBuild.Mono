/* eslint-disable no-undef */
(() => {
    // ------------------------------
    // Config
    // ------------------------------
    const API = {
        summary: "/api/businessmetrics/summary",
        customers: "/api/businessmetrics/customers",
        invoices: "/api/businessmetrics/invoices",
        apiUsage: "/api/businessmetrics/api-usage",
        health: "/health",
    };

    const CACHE_KEY = "s200-dashboard-cache-v2";
    const REQUEST_TIMEOUT_MS = 10000;

    // ------------------------------
    // Utilities
    // ------------------------------
    const $ = (id) => document.getElementById(id);
    const fmtGBP = (n) =>
        new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" }).format(n || 0);
    const fmtTs = (iso) =>
        new Date(iso || Date.now()).toLocaleString(undefined, {
            year: "numeric",
            month: "short",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
        });

    const timeout = (ms) =>
        new Promise((_, reject) => setTimeout(() => reject(new Error("timeout")), ms));

    const fetchJson = async (url) => {
        const ctrl = new AbortController();
        const t = timeout(REQUEST_TIMEOUT_MS).catch((e) => {
            ctrl.abort();
            throw e;
        });

        // correlation id so it shows in your logs
        const correlationId = (crypto && crypto.randomUUID) ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`;

        const res = await Promise.race([
            fetch(url, {
                headers: { "X-Correlation-ID": correlationId },
                signal: ctrl.signal,
                cache: "no-store",
            }),
            t,
        ]);

        if (!res.ok) throw new Error(`${url} -> ${res.status}`);
        const json = await res.json();
        return { json, headers: res.headers };
    };

    const saveCache = (payload) => {
        try {
            localStorage.setItem(
                CACHE_KEY,
                JSON.stringify({
                    ts: Date.now(),
                    data: payload,
                })
            );
        } catch {
            // ignore quota/serialization errors
        }
    };

    const loadCache = () => {
        try {
            const raw = localStorage.getItem(CACHE_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch {
            return null;
        }
    };

    const showStaleBanner = (msg) => {
        let el = document.getElementById("staleBanner");
        if (!el) {
            el = document.createElement("div");
            el.id = "staleBanner";
            el.className = "alert alert-warning text-dark mb-0";
            const topbar = document.querySelector(".topbar");
            topbar.insertAdjacentElement("afterend", el);
        }
        el.textContent = msg;
    };

    const hideStaleBanner = () => {
        const el = document.getElementById("staleBanner");
        if (el) el.remove();
    };

    const setHealthChip = (status, msg) => {
        const chip = $("healthChip");
        chip.classList.remove("bg-success", "bg-warning", "bg-danger", "bg-secondary");
        chip.textContent = `Health: ${msg || status}`;
        switch (status) {
            case "healthy":
                chip.classList.add("bg-success");
                break;
            case "degraded":
                chip.classList.add("bg-warning");
                break;
            case "unhealthy":
                chip.classList.add("bg-danger");
                break;
            default:
                chip.classList.add("bg-secondary");
        }
    };

    const checkHealth = async () => {
        try {
            const { json, headers } = await fetchJson(API.health);

            // Normalize to 'healthy' | 'degraded' | 'unhealthy'
            const norm = (s) => ({
                Healthy: "healthy", healthy: "healthy",
                Degraded: "degraded", degraded: "degraded",
                Unhealthy: "unhealthy", unhealthy: "unhealthy"
            }[s]);

            let rawStatus = null;

            // 1) Common ASP.NET HealthChecks format: { status: "Degraded", entries: {...} }
            if (json && (json.status || json.Status)) {
                rawStatus = json.status || json.Status;
            }

            // 2) If not present, look through entries and pick the worst
            if (!rawStatus && json && json.entries && typeof json.entries === "object") {
                const vals = Object.values(json.entries).map(e => e?.status || e?.Status).filter(Boolean);
                if (vals.length) {
                    // Worst first: Unhealthy > Degraded > Healthy
                    rawStatus = vals.includes("Unhealthy") ? "Unhealthy"
                        : vals.includes("Degraded") ? "Degraded"
                            : vals.includes("Healthy") ? "Healthy" : null;
                }
            }

            // 3) Some health endpoints return plain text like "Healthy"
            if (!rawStatus && typeof json === "string") {
                rawStatus = json.trim();
            }

            // 4) Optional header some services set
            if (!rawStatus) {
                const h = headers.get("X-Health-Status");
                if (h) rawStatus = h;
            }

            const normalized = norm(rawStatus) || "degraded"; // sensible default
            setHealthChip(normalized, normalized);
        } catch {
            // If the health endpoint itself fails, treat as degraded
            setHealthChip("degraded", "degraded");
        }
    };

    // ------------------------------
    // Charts
    // ------------------------------
    let charts = {};
    const ensureChart = (id, type, data, options) => {
        // Graceful if Chart.js failed to load
        if (typeof Chart === "undefined") return null;

        if (charts[id]) {
            charts[id].data = data;
            charts[id].options = options || charts[id].options;
            charts[id].update();
            return charts[id];
        }
        const ctx = $(id).getContext("2d");
        charts[id] = new Chart(ctx, { type, data, options });
        return charts[id];
    };

    // ------------------------------
    // UI Updaters
    // ------------------------------
    const updateFromSummary = (summary) => {
        const c = summary.CustomerMetrics || {};
        const i = summary.InvoiceMetrics || {};
        const r = summary.RevenueMetrics || {};
        const a = summary.ApiUsageMetrics || {};

        $("totalCustomers").textContent = c.TotalCustomers ?? "-";
        $("newCustomers24h").textContent = `+${c.NewCustomers24h ?? 0}`;
        $("totalInvoices").textContent = i.TotalInvoices ?? "-";
        $("pendingInvoices").textContent = i.PendingInvoices ?? 0;
        $("totalRevenue").textContent = fmtGBP(r.TotalRevenue ?? 0);
        $("revenue24h").textContent = (r.Revenue24h ?? 0).toFixed(2);
        $("avgInvoice").textContent = (r.AverageInvoiceValue ?? 0).toFixed(2);
        $("apiRequests24h").textContent = a.TotalRequests24h ?? "-";

        $("growth24h").textContent = c.NewCustomers24h ?? 0;
        $("growth7d").textContent = c.NewCustomers7d ?? 0;
        $("growth30d").textContent = c.NewCustomers30d ?? 0;

        $("lastUpdated").textContent = fmtTs(summary.Timestamp);
    };

    const updateCustomers = (data) => {
        const labels = (data.DailyNewCustomers || []).map((p) =>
            new Date(p.Date).toLocaleDateString()
        );
        const values = (data.DailyNewCustomers || []).map((p) => p.Value || 0);

        ensureChart(
            "newCustomersChart",
            "line",
            {
                labels,
                datasets: [{ label: "New Customers", data: values, borderWidth: 2, fill: false, tension: 0.25 }],
            },
            { responsive: true, maintainAspectRatio: false }
        );

        ensureChart(
            "dailyNewCustomersChart",
            "bar",
            {
                labels,
                datasets: [{ label: "New Customers", data: values, borderWidth: 1 }],
            },
            { responsive: true, maintainAspectRatio: false }
        );
    };

    const updateInvoices = (data) => {
        $("pendingCount").textContent = data.PendingInvoices ?? 0;
        $("completedCount").textContent = data.CompletedInvoices ?? 0;

        const labels = (data.DailyNewInvoices || []).map((p) =>
            new Date(p.Date).toLocaleDateString()
        );
        const newInv = (data.DailyNewInvoices || []).map((p) => p.Value || 0);
        const revLabels = (data.DailyRevenue || []).map((p) =>
            new Date(p.Date).toLocaleDateString()
        );
        const rev = (data.DailyRevenue || []).map((p) => p.Value || 0);

        ensureChart(
            "invoiceTrendsChart",
            "line",
            {
                labels,
                datasets: [{ label: "New Invoices", data: newInv, borderWidth: 2, fill: false, tension: 0.25 }],
            },
            { responsive: true, maintainAspectRatio: false }
        );

        ensureChart(
            "revenueChart",
            "line",
            {
                labels: revLabels,
                datasets: [{ label: "Revenue", data: rev, borderWidth: 2, fill: false, tension: 0.25 }],
            },
            { responsive: true, maintainAspectRatio: false }
        );

        ensureChart(
            "dailyRevenueChart",
            "bar",
            {
                labels: revLabels,
                datasets: [{ label: "Revenue", data: rev, borderWidth: 1 }],
            },
            { responsive: true, maintainAspectRatio: false }
        );
    };

    const updateApiUsage = (data) => {
        // Hourly chart
        const labels = (data.HourlyRequests || []).map((h) =>
            new Date(h.Hour).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
        );
        const values = (data.HourlyRequests || []).map((h) => h.Value || 0);

        ensureChart(
            "hourlyRequestsChart",
            "bar",
            {
                labels,
                datasets: [{ label: "API Requests", data: values, borderWidth: 1 }],
            },
            { responsive: true, maintainAspectRatio: false }
        );

        // Top API Keys table
        const keysBody = $("topApiKeys");
        keysBody.innerHTML = "";
        const keys = data.ApiKeyUsage || data.TopApiKeys || [];
        if (!keys.length) {
            keysBody.innerHTML = `<tr><td colspan="3" class="text-muted">No data</td></tr>`;
        } else {
            for (const row of keys) {
                const tr = document.createElement("tr");
                tr.innerHTML = `<td>${row.ClientName || row.Client || "-"}</td>
                        <td>${row.KeyId || row.KeyID || "-"}</td>
                        <td class="text-end">${row.Requests ?? row.Count ?? 0}</td>`;
                keysBody.appendChild(tr);
            }
        }

        // Top Endpoints table
        const epBody = $("topEndpoints");
        epBody.innerHTML = "";
        const eps = data.EndpointUsage || data.TopEndpoints || [];
        if (!eps.length) {
            epBody.innerHTML = `<tr><td colspan="3" class="text-muted">No data</td></tr>`;
        } else {
            for (const row of eps) {
                const tr = document.createElement("tr");
                tr.innerHTML = `<td>${row.Method || "-"}</td>
                        <td>${row.Endpoint || row.UrlPath || "-"}</td>
                        <td class="text-end">${row.Requests ?? row.Count ?? 0}</td>`;
                epBody.appendChild(tr);
            }
        }
    };

    // ------------------------------
    // Fetch + Cache + Degrade
    // ------------------------------
    const fetchData = async () => {
        hideStaleBanner();
        setBusy(true);

        try {
            await checkHealth();

            const [sumRes, custRes, invRes, apiRes] = await Promise.all([
                fetchJson(API.summary),
                fetchJson(API.customers),
                fetchJson(API.invoices),
                fetchJson(API.apiUsage),
            ]);

            // drive UI
            updateFromSummary(sumRes.json);
            updateCustomers(custRes.json);
            updateInvoices(invRes.json);
            updateApiUsage(apiRes.json);

            $("lastUpdated").textContent = fmtTs(sumRes.json.Timestamp || Date.now());

            // cache snapshot
            saveCache({
                summary: sumRes.json,
                customers: custRes.json,
                invoices: invRes.json,
                apiUsage: apiRes.json,
            });

            // if backend signals stale via header or payload, show banner
            const staleHeader = sumRes.headers.get("X-Data-Stale");
            const isStale =
                String(staleHeader || "").toLowerCase() === "true" ||
                !!sumRes.json.IsStale ||
                !!custRes.json.IsStale ||
                !!invRes.json.IsStale ||
                !!apiRes.json.IsStale;

            if (isStale) {
                showStaleBanner("Data may be out of date (serving last known good snapshot).");
            }
        } catch (err) {
            console.warn("Falling back to cache:", err?.message || err);

            const cached = loadCache();
            if (cached?.data) {
                const { summary, customers, invoices, apiUsage } = cached.data;
                updateFromSummary(summary);
                updateCustomers(customers);
                updateInvoices(invoices);
                updateApiUsage(apiUsage);
                showStaleBanner(`Showing cached data from ${fmtTs(cached.ts)} (offline or server unreachable).`);
                setHealthChip("degraded", "degraded");
            } else {
                alert("No data available and the server is unreachable.");
            }
        } finally {
            setBusy(false);
        }
    };

    // ------------------------------
    // UX helpers
    // ------------------------------
    const setBusy = (busy) => {
        const btn = $("refreshBtn");
        btn.disabled = !!busy;
        btn.innerHTML = busy
            ? `<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Refreshing...`
            : `<i class="bi bi-arrow-clockwise me-1"></i>Refresh Data`;
    };

    // Smooth-scroll nav links
    document.querySelectorAll('.nav a[href^="#"]').forEach((a) => {
        a.addEventListener("click", (e) => {
            const id = a.getAttribute("href");
            if (!id || id === "#") return;
            e.preventDefault();
            const el = document.querySelector(id);
            if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
        });
    });

    // Wire up refresh
    $("refreshBtn").addEventListener("click", fetchData);

    // Initial load
    fetchData();

    // Optional: auto-refresh every 5 minutes
    // setInterval(fetchData, 5 * 60 * 1000);
})();