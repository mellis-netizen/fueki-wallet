# GitHub Secrets Setup Guide

## Overview

This guide provides step-by-step instructions for setting up all required GitHub Secrets for the CI/CD pipeline.

## Required Secrets by Platform

### iOS Secrets

#### 1. App Store Connect API Key

**APP_STORE_CONNECT_API_KEY_ID**
- Navigate to App Store Connect → Users and Access → Keys
- Create a new API Key (or use existing)
- Copy the Key ID (format: XXXXXXXXXX)

**APP_STORE_CONNECT_ISSUER_ID**
- Found on the same Keys page
- Copy the Issuer ID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)

**APP_STORE_CONNECT_API_KEY_BASE64**
- Download the `.p8` file from App Store Connect
- Convert to base64:
  ```bash
  cat AuthKey_XXXXXXXXXX.p8 | base64
  ```
- Copy the entire base64 string

#### 2. Code Signing Certificates

**CERTIFICATES_P12_BASE64**
- Export your distribution certificate from Keychain Access
- File → Export Items → Choose .p12 format
- Set a password when prompted
- Convert to base64:
  ```bash
  cat Certificates.p12 | base64
  ```

**CERTIFICATES_PASSWORD**
- The password you set when exporting the .p12 file

#### 3. Provisioning Profiles

**PROVISIONING_PROFILE_BASE64**
- Download provisioning profile from Apple Developer Portal
- Or find in `~/Library/MobileDevice/Provisioning Profiles/`
- Convert to base64:
  ```bash
  cat YourProfile.mobileprovision | base64
  ```

**PROVISIONING_PROFILE_NAME**
- The name of your provisioning profile
- Example: "match AppStore com.fueki.wallet"

#### 4. Team and Bundle Information

**DEVELOPMENT_TEAM_ID**
- Your Apple Team ID (10 characters)
- Found in Apple Developer Portal → Membership

**BUNDLE_IDENTIFIER**
- Your app's bundle identifier
- Example: com.fueki.wallet

### Android Secrets

#### 1. Signing Key

**ANDROID_KEYSTORE_BASE64**
- Your release keystore file
- Convert to base64:
  ```bash
  cat release.keystore | base64
  ```

**ANDROID_KEY_ALIAS**
- The alias used when creating the keystore
- Example: release-key

**ANDROID_KEY_PASSWORD**
- Password for the key entry

**ANDROID_STORE_PASSWORD**
- Password for the keystore file

#### 2. Play Store Service Account

**PLAY_STORE_SERVICE_ACCOUNT_JSON**
- Create service account in Google Cloud Console:
  1. Go to IAM & Admin → Service Accounts
  2. Create new service account
  3. Download JSON key file
- Convert to base64 or paste JSON content directly

### General Secrets

#### Code Coverage

**CODECOV_TOKEN**
- Sign up at codecov.io
- Add your repository
- Copy the upload token

#### Security Scanning

**SNYK_TOKEN**
- Sign up at snyk.io
- Go to Account Settings
- Copy your API token

## Setting Up Secrets in GitHub

### Via GitHub Web Interface

1. Navigate to your repository
2. Go to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Enter the secret name and value
5. Click "Add secret"

### Via GitHub CLI

```bash
# Set a secret
gh secret set SECRET_NAME

# Set from file
gh secret set SECRET_NAME < secret-file.txt

# Set from base64 encoded file
cat file.p12 | base64 | gh secret set CERTIFICATES_P12_BASE64
```

## iOS Setup Detailed Steps

### Step 1: Create App Store Connect API Key

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to Users and Access
3. Click on Keys tab
4. Click the + button to create a new key
5. Give it a name (e.g., "GitHub Actions CI")
6. Select "App Manager" access
7. Click "Generate"
8. Download the `.p8` file (you can only download it once!)
9. Note the Key ID and Issuer ID

Set these secrets:
```bash
gh secret set APP_STORE_CONNECT_API_KEY_ID
# Paste Key ID when prompted

gh secret set APP_STORE_CONNECT_ISSUER_ID
# Paste Issuer ID when prompted

cat AuthKey_XXXXXXXXXX.p8 | base64 | gh secret set APP_STORE_CONNECT_API_KEY_BASE64
```

### Step 2: Export Distribution Certificate

1. Open Keychain Access on your Mac
2. Select "My Certificates" from the left sidebar
3. Find your "Apple Distribution" certificate
4. Right-click → Export
5. Choose .p12 format
6. Set a strong password
7. Save as `Certificates.p12`

Set these secrets:
```bash
cat Certificates.p12 | base64 | gh secret set CERTIFICATES_P12_BASE64

gh secret set CERTIFICATES_PASSWORD
# Enter the password you set
```

### Step 3: Export Provisioning Profile

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Profiles
3. Find your App Store distribution profile
4. Download it
5. Rename to something simple like `AppStore.mobileprovision`

Set these secrets:
```bash
cat AppStore.mobileprovision | base64 | gh secret set PROVISIONING_PROFILE_BASE64

gh secret set PROVISIONING_PROFILE_NAME
# Enter: "App Store Profile" or your profile name
```

### Step 4: Set Team Information

```bash
gh secret set DEVELOPMENT_TEAM_ID
# Enter your 10-character Team ID

gh secret set BUNDLE_IDENTIFIER
# Enter: com.fueki.wallet
```

## Android Setup Detailed Steps

### Step 1: Generate Release Keystore (First Time Only)

If you don't have a keystore yet:

```bash
keytool -genkey -v -keystore release.keystore -alias release-key \
  -keyalg RSA -keysize 2048 -validity 10000

# Answer the prompts and remember your passwords!
```

### Step 2: Set Keystore Secrets

```bash
cat release.keystore | base64 | gh secret set ANDROID_KEYSTORE_BASE64

gh secret set ANDROID_KEY_ALIAS
# Enter: release-key (or your alias)

gh secret set ANDROID_KEY_PASSWORD
# Enter your key password

gh secret set ANDROID_STORE_PASSWORD
# Enter your keystore password
```

### Step 3: Create Play Console Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select or create a project
3. Enable Google Play Android Developer API
4. Go to IAM & Admin → Service Accounts
5. Click "Create Service Account"
6. Name it "GitHub Actions Deploy"
7. Click "Create and Continue"
8. Skip granting access (for now)
9. Click "Done"
10. Click on the service account
11. Go to Keys tab
12. Add Key → Create new key → JSON
13. Download the JSON file

Link to Play Console:
1. Go to [Play Console](https://play.google.com/console)
2. Select your app
3. Go to Setup → API access
4. Click "Link" on your service account
5. Grant "Release to testing tracks" permission

Set secret:
```bash
cat service-account-key.json | gh secret set PLAY_STORE_SERVICE_ACCOUNT_JSON
```

## Verification

### Verify iOS Secrets

```bash
# List all secrets (won't show values)
gh secret list

# Run TestFlight workflow manually to test
gh workflow run testflight.yml
```

### Verify Android Secrets

```bash
# Run Play Store workflow manually to test
gh workflow run play-store.yml -f track=internal
```

### Test Locally (Partially)

Create a `.env` file locally to test scripts:

```bash
# .env.test (DO NOT COMMIT)
export APP_STORE_CONNECT_API_KEY_ID="XXXXXXXXXX"
export APP_STORE_CONNECT_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ANDROID_KEY_ALIAS="release-key"
# ... etc

# Source it
source .env.test

# Run local build test
./scripts/deployment/deploy-testflight.sh --skip-upload
```

## Security Best Practices

1. **Never Commit Secrets**
   - Add to `.gitignore`: `*.p12`, `*.mobileprovision`, `*.keystore`, `*.json`
   - Use environment variables
   - Use GitHub Secrets

2. **Rotate Regularly**
   - API keys: Every 90 days
   - Certificates: Before expiration
   - Service accounts: Quarterly

3. **Limit Access**
   - Only give CI/CD minimum required permissions
   - Use separate accounts for production
   - Enable 2FA on all accounts

4. **Backup Safely**
   - Encrypt keystores before backing up
   - Use password managers
   - Store recovery codes securely

5. **Monitor Usage**
   - Review GitHub Actions logs
   - Check App Store Connect activity
   - Monitor Play Console API usage

## Troubleshooting

### Secret Not Working

1. Check for typos in secret names
2. Verify base64 encoding is correct
3. Ensure no extra whitespace or newlines
4. Try re-creating the secret

### Certificate Expired

1. Generate new certificate
2. Update provisioning profile
3. Re-export and update secrets

### Service Account No Permission

1. Check Play Console API access
2. Verify role assignments
3. Re-link service account
4. Wait 24 hours for propagation

## Support

For issues with secret setup:
1. Check workflow logs for specific errors
2. Review this guide carefully
3. Contact team lead for assistance
4. Open GitHub issue with redacted logs

---

**Remember**: Treat these secrets like passwords. Never share them publicly or commit them to version control!
