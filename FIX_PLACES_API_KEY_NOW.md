# URGENT: Fix Places API Key - Step by Step Guide

## Current Problem

The API key `AIzaSyDGQShvfon0olSlQIRJy8F8ION3rWQG-tQ` is **STILL RESTRICTED** despite being labeled as "unrestricted".

When I tested it with curl, I got:
```
"error_message": "This IP, site or mobile application is not authorized to use this API key"
"status": "REQUEST_DENIED"
```

## Why This Happens

Your key still has **application restrictions** that prevent HTTP requests. The `google_places_flutter` package makes HTTP REST API calls, which cannot work with app-restricted keys.

---

## ✅ SOLUTION: Follow These Exact Steps

### Step 1: Go to Google Cloud Console

1. Open: https://console.cloud.google.com/apis/credentials
2. Find the key: `AIzaSyDGQShvfon0olSlQIRJy8F8ION3rWQG-tQ`
3. Click on it to edit

### Step 2: Check Application Restrictions

**Look at "Application restrictions" section:**

❌ **WRONG Configuration** (Current):
```
Application restrictions: iOS apps
  or
Application restrictions: Android apps
```

✅ **CORRECT Configuration** (What you need):
```
Application restrictions: None
```

**ACTION:** Select **"None"** for Application restrictions

### Step 3: Set API Restrictions

**Look at "API restrictions" section:**

✅ **CORRECT Configuration:**
- Select: "Restrict key"
- Check ONLY these APIs:
  - ✅ Places API
  - ✅ Places API (New)
  - ✅ Geocoding API

**Do NOT select:**
- ❌ Maps SDK for Android (use separate key for this)
- ❌ Maps SDK for iOS (use separate key for this)

### Step 4: Save and Wait

1. Click **"Save"** button
2. **Wait 5-10 minutes** for changes to propagate across Google's servers
3. Do NOT test immediately

### Step 5: Test the Key

After 10 minutes, test with this command:

```bash
curl -s "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Mumbai&key=AIzaSyDGQShvfon0olSlQIRJy8F8ION3rWQG-tQ"
```

**Expected SUCCESS Response:**
```json
{
  "predictions": [
    {
      "description": "Mumbai, Maharashtra, India",
      "place_id": "ChIJwe1EZjDG5zsRaYxkjY_tpF0",
      ...
    }
  ],
  "status": "OK"
}
```

**If you still get error:** The key configuration didn't save properly. Try creating a NEW key.

---

## 🔐 Alternative: Create Completely New Key

If the above doesn't work, create a fresh key:

### Step 1: Create New API Key

1. Go to: https://console.cloud.google.com/apis/credentials
2. Click: **"+ CREATE CREDENTIALS"** → **"API Key"**
3. Copy the new key immediately

### Step 2: Configure the New Key

1. Click on the newly created key
2. **Name:** "Places Autocomplete - Unrestricted"
3. **Application restrictions:** Select **"None"**
4. **API restrictions:** Select **"Restrict key"**
5. Check these APIs:
   - ✅ Places API
   - ✅ Places API (New)
   - ✅ Geocoding API
6. Click **"Save"**

### Step 3: Update Your Code

Replace the key in your Flutter code:

```dart
// lib/features/address/screens/location_picker_screen.dart
// Line 38
static const String _googleApiKey = 'YOUR_BRAND_NEW_KEY_HERE';
```

### Step 4: Wait and Test

1. Wait **10 minutes**
2. Run: `flutter clean && flutter pub get`
3. Run the app and test location search

---

## 🎯 Summary of What You Need

### Three Separate API Keys for Production:

| Purpose | Key Type | Restrictions | Where Used |
|---------|----------|--------------|------------|
| **Android Maps** | Android-restricted | Android apps only | AndroidManifest.xml |
| **iOS Maps** | iOS-restricted | iOS apps only | AppDelegate.swift |
| **Places Autocomplete** | **Unrestricted** | None (with API limits) | location_picker_screen.dart |

### Current Setup:

✅ **Android Maps:** `AIzaSyB3WtSmaLqOuAh-642QcTUI2TM3skK0i_U` (Working)
✅ **iOS Maps:** `AIzaSyD4Lbd1wwEpEOB1pBHLB8mWEDJ4MHpiDW8` (Working)
❌ **Places Autocomplete:** `AIzaSyDGQShvfon0olSlQIRJy8F8ION3rWQG-tQ` (NOT WORKING - Still restricted)

---

## 🚨 Common Mistakes to Avoid

1. **Don't use iOS/Android restricted keys for Places Autocomplete**
   - They will NEVER work for HTTP API calls

2. **Don't select "Android apps" or "iOS apps" for Places key**
   - Must be "None" or "HTTP referrers"

3. **Don't test immediately after saving**
   - Wait at least 5-10 minutes for changes to propagate

4. **Don't skip API restrictions**
   - Leaving it completely unrestricted with no API limits is dangerous

---

## 🔍 Verification Checklist

Before you tell me "it's working":

- [ ] I went to Google Cloud Console
- [ ] I found the key `AIzaSyDGQShvfon0olSlQIRJy8F8ION3rWQG-tQ`
- [ ] I set "Application restrictions" to **"None"**
- [ ] I set "API restrictions" to include Places API, Places API (New), Geocoding API
- [ ] I clicked "Save"
- [ ] I waited 10 minutes
- [ ] I tested with curl command and got "status": "OK"
- [ ] I ran `flutter clean && flutter pub get`
- [ ] I tested in the app and search autocomplete works

---

## 💡 Security Note

**Is an unrestricted key safe?**

For development: YES, if you:
- ✅ Set daily quotas (Google Cloud Console → Quotas)
- ✅ Monitor usage (Google Cloud Console → APIs & Services → Dashboard)
- ✅ Set billing alerts

For production: Consider:
- Backend proxy (most secure)
- HTTP referrer restrictions (if you have a web version)
- Rotate keys periodically

---

## 📞 Next Steps

1. **Right now:** Fix the key in Google Cloud Console (follow Step 1-5 above)
2. **Wait 10 minutes**
3. **Test with curl**
4. **If successful:** Test in the app
5. **If still failing:** Create a brand new key (Alternative method above)

---

## 🎉 Expected Result

Once the key is properly unrestricted, your location search will:
- ✅ Show autocomplete suggestions as you type
- ✅ Display places like "Mumbai, Maharashtra, India"
- ✅ Allow selecting locations from search results
- ✅ Auto-populate address fields

**The Maps display already works - only search is broken due to this API key restriction issue.**

---

**Created:** $(date)
**Status:** ⏳ Waiting for you to fix the API key configuration in Google Cloud Console
