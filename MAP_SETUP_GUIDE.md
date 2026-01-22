# Google Maps Setup Guide - Fix Map Not Showing

## Problem
The map is not displaying - showing only beige/gray background. Search is working but map tiles are not loading.

## Root Cause
The Maps SDK for Android requires specific API key configuration that's different from the Places API key.

## Solution - Configure Google Cloud Console

### Step 1: Enable Required APIs

Go to Google Cloud Console → APIs & Services → Library

Enable these APIs:
1. ✅ **Maps SDK for Android** (REQUIRED for map display)
2. ✅ **Places API** (for search autocomplete)
3. ✅ **Places API (New)** (recommended)
4. ✅ **Geocoding API** (for address lookups)
5. ✅ **Geolocation API** (optional)

### Step 2: Create/Configure Android API Key

**Current Key in AndroidManifest.xml:** `AIzaSyB3WtSmaLqOuAh-642QcTUI2TM3skK0i_U`

#### Configure this key:

1. Go to: **Google Cloud Console → APIs & Services → Credentials**

2. Find the key `AIzaSyB3WtSmaLqOuAh-642QcTUI2TM3skK0i_U` (or create new)

3. **Application restrictions:**
   - Select: ✅ **Android apps**
   - Add package name: `com.sylonowusr.app`
   - To get SHA-1 fingerprint:
     ```bash
     # Debug certificate (for development)
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

     # Release certificate (for production)
     keytool -list -v -keystore path/to/your/release.keystore -alias your-key-alias
     ```
   - Add the SHA-1 fingerprint from above

4. **API restrictions:**
   - Select: ✅ **Restrict key**
   - Select these APIs:
     - ✅ Maps SDK for Android
     - ✅ Places API
     - ✅ Places API (New)
     - ✅ Geocoding API

5. Click **Save**

### Step 3: Verify Current Setup

Current configuration in code:

**AndroidManifest.xml** (line 16-17):
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyB3WtSmaLqOuAh-642QcTUI2TM3skK0i_U"/>
```

**Package Name:** `com.sylonowusr.app`

### Step 4: Test Map Display

After configuring:

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Check logs:**
   - Look for map creation logs
   - Check for any API key errors

3. **If still not working:**
   - Wait 5-10 minutes for Google's servers to propagate changes
   - Verify billing is enabled on Google Cloud Project
   - Check API quotas haven't been exceeded

## Common Issues

### Issue 1: "API key not valid" error
**Solution:** Ensure SHA-1 fingerprint matches exactly and package name is correct

### Issue 2: Map shows gray tiles
**Solution:** Enable "Maps SDK for Android" API (not just "Maps JavaScript API")

### Issue 3: Search works but map doesn't show
**Solution:** You have two different keys - one for Places (HTTP), one for Maps (Android SDK). Make sure the Android SDK key is properly configured.

## Two API Keys Explanation

Your app uses **TWO different API keys**:

1. **Maps SDK Key** (`AIzaSyB3WtSmaLqOuAh-642QcTUI2TM3skK0i_U`)
   - Location: AndroidManifest.xml
   - Purpose: Display map tiles
   - Restrictions: Android apps only
   - Required APIs: Maps SDK for Android

2. **Places API Key** (`AIzaSyCHo3CugNRhyKluhdiSXjYRff0t-hfJUvQ`)
   - Location: location_picker_screen.dart (line 41)
   - Purpose: Search autocomplete
   - Restrictions: HTTP referrers or None
   - Required APIs: Places API, Geocoding API

## Quick Fix Checklist

- [ ] Maps SDK for Android is enabled
- [ ] API key has Android app restrictions
- [ ] Package name is `com.sylonowusr.app`
- [ ] SHA-1 fingerprint is added
- [ ] API restrictions include "Maps SDK for Android"
- [ ] Billing is enabled on Google Cloud Project
- [ ] Waited 5-10 minutes after making changes
- [ ] Ran `flutter clean && flutter pub get && flutter run`

## Testing Commands

```bash
# Check if SHA-1 is correct
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1

# Clean rebuild
flutter clean
flutter pub get
flutter run --verbose

# Check for errors in logs
adb logcat | grep -i "maps\|api"
```
