@echo off
setlocal EnableDelayedExpansion

echo.
echo ==========================================
echo   Remove a word from all filenames
echo ==========================================
echo.

set /p "word=Enter the word to remove from filenames: "

if "%word%"=="" (
    echo.
    echo No word entered. Aborting.
    goto :EOF
)

echo.
echo Current folder:
cd
echo.
echo Looking for files matching: *%word%*
echo.

set "count=0"

:: PREVIEW PASS
for %%f in (*%word%*) do (
    set /a count+=1
    set "oldname=%%f"
    set "newname=%%f"
    set "newname=!newname:%word%=!"

    echo !count!. "!oldname!"  ^>  "!newname!"
)

if %count%==0 (
    echo.
    echo No files matched the pattern *%word%* in this folder.
    echo.
    pause
    goto :EOF
)

echo.
echo ==========================================
echo Total files that contain "%word%": %count%
echo ==========================================
echo.

choice /M "Do you want to rename these files now"
if errorlevel 2 (
    echo.
    echo Rename cancelled.
    echo.
    pause
    goto :EOF
)

echo.
echo Renaming files...
echo.

:: RENAME PASS
for %%f in (*%word%*) do (
    set "newname=%%f"
    set "newname=!newname:%word%=!"
    echo REN: "%%f"  ^>  "!newname!"
    ren "%%f" "!newname!"
)

echo.
echo Done.
echo.
pause
