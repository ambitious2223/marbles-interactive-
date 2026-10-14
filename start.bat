@echo off
REM Marble Royale launcher for the Tikora hub.
REM Tikora injects TIKORA_RELAY_URL / TIKORA_GAME_SLUG / TIKORA_GAME_KEY into this process.
setlocal enabledelayedexpansion
cd /d "%~dp0"

REM 1) Prefer a built/exported game next to this file.
if exist "build\windows\MarbleRoyale.exe" (
  start "" "build\windows\MarbleRoyale.exe" %*
  goto :eof
)
if exist "MarbleRoyale.exe" (
  start "" "MarbleRoyale.exe" %*
  goto :eof
)

REM 2) Dev fallback: run the project in the Godot editor/runtime.
if defined GODOT (
  start "" "%GODOT%" --path "%~dp0." %*
  goto :eof
)
where godot >nul 2>nul
if %errorlevel%==0 (
  start "" godot --path "%~dp0." %*
  goto :eof
)

REM 3) Auto-detect a Godot .NET build (WinGet package, then common install dirs).
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.*") do (
  for /f "delims=" %%G in ('dir /b /s "%%~D\Godot_v*_mono_win64.exe" 2^>nul') do set "GODOT=%%G"
)
if not defined GODOT (
  for %%R in ("%LOCALAPPDATA%\Programs\Godot" "%ProgramFiles%\Godot" "C:\Godot") do (
    for /f "delims=" %%G in ('dir /b /s "%%~R\Godot_v*_mono_win64.exe" 2^>nul') do set "GODOT=%%G"
  )
)
if defined GODOT (
  echo Starting Marble Royale with "!GODOT!"
  start "" "!GODOT!" --path "%~dp0." %*
  goto :eof
)

echo Marble Royale: no built game and no Godot found.
echo Set the GODOT env var to your Godot .NET executable, or export the game.
echo Expected something like:
echo   %%LOCALAPPDATA%%\Microsoft\WinGet\Packages\GodotEngine.*\Godot_v*_mono_win64\Godot_v*_mono_win64.exe
pause
