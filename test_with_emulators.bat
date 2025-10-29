@echo off
REM Script to run Flutter tests with Firebase Emulators

echo ========================================
echo Starting Firebase Emulators...
echo ========================================
start /B firebase emulators:start --only firestore,auth

REM Wait for emulators to start
echo Waiting for emulators to initialize...
timeout /t 5 /nobreak >nul

echo.
echo ========================================
echo Running Flutter Tests...
echo ========================================
flutter test

echo.
echo ========================================
echo Stopping Firebase Emulators...
echo ========================================
REM Kill the firebase emulators process
taskkill /F /IM java.exe /FI "WINDOWTITLE eq Firebase*" 2>nul

echo.
echo Done!
pause
