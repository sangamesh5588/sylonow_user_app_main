# Create Android Release Keystore

## Step 1: Create the Keystore

Run this command in your terminal (from the android folder):

```bash
cd "c:\Users\msi\Downloads\sylonow-user-app-main\sylonow-user-app-main\android"

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

When prompted, enter:
- **Keystore password:** `SylonowUploadKey!2025` (as configured in key.properties)
- **Key password:** `SylonowUploadKey!2025` (same as above)
- **First and last name:** Sylonow
- **Organization:** Sylonow
- **City/Locality:** Bangalore
- **State/Province:** Karnataka
- **Country code:** IN

## Step 2: Get Release SHA-1 Fingerprint

After creating the keystore, run this command:

```bash
cd c:\Users\msi\Downloads\sylonow-user-app-main\sylonow-user-app-main\android
keytool -list -v -keystore upload-keystore.jks -alias upload
```

When prompted, enter password: `SylonowUploadKey!2025`

Look for the **SHA1:** line and copy that fingerprint.

## Step 3: Create the Release Keystore

Run this command in the `android` directory:

```bash
cd c:\Users\msi\Downloads\sylonow-user-app-main\sylonow-user-app-main\android

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

When prompted, use these values:
- **Keystore password:** `SylonowUploadKey!2025`
- **Key password:** `SylonowUploadKey!2025`
- **First and Last Name:** Sylonow
- **Organizational Unit:** Development
- **Organization:** Sylonow
- **City:** [Your city]
- **State:** [Your state]
- **Country Code:** IN

Would you like me to create a script to generate the keystore automatically with these details?