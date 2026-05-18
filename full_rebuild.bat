@echo off
echo Starting full clean and rebuild process...

echo Stopping any stuck dart processes...
taskkill /f /im dart.exe >nul 2>&1

echo Running flutter clean...
call flutter clean

echo Force removing build and android\.gradle directories...
rmdir /s /q .\build >nul 2>&1
rmdir /s /q .\android\.gradle >nul 2>&1

echo Running flutter pub get...
call flutter pub get

echo All done! You can now run your app from Android Studio or VS Code.
