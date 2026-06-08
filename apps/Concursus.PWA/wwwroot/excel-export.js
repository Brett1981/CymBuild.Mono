window.cymBuildV2 = window.cymBuildV2 || {};

window.cymBuildV2.exportTreeGridToExcel = function (fileName, sheetName, columns, rows) {
    const escapeHtml = function (value) {
        return String(value ?? "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#039;");
    };

    let html = `
                <html>
                <head>
                    <meta charset="utf-8" />
                    <style>
                        table { border-collapse: collapse; font-family: Arial, sans-serif; font-size: 12px; }
                        th { background: #eef6ff; font-weight: bold; border: 1px solid #cbd5e1; padding: 6px; }
                        td { border: 1px solid #e2e8f0; padding: 6px; }
                        .group { background: #dbeafe; font-weight: bold; }
                        .group-level-1 { background: #fef3c7; font-weight: bold; }
                        .group-level-2 { background: #eef6ff; font-weight: bold; }
                    </style>
                </head>
                <body>
                    <table>
                        <thead>
                            <tr>${columns.map(c => `<th>${escapeHtml(c.title)}</th>`).join("")}</tr>
                        </thead>
                        <tbody>
            `;

    for (const row of rows) {
        if (row.isGroup) {
            const className = row.level === 0 ? "group" : row.level === 1 ? "group-level-1" : "group-level-2";
            html += `<tr class="${className}"><td colspan="${columns.length}">${"&nbsp;".repeat(row.level * 6)}${escapeHtml(row.groupText)}</td></tr>`;
            continue;
        }

        html += "<tr>";
        for (const column of columns) {
            html += `<td>${escapeHtml(row.values[column.key])}</td>`;
        }
        html += "</tr>";
    }

    html += `
                        </tbody>
                    </table>
                </body>
                </html>
            `;

    const blob = new Blob(["\ufeff", html], {
        type: "application/vnd.ms-excel;charset=utf-8;"
    });

    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);

    link.href = url;
    link.download = fileName || "CymBuild_Export.xls";
    document.body.appendChild(link);
    link.click();

    document.body.removeChild(link);
    URL.revokeObjectURL(url);
};