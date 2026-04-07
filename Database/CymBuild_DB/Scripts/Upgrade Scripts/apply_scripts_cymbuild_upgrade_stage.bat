@echo off
setlocal enabledelayedexpansion

REM === CONFIGURATION SECTION ===

set SERVER=SOC-SQLDEVBRE01\General
set DATABASE=CymBuild_Upgrade_Stage

REM Set to "SQL" for SQL Authentication or "WINDOWS" for Windows Authentication
set AUTH_TYPE=WINDOWS

REM Only used if AUTH_TYPE is SQL
set USERNAME=your_username
set PASSWORD=your_password

REM Set the folder containing the .sql files
set SQL_FOLDER=.

REM =============================

cd /d "%SQL_FOLDER%"

REM Build sqlcmd auth params
if /i "%AUTH_TYPE%"=="SQL" (
    set AUTH_PARAMS=-U %USERNAME% -P %PASSWORD%
) else (
    set AUTH_PARAMS=-E
)

echo Ensuring script_history table exists...
sqlcmd -b -S %SERVER% -d %DATABASE% %AUTH_PARAMS% -Q "IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'script_history') BEGIN CREATE TABLE dbo.script_history (script_name NVARCHAR(255) NOT NULL PRIMARY KEY, executed_at DATETIME NOT NULL DEFAULT GETDATE()) END"
if errorlevel 1 (
    echo Failed to create or verify dbo.script_history. Stopping execution.
	pause
    exit /b 1
)

REM Run the Pre Deployment Scripts 
echo Running Pre Deployment Scripts
sqlcmd -S %SERVER% -d %DATABASE% %AUTH_PARAMS% -Q "EXEC SCore.PreDeploymentScript"
if errorlevel 1 (
    echo Failed to run Pre Deployment Script. Stopping execution.
	pause
    exit /b 1
)

REM Loop through sorted .sql files
for %%F in (*.sql) do (
    call :check_if_ran "%%F"
    if !already_ran! == 1 (
        echo Skipping already executed script: %%F
    ) else (
        echo Executing %%F...
        sqlcmd -b -S %SERVER% -d %DATABASE% %AUTH_PARAMS% -i "%%F"
        if errorlevel 1 (
            echo Failed to execute %%F. Stopping execution.
			pause
            exit /b 1
        )
        echo Logging execution of %%F to dbo.script_history...
        sqlcmd -S %SERVER% -d %DATABASE% %AUTH_PARAMS% -Q "INSERT INTO dbo.script_history (script_name, executed_at) VALUES ('%%F', GETDATE())"
    )
)

REM Run the Post Deployment Scripts 
echo Running Post Deployment Scripts
sqlcmd -S %SERVER% -d %DATABASE% %AUTH_PARAMS% -Q "EXEC SCore.PostDeploymentScript"
if errorlevel 1 (
    echo Failed to run Post Deployment Script. Stopping execution.
	pause
    exit /b 1
)

echo Script processing complete.
exit /b 0

REM === Function to check script_history ===
:check_if_ran
set "already_ran=0"
set "script_name=%~1"

REM echo Checking if %script_name% has already run . . . 

for /f %%R in ('sqlcmd -S %SERVER% -d %DATABASE% %AUTH_PARAMS% -h -1 -W -Q "IF EXISTS (SELECT 1 FROM dbo.script_history WHERE script_name = '%script_name%') SELECT 1 ELSE SELECT 0"') do (
    if %%R==1 set already_ran=1
)
exit /b
