@echo off
REM JSPlots Launcher Script for Windows
REM Tries browsers in order: Brave, Chrome, Firefox, then system default

set "HTML_FILE=%~dp0external_formats_examples.html"

REM Try Brave Browser
where brave.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Opening with Brave Browser...
    start brave.exe --allow-file-access-from-files "%HTML_FILE%"
    exit /b
)

REM Try Chrome
where chrome.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Opening with Google Chrome...
    start chrome.exe --allow-file-access-from-files "%HTML_FILE%"
    exit /b
)

REM Try Chrome in Program Files
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo Opening with Google Chrome...
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --allow-file-access-from-files "%HTML_FILE%"
    exit /b
)

REM Try Chrome in Program Files (x86)
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    echo Opening with Google Chrome...
    start "" "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --allow-file-access-from-files "%HTML_FILE%"
    exit /b
)

REM Try Firefox
where firefox.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Opening with Firefox...
    start firefox.exe "%HTML_FILE%"
    exit /b
)

REM Try Firefox in Program Files
if exist "C:\Program Files\Mozilla Firefox\firefox.exe" (
    echo Opening with Firefox...
    start "" "C:\Program Files\Mozilla Firefox\firefox.exe" "%HTML_FILE%"
    exit /b
)

REM Fallback to default browser
echo Opening with default browser...
start "" "%HTML_FILE%"
