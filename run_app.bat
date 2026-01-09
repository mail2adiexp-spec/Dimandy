@echo off
REM Set JAVA_HOME to correct JDK path
set JAVA_HOME=C:\Program Files\Java\jdk-17
set PATH=%JAVA_HOME%\bin;%PATH%

echo ========================================
echo   Bong Bazar - Flutter App Runner
echo ========================================
echo.
echo JAVA_HOME set to: %JAVA_HOME%
echo.

REM Navigate to project directory
cd /d %~dp0

echo Checking connected devices...
flutter devices
echo.

echo Select an option to run the app:
echo 1. Run on a connected Android device
echo 2. Run on Chrome (Web)
echo 3. Check Flutter Doctor

echo.
set /p choice="Enter choice (1/2/3): "

if "%choice%"=="1" (
    echo.
    set /p deviceId="Enter the device ID from the list above (e.g., R5CR8123XYZ): "
    if defined deviceId (
        echo.
        echo Running on Android device: %deviceId%
        flutter run -d %deviceId%
    ) else (
        echo.
        echo No device ID entered. Running on default device.
        flutter run
    )
) else if "%choice%"=="2" (
    echo.
    echo Running on Chrome...
    flutter run -d chrome
) else if "%choice%"=="3" (
    echo.
    flutter doctor -v
    pause
) else (
    echo Invalid choice!
    pause
)
