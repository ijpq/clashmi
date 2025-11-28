# Android CI and Release Guide

This document describes the Android testing infrastructure and release process for Clashmi.

## 📱 Android CI Testing

### Emulator Testing

The CI automatically tests the app on real Android emulators with the following configurations:

| API Level | Android Version | Architecture | Purpose |
|-----------|----------------|--------------|---------|
| **29** | Android 10 | x86_64 | Baseline compatibility |
| **33** | Android 13 | x86_64 | Latest stable version |

### What Gets Tested

#### 1. **Integration Tests** (`integration_test/global_script_android_test.dart`)

**12+ test scenarios** running on actual Android devices:

✅ **Basic Functionality**
- App launches successfully
- GlobalScriptManager initialization
- Enable/disable script functionality
- Configuration persistence

✅ **JavaScript Execution**
- Script execution on Android runtime
- YAML parsing and conversion
- Complex data structure handling
- Performance testing (10 executions < 5 seconds)

✅ **Real-World Scenarios**
- Region-based proxy grouping
- Auto-test group creation
- DNS configuration
- Multiple proxy groups
- Nested YAML structures

✅ **Error Handling**
- Script errors don't crash the app
- Invalid YAML handling
- Disabled script bypass
- Memory management with large configs

✅ **API Compatibility**
- Android 10 (API 29) compatibility
- Android 13 (API 33) compatibility
- Cross-version consistency

### Running Integration Tests Locally

#### Prerequisites

```bash
# Install Android SDK and emulator
flutter doctor

# Ensure at least one emulator is available
flutter emulators

# Create an emulator if needed
flutter emulators --create
```

#### Run Tests on Emulator

```bash
# Start an emulator
flutter emulators --launch <emulator-name>

# Run integration tests
flutter test integration_test/global_script_android_test.dart

# Or use the Flutter driver
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/global_script_android_test.dart
```

#### Run Tests on Physical Device

```bash
# Connect your Android device via USB with USB debugging enabled

# Verify device is connected
flutter devices

# Run tests
flutter test integration_test/global_script_android_test.dart -d <device-id>
```

### CI Emulator Configuration

The CI uses the `reactivecircus/android-emulator-runner` action with:

```yaml
emulator-options: >
  -no-window
  -gpu swiftshader_indirect
  -noaudio
  -no-boot-anim
  -camera-back none
```

**Features:**
- ✅ AVD caching for faster runs
- ✅ KVM hardware acceleration
- ✅ Parallel testing on multiple API levels
- ✅ Test result uploads as artifacts

## 📦 Release Builds

### Multi-Architecture APK Builds

The release workflow (`release.yml`) builds APKs for all Android architectures:

| Architecture | Devices | File Size | Recommended For |
|-------------|---------|-----------|-----------------|
| **arm64-v8a** | Modern ARM 64-bit | Smallest | Most users (2016+ phones) |
| **armeabi-v7a** | Older ARM 32-bit | Small | Older devices (pre-2016) |
| **x86_64** | Intel/AMD 64-bit | Small | Emulators, some tablets |
| **universal** | All architectures | Largest | Maximum compatibility |

### Release Workflow Triggers

#### 1. **Tag-based Release**

```bash
# Create and push a version tag
git tag v1.0.15
git push origin v1.0.15
```

This automatically:
1. ✅ Builds APKs for all architectures
2. ✅ Builds universal APK
3. ✅ Builds AAB for Play Store
4. ✅ Builds Linux, Windows, macOS binaries
5. ✅ Creates GitHub Release with all artifacts
6. ✅ Generates release notes

#### 2. **Manual Release**

Via GitHub Actions UI:
1. Go to Actions → Release Build → Run workflow
2. Enter version (e.g., `v1.0.15`)
3. Click "Run workflow"

### Release Artifacts

Each release creates:

```
📦 Android APKs
├── clashmi-v1.0.15-arm64-v8a.apk      (recommended)
├── clashmi-v1.0.15-armeabi-v7a.apk    (older devices)
├── clashmi-v1.0.15-x86_64.apk         (emulators)
├── clashmi-v1.0.15-universal.apk      (all architectures)
└── clashmi-v1.0.15.aab                (Play Store)

📦 Desktop Binaries
├── clashmi-v1.0.15-linux-x64.tar.gz
├── clashmi-v1.0.15-windows-x64.zip
└── clashmi-v1.0.15-macos.zip
```

## 🛠️ Building Locally

### Build Specific Architecture APK

```bash
# ARM 64-bit (recommended)
flutter build apk --release \
  --target-platform android-arm64 \
  --split-per-abi

# ARM 32-bit
flutter build apk --release \
  --target-platform android-arm \
  --split-per-abi

# x86 64-bit
flutter build apk --release \
  --target-platform android-x64 \
  --split-per-abi
```

### Build Universal APK

```bash
flutter build apk --release
```

### Build App Bundle (AAB)

```bash
flutter build appbundle --release
```

### Build with Signing

For signed releases, configure signing in `android/app/build.gradle`:

```gradle
signingConfigs {
    release {
        storeFile file(System.getenv("KEYSTORE_FILE") ?: "key.jks")
        storePassword System.getenv("KEYSTORE_PASSWORD")
        keyAlias System.getenv("KEY_ALIAS")
        keyPassword System.getenv("KEY_PASSWORD")
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        // ... other settings
    }
}
```

Set environment variables:
```bash
export KEYSTORE_FILE=/path/to/keystore.jks
export KEYSTORE_PASSWORD=your_store_password
export KEY_ALIAS=your_key_alias
export KEY_PASSWORD=your_key_password

flutter build apk --release
```

## 📊 Understanding APK Sizes

| Build Type | Size (approx) | Compatibility |
|-----------|---------------|---------------|
| arm64-v8a | ~50MB | 64-bit ARM only |
| armeabi-v7a | ~45MB | 32-bit ARM only |
| x86_64 | ~55MB | x86_64 only |
| universal | ~145MB | All architectures |
| AAB | ~145MB | Play Store optimizes |

**Recommendation**: Use split APKs for distribution, universal only for testing.

## 🚀 Publishing to Play Store

### Using App Bundle (Recommended)

```bash
# Build AAB
flutter build appbundle --release

# Upload to Play Store Console
# Location: build/app/outputs/bundle/release/app-release.aab
```

**Benefits:**
- ✅ Smaller download sizes (Play Store optimizes per-device)
- ✅ Dynamic delivery support
- ✅ Required for new apps on Play Store

### Using APKs (Alternative)

```bash
# Build all APKs
flutter build apk --release --split-per-abi

# Upload all APKs to Play Store
# arm64-v8a: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# armeabi-v7a: build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# x86_64: build/app/outputs/flutter-apk/app-x86_64-release.apk
```

## 🔍 Debugging Build Issues

### Check Supported ABIs

```bash
flutter doctor -v
```

### View APK Contents

```bash
unzip -l app-arm64-v8a-release.apk
```

### Analyze APK Size

```bash
flutter build apk --release --analyze-size
```

### Check Architecture

```bash
# Extract native libraries
unzip app-arm64-v8a-release.apk -d extracted/
ls extracted/lib/

# Should show: arm64-v8a/
```

## 📈 CI Performance

Typical CI run times:

| Job | Duration |
|-----|----------|
| Unit Tests | ~2 min |
| Android Emulator Test (API 29) | ~8 min |
| Android Emulator Test (API 33) | ~8 min |
| Build arm64-v8a APK | ~3 min |
| Build armeabi-v7a APK | ~3 min |
| Build x86_64 APK | ~3 min |
| **Total CI Run** | **~25-30 min** |

Release builds take ~15-20 minutes for all platforms.

## 🎯 Best Practices

### For Development

- ✅ Use debug APKs during development
- ✅ Test on emulators for quick iteration
- ✅ Use hot reload for UI changes
- ✅ Run integration tests before major commits

### For Testing

- ✅ Test on multiple API levels (29, 33)
- ✅ Test on both ARM and x86 if possible
- ✅ Run integration tests on physical devices
- ✅ Verify global script feature works on real data

### For Release

- ✅ Always create signed releases
- ✅ Test release builds before publishing
- ✅ Use semantic versioning (v1.0.15)
- ✅ Include changelog in release notes
- ✅ Verify all architectures build successfully
- ✅ Test universal APK on multiple devices

## 🐛 Troubleshooting

### Emulator Won't Start in CI

```yaml
# Ensure KVM is enabled
- name: Enable KVM group perms
  run: |
    echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
    sudo udevadm control --reload-rules
```

### Integration Tests Fail on Emulator

```bash
# Increase timeout
flutter test integration_test/ --timeout=2m

# Check emulator logs
adb logcat
```

### Build Fails for Specific Architecture

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64
```

### APK Too Large

```bash
# Enable code shrinking in android/app/build.gradle
buildTypes {
    release {
        shrinkResources true
        minifyEnabled true
    }
}
```

## 📚 Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Play Store Publishing](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Android Emulator Runner](https://github.com/ReactiveCircus/android-emulator-runner)

## 🔐 Security Notes

### Keystore Management

**Never commit keystores or passwords to git!**

```bash
# .gitignore should include:
*.jks
*.keystore
key.properties
```

### CI Secrets

Set up GitHub Secrets for signing:
- `KEYSTORE_FILE` (base64 encoded keystore)
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

Access in workflow:
```yaml
env:
  KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
```

## 📞 Support

For issues with CI or releases:
1. Check [GitHub Actions logs](../../actions)
2. Review [test results artifacts](../../actions)
3. Open an issue with CI logs attached
