function downloadFile(fileName, content) {
    var a = document.createElement("a");
    a.href = content;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
}