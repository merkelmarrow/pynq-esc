@echo off
setlocal

REM ====== CONFIG ======
set "HOST=xilinx@pynq"
set "SRC=/home/xilinx/jupyter_notebooks/esc"
set "DEST=C:\Development\Projects\pynq-esc\pynq-esc\pynq"
REM SSH options: auto-accept first-time host key, short timeout
set "SSHOPTS=-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
REM =====================

REM Check if the tools exist
where ssh >nul 2>&1 || (echo ERROR: ssh.exe not found. Install "OpenSSH Client". & exit /b 1)
where scp >nul 2>&1 || (echo ERROR: scp.exe not found. Install "OpenSSH Client". & exit /b 1)

echo Checking access to %HOST%:%SRC% ...
ssh %SSHOPTS% %HOST% "test -d '%SRC%'" >nul 2>&1
if errorlevel 1 (
  echo.
  echo ERROR: Cannot access "%SRC%" on %HOST%.
  echo - Check the host/IP (e.g. 'pynq'), username, or path.
  echo - Make sure the board is up and reachable.
  exit /b 1
)

echo.
echo Source:      %HOST%:%SRC%/
echo Destination: "%DEST%"
echo.
choice /C YN /M "Proceed? This will DELETE ALL CURRENT CONTENTS of the destination before copying"
if errorlevel 2 (
  echo Aborted by user.
  exit /b 0
)

REM Create destination if missing
if not exist "%DEST%" (
  echo Creating "%DEST%"...
  mkdir "%DEST%" || (echo ERROR: Could not create "%DEST%". & exit /b 1)
)

REM Safety guard: refuse to wipe a drive root like C:\
for %%I in ("%DEST%") do (
  set "DESTDRIVE=%%~dI"
  set "DESTPATH=%%~pI"
)
if "%DESTPATH%"=="\" (
  echo ERROR: Destination is a drive root (%DEST%). Refusing to delete its contents.
  exit /b 1
)

echo.
echo Deleting existing contents of "%DEST%"...
del /q /f /s "%DEST%\*" >nul 2>&1
for /d %%D in ("%DEST%\*") do rd /s /q "%%D"

echo.
echo Copying
scp -r -p %HOST%:%SRC%/. "%DEST%"
if errorlevel 1 (
  echo.
  echo ERROR: Copy failed.
  exit /b 1
)

echo.
echo Done. Files copied to "%DEST%".
exit /b 0
