# Installation Guide - Best Bike Paths (BBP)

This comprehensive guide provides detailed instructions for setting up and running the Best Bike Paths application on Windows, macOS, and Linux.

---

## Table of Contents

1. [Prerequisites Overview](#1-prerequisites-overview)
2. [Platform-Specific Installation](#2-platform-specific-installation)
3. [Project Setup](#3-project-setup)
4. [Firebase Configuration](#4-firebase-configuration)
5. [Google Maps API Setup](#5-google-maps-api-setup)
6. [OpenWeatherMap API Setup](#6-openweathermap-api-setup)
7. [Running the Application](#7-running-the-application)
8. [Running Tests](#8-running-tests)
9. [Building for Production](#9-building-for-production)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites Overview

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Flutter SDK | ≥3.0.0 <4.0.0 | Cross-platform framework |
| Dart SDK | ≥3.0.0 | Programming language (bundled with Flutter) |
| Git | Latest | Version control |
| Android Studio | Latest | Android development & emulator |
| Xcode | 14+ | iOS development (macOS only) |
| VS Code | Latest | Recommended IDE (optional) |

### Required Accounts

| Service | Purpose | URL |
|---------|---------|-----|
| Google Account | Firebase & Google Cloud access | [accounts.google.com](https://accounts.google.com) |
| Firebase | Backend services | [console.firebase.google.com](https://console.firebase.google.com) |
| Google Cloud | Maps & Directions API | [console.cloud.google.com](https://console.cloud.google.com) |
| OpenWeatherMap | Weather API | [openweathermap.org](https://openweathermap.org/api) |

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| Storage | 10 GB free | 20 GB free |
| CPU | Dual-core | Quad-core |
| Android Device/Emulator | API 21+ (Android 5.0) | API 30+ (Android 11) |
| iOS Device/Simulator | iOS 12+ | iOS 16+ |

---

## 2. Platform-Specific Installation

### 2.1 Windows Installation

#### Step 1: Install Git

```powershell
# Option A: Download from https://git-scm.com/download/win
# Option B: Using winget
winget install Git.Git
```

#### Step 2: Install Flutter SDK

1. Download Flutter SDK from [flutter.dev/docs/get-started/install/windows](https://flutter.dev/docs/get-started/install/windows)

2. Extract to `C:\src\flutter` (avoid paths with spaces or special characters)

3. Add Flutter to PATH:
   ```powershell
   # Add to System Environment Variables
   # Path: C:\src\flutter\bin
   
   # Or run in PowerShell (temporary)
   $env:Path += ";C:\src\flutter\bin"
   ```

4. Verify installation:
   ```powershell
   flutter --version
   flutter doctor
   ```

#### Step 3: Install Android Studio

1. Download from [developer.android.com/studio](https://developer.android.com/studio)

2. During installation, ensure the following are selected:
   - Android SDK
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android Emulator

3. After installation, open Android Studio and complete initial setup

4. Install Flutter & Dart plugins:
   - File → Settings → Plugins
   - Search "Flutter" and install
   - Search "Dart" and install

5. Configure Android SDK path:
   ```powershell
   flutter config --android-sdk "C:\Users\<USERNAME>\AppData\Local\Android\Sdk"
   ```

#### Step 4: Create Android Emulator

1. Open Android Studio → Tools → Device Manager
2. Click "Create Device"
3. Select "Pixel 6" or similar
4. Select "API 33" or latest available
5. Click "Finish"

#### Step 5: Accept Android Licenses

```powershell
flutter doctor --android-licenses
# Press 'y' to accept all licenses
```

#### Step 6: Verify Setup

```powershell
flutter doctor -v
```

Expected output (all checkmarks):
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Windows Version
[✓] Android toolchain
[✓] Android Studio
[✓] VS Code (optional)
[✓] Connected device
```

---

### 2.2 macOS Installation

#### Step 1: Install Xcode

```bash
# Install from Mac App Store or:
xcode-select --install
```

#### Step 2: Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Step 3: Install Flutter SDK

```bash
# Option A: Using Homebrew
brew install flutter

# Option B: Manual installation
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable

# Add to PATH in ~/.zshrc or ~/.bash_profile
export PATH="$PATH:$HOME/development/flutter/bin"
source ~/.zshrc
```

#### Step 4: Install Android Studio

```bash
brew install --cask android-studio
```

Or download from [developer.android.com/studio](https://developer.android.com/studio)

#### Step 5: Configure Xcode

```bash
# Accept Xcode license
sudo xcodebuild -license accept

# Install iOS Simulator
open -a Simulator
```

#### Step 6: Install CocoaPods (for iOS)

```bash
sudo gem install cocoapods
# Or with Homebrew:
brew install cocoapods
```

#### Step 7: Accept Android Licenses

```bash
flutter doctor --android-licenses
```

#### Step 8: Verify Setup

```bash
flutter doctor -v
```

Expected output:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain
[✓] Xcode
[✓] Chrome
[✓] Android Studio
[✓] VS Code (optional)
[✓] Connected device
```

---

### 2.3 Linux Installation

#### Step 1: Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

**Fedora:**
```bash
sudo dnf install -y curl git unzip xz zip mesa-libGLU clang cmake ninja-build gtk3-devel
```

**Arch Linux:**
```bash
sudo pacman -S --needed curl git unzip xz zip mesa clang cmake ninja gtk3
```

#### Step 2: Install Flutter SDK

```bash
# Create development directory
mkdir -p ~/development
cd ~/development

# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable

# Add to PATH in ~/.bashrc or ~/.zshrc
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### Step 3: Install Android Studio

1. Download from [developer.android.com/studio](https://developer.android.com/studio)

2. Extract and run:
   ```bash
   tar -xzf android-studio-*.tar.gz
   cd android-studio/bin
   ./studio.sh
   ```

3. Complete initial setup and install SDK

4. Add Android SDK to PATH:
   ```bash
   echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
   echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc
   source ~/.bashrc
   ```

#### Step 4: Install Chrome (for web development)

**Ubuntu/Debian:**
```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

#### Step 5: Accept Android Licenses

```bash
flutter doctor --android-licenses
```

#### Step 6: Verify Setup

```bash
flutter doctor -v
```

---

## 3. Project Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/BBPpolimi/MurugesanPalanisamyMarasani.git
cd MurugesanPalanisamyMarasani
```

### Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

### Step 3: Verify Project Structure

```
MurugesanPalanisamyMarasani/
├── lib/                    # Application source code
│   ├── main.dart          # Entry point
│   ├── models/            # Data models
│   ├── pages/             # UI screens
│   ├── services/          # Business logic
│   └── widgets/           # Reusable components
├── test/                   # Unit & widget tests
├── integration_test/       # Device integration tests
├── android/                # Android configuration
├── ios/                    # iOS configuration
├── pubspec.yaml           # Dependencies
└── firestore.rules        # Security rules
```

---

## 4. Firebase Configuration

### Step 1: Create Firebase Project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click "Add project"
3. Enter project name: `best-bike-paths` (or your choice)
4. Disable Google Analytics (optional for development)
5. Click "Create project"

### Step 2: Enable Authentication

1. In Firebase Console, go to **Build → Authentication**
2. Click "Get started"
3. Enable the following sign-in providers:
   - **Google** - Configure OAuth consent screen
   - **Email/Password** - Enable
   - **Anonymous** - Enable (for guest users)

### Step 3: Create Firestore Database

1. Go to **Build → Firestore Database**
2. Click "Create database"
3. Choose **Start in test mode** (for development)
4. Select a Cloud Firestore location (e.g., `europe-west6` or nearest to you)
5. Click "Enable"

### Step 4: Deploy Security Rules

1. In the project root, locate `firestore.rules`
2. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   # Or
   curl -sL firebase.tools | bash
   ```

3. Login to Firebase:
   ```bash
   firebase login
   ```

4. Initialize Firebase in project:
   ```bash
   firebase init firestore
   # Select your project
   # Use existing firestore.rules file
   ```

5. Deploy rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Step 5: Configure Android App in Firebase

1. In Firebase Console, click **Project Settings** (gear icon)
2. Under "Your apps", click **Android icon**
3. Enter package name: `com.example.bbp_flutter`
4. (Optional) Enter app nickname and debug signing certificate SHA-1
5. Click "Register app"
6. Download `google-services.json`
7. Place it in: `android/app/google-services.json`

### Step 6: Configure iOS App in Firebase

1. In Firebase Console, click **Add app → iOS**
2. Enter bundle ID: `com.example.bbpFlutter`
3. Click "Register app"
4. Download `GoogleService-Info.plist`
5. Place it in: `ios/Runner/GoogleService-Info.plist`

### Existing Configuration

> **Note:** The repository already includes Firebase configuration files. If you're using the existing project, you can skip Steps 5-6. However, for your own Firebase project, you must replace:
> - `android/app/google-services.json`
> - `ios/Runner/GoogleService-Info.plist`

---

## 5. Google Maps API Setup

### Step 1: Enable APIs in Google Cloud

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Select your Firebase project (same Google Cloud project)
3. Go to **APIs & Services → Library**
4. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Directions API**
   - **Geocoding API**

### Step 2: Create API Key

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → API Key**
3. Copy the generated API key
4. (Recommended) Click "Edit API Key" to add restrictions:
   - Application restrictions: Android apps / iOS apps
   - API restrictions: Select the 4 APIs enabled above

### Step 3: Configure Android

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <application ...>
        <!-- Replace YOUR_API_KEY with your actual key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY"/>
    </application>
</manifest>
```

### Step 4: Configure iOS

Edit `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps  // Add this import

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add this line with your API key
    GMSServices.provideAPIKey("YOUR_API_KEY")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 5: Update Directions Service

If using your own API key, edit `lib/services/directions_service.dart`:

```dart
class DirectionsService {
  static const String _googleApiKey = 'YOUR_API_KEY';  // Replace this
  // ...
}
```

### Existing Configuration

> **Note:** The repository includes working API keys for development. For production or your own project, replace with your own keys.

---

## 6. OpenWeatherMap API Setup

### Step 1: Create Account

1. Go to [openweathermap.org](https://openweathermap.org)
2. Sign up for a free account
3. Verify your email

### Step 2: Get API Key

1. Go to [API Keys](https://home.openweathermap.org/api_keys)
2. Copy your default key or generate a new one
3. Note: New keys take ~10 minutes to activate

### Step 3: Configure Weather Service

Edit `lib/services/weather_service.dart`:

```dart
class WeatherService {
  static const String _apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';  // Replace this
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  // ...
}
```

### Existing Configuration

> **Note:** The repository includes a working OpenWeatherMap API key for development.

---

## 7. Running the Application

### List Available Devices

```bash
flutter devices
```

Example output:
```
3 connected devices:

Pixel 6 (mobile)        • emulator-5554  • android-arm64  • Android 13 (API 33)
iPhone 14 Pro (mobile)  • 00008030-...   • ios            • iOS 16.4
Chrome (web)            • chrome         • web-javascript • Google Chrome
```

### Run on Android

```bash
# Run on connected Android device or emulator
flutter run -d android

# Or specify device ID
flutter run -d emulator-5554
```

### Run on iOS (macOS only)

```bash
# First time: Install CocoaPods dependencies
cd ios
pod install --repo-update
cd ..

# Run on iOS Simulator
flutter run -d iphone

# Or specify device ID
flutter run -d 00008030-...
```

### Run on Web (Limited Features)

```bash
flutter run -d chrome
```

> **Note:** GPS and sensor features are not available on web.

### Run in Debug Mode with Verbose Output

```bash
flutter run -v
```

### Hot Reload During Development

While the app is running:
- Press `r` for hot reload (preserves state)
- Press `R` for hot restart (full restart)
- Press `q` to quit

---

## 8. Running Tests

### Run All Unit Tests

```bash
flutter test
```

### Run Specific Test Categories

```bash
# Feature unit tests
flutter test test/integration/

# Widget tests
flutter test test/widget/

# Security tests
flutter test test/security/

# Performance tests
flutter test test/performance/
```

### Run Integration Tests on Device

```bash
# Get device ID first
flutter devices

# Run all integration tests
flutter test integration_test/ -d <device_id>

# Run specific test file
flutter test integration_test/f1_auth_test.dart -d <device_id>
```

### Generate Test Coverage Report

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## 9. Building for Production

### Android APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (macOS only)

```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release

# Output: build/ios/iphoneos/Runner.app
```

### Create iOS Archive for App Store

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Distribute via App Store Connect

---

## 10. Troubleshooting

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| `flutter pub get` fails | Run `flutter clean` then `flutter pub get` |
| Android device not detected | Enable USB debugging, run `adb devices` |
| iOS build fails | Run `cd ios && pod install --repo-update` |
| Firebase initialization error | Verify `google-services.json` or `GoogleService-Info.plist` |
| Google Maps shows blank | Check API key restrictions in Google Cloud Console |
| Weather data not loading | Verify OpenWeatherMap API key is active |
| "No connected devices" | Start emulator or connect physical device |
| Gradle build fails | Run `cd android && ./gradlew clean` |
| CocoaPods error | Run `sudo gem install cocoapods` |

### Verify Flutter Installation

```bash
flutter doctor -v
```

Fix any issues reported by the doctor command.

### Clear All Caches

```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### Reset Android Build

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Reset iOS Build

```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter pub get
```

### Check Firestore Connection

If data isn't syncing, verify:
1. Firebase project is correctly linked
2. Firestore database is created
3. Security rules are deployed
4. Internet connection is available

### Debug Network Requests

Add to your service for debugging:
```dart
print('DEBUG: Request URL: $url');
print('DEBUG: Response: ${response.data}');
```

---

## Quick Start Summary

```bash
# 1. Clone project
git clone https://github.com/BBPpolimi/MurugesanPalanisamyMarasani.git
cd MurugesanPalanisamyMarasani

# 2. Install dependencies
flutter pub get

# 3. Check setup
flutter doctor

# 4. List devices
flutter devices

# 5. Run app
flutter run -d <device_id>

# 6. Run tests
flutter test
```

---

## Support

For issues:
1. Check [Flutter documentation](https://docs.flutter.dev)
2. Check [Firebase documentation](https://firebase.google.com/docs)
3. Open an issue on the GitHub repository

---

## Authors

- Jayasurya Marasani
- Arunkumar Murugesan
- Sneharajalakshmi Palanisamy

Politecnico di Milano - Software Engineering II (2025-2026)
