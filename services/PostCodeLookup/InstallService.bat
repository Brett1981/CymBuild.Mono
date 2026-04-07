@echo off
REM --------------------------------------------------------
REM Install PostCodeLookup as a Windows Service
REM --------------------------------------------------------

sc create PostCodeLookupAPI ^
    binPath="C:\Program Files\PostCodeLookup\PostCodeLookup.exe" ^
    DisplayName="PostCodeLookup API Service" ^
    start=auto ^
    obj="LocalSystem"

if ERRORLEVEL 1 (
    echo Failed to create service.
) else (
    echo Service PostCodeLookup created successfully.
)

pause