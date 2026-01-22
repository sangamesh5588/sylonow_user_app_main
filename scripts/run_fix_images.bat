@echo off
echo ========================================
echo Theater Screen Image Converter
echo ========================================
echo.
echo This script will:
echo 1. Find theater screens with base64-encoded images
echo 2. Convert them to proper image files
echo 3. Upload to Supabase Storage
echo 4. Update database with image URLs
echo.
echo Press Ctrl+C to cancel, or
pause

cd /d "%~dp0.."
dart run lib/scripts/fix_theater_screen_images.dart

echo.
echo ========================================
echo Script completed!
echo ========================================
pause
