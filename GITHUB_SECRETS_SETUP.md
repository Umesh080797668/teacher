# GitHub Secrets Setup for Automatic APK Signing

## ⚠️ IMPORTANT
Your workflow is now configured to automatically sign APKs, but you need to add the signing credentials as GitHub Secrets.

## 📋 Steps to Add Secrets

### 1. Go to Your GitHub Repository Settings
1. Open https://github.com/Umesh080797668/teacher
2. Click on **Settings** (top menu)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**

### 2. Add KEYSTORE_BASE64 Secret

**Name:** `KEYSTORE_BASE64`

**Value:** (Copy the entire content from the file below)
```
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
```

**Steps:**
1. Click **New repository secret**
2. Name: `KEYSTORE_BASE64`
3. Paste the entire base64 string above (it's very long, make sure you copy all of it)
4. Click **Add secret**

### 3. Add KEY_PROPERTIES Secret

**Name:** `KEY_PROPERTIES`

**Value:**
```
storePassword=android123
keyPassword=android123
keyAlias=upload
storeFile=upload-keystore.jks
```

**Steps:**
1. Click **New repository secret** again
2. Name: `KEY_PROPERTIES`
3. Paste the 4 lines above exactly as shown
4. Click **Add secret**

**Important:** The `storeFile` path is relative to the `android/app` folder. The workflow places the keystore at `android/app/upload-keystore.jks`.

## ✅ Verification

After adding both secrets:
1. Go to **Actions** tab in your repository
2. Create a new release (tag: `1.0.20`)
3. The workflow should now build a **signed APK** automatically
4. Users will be able to download and install it from the app

## 🔒 Security Notes

- ✅ Secrets are encrypted and never exposed in logs
- ✅ Only GitHub Actions can access these secrets
- ✅ The keystore is decoded during build and immediately discarded
- ⚠️ Never commit the actual keystore file or key.properties to the repository
- ⚠️ Delete the `keystore_base64.txt` file after setting up secrets

## 📝 After Setup

Once secrets are added, delete the temporary file:
```bash
cd android
rm keystore_base64.txt
```

Then you're ready to create the v1.0.20 release!
