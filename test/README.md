# Global Script Feature Tests

This directory contains comprehensive tests for the Global Extend Script feature.

## Test Coverage

### 1. Unit Tests (`global_script_manager_test.dart`)

Tests the core functionality of `GlobalScriptManager`:

- ✅ Initialization and default values
- ✅ Configuration updates (enabled, script, remark)
- ✅ Script execution with YAML parsing
- ✅ JavaScript execution via flutter_js
- ✅ Error handling and graceful degradation
- ✅ Array and nested object handling
- ✅ Complex real-world script scenarios
- ✅ Event callbacks
- ✅ Script testing without modifying global config

**Coverage**: ~90% of GlobalScriptManager functionality

### 2. Widget Tests (`global_script_edit_screen_test.dart`)

Tests the UI components of `GlobalScriptEditScreen`:

- ✅ Widget rendering and layout
- ✅ Enable/disable switch functionality
- ✅ Remark text field
- ✅ Code editor integration
- ✅ Navigation (back button, save button)
- ✅ State management and updates
- ✅ Integration with GlobalScriptManager
- ✅ Basic accessibility checks

**Coverage**: UI component interactions and state management

### 3. Integration Tests (`global_script_integration_test.dart`)

Tests end-to-end workflows:

- ✅ Complete user journey (enable → write script → modify config)
- ✅ Real-world region grouping script (from user's example)
- ✅ Proxy group modifications
- ✅ DNS configuration additions
- ✅ Feature enable/disable flow
- ✅ Error recovery scenarios
- ✅ Performance testing (multiple executions)
- ✅ Complex data type handling
- ✅ Edge cases and error conditions

**Coverage**: Full feature integration and production scenarios

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
# Unit tests only
flutter test test/global_script_manager_test.dart

# Widget tests only
flutter test test/global_script_edit_screen_test.dart

# Integration tests only
flutter test test/global_script_integration_test.dart
```

### Run with Coverage

```bash
flutter test --coverage
```

View coverage report:
```bash
# Install genhtml (Linux)
sudo apt-get install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

### Run Tests in Watch Mode

```bash
flutter test --watch
```

## CI/CD Integration

### GitHub Actions Workflows

#### 1. Main CI Workflow (`.github/workflows/ci.yml`)

Runs on every push and PR:

- **Analyze Job**: Code formatting and static analysis
- **Test Job**: Runs all tests with coverage
- **Build Jobs**: Builds for all platforms (Android, iOS, Linux, macOS, Windows)

#### 2. Global Script Feature Workflow (`.github/workflows/global-script-feature.yml`)

Runs when global script files are modified:

- **Test Global Script**: Runs feature-specific tests
- **Frontend Check**: Verifies UI compilation and imports
- **Integration Check**: Tests the complete integration

This workflow includes additional verification:
- Dependency verification (flutter_js, yaml)
- i18n string checks
- Integration point verification
- Build-time compilation checks

### Running CI Locally

You can simulate CI checks locally:

```bash
# Format check
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze --no-fatal-infos

# Run tests
flutter test --coverage

# Build for current platform
flutter build apk --debug  # Android
flutter build linux --debug  # Linux
flutter build windows --debug  # Windows (on Windows)
flutter build macos --debug  # macOS (on macOS)
```

## Test Scenarios Covered

### Basic Functionality
- [x] Enable/disable feature
- [x] Update script content
- [x] Update remark
- [x] Save and load configuration

### Script Execution
- [x] Passthrough script (no modifications)
- [x] Add new fields to config
- [x] Modify existing fields
- [x] Create proxy groups
- [x] Add DNS configuration
- [x] Handle arrays and nested objects

### Real-World Scenarios
- [x] Region-based proxy grouping
- [x] Auto-test group creation
- [x] Speed filtering (exclude 2x, 3x proxies)
- [x] Emoji handling in proxy names
- [x] Multiple region support

### Error Handling
- [x] Invalid JavaScript syntax
- [x] Runtime errors in script
- [x] Invalid YAML input
- [x] Missing main function
- [x] Script returns non-object
- [x] Graceful degradation

### UI Functionality
- [x] Screen rendering
- [x] Switch toggle
- [x] Text input
- [x] Code editor
- [x] Navigation
- [x] Save functionality

## Example Test Script

Here's the test version of your actual use case:

```javascript
function main(config) {
  const proxies = config.proxies || [];

  function getRegion(proxyName) {
    const match = proxyName.match(/^(🇯🇵\s?JP|🇸🇬\s?SG|🇹🇼\s?TW)/u);
    if (match) {
      if (match[1].includes('JP')) return '🇯🇵 JP';
      if (match[1].includes('SG')) return '🇸🇬 SG';
      if (match[1].includes('TW')) return '🇹🇼 TW';
    }
    return null;
  }

  function isValidSpeed(proxyName) {
    const match = proxyName.match(/(\d+)x/i);
    return !match || parseInt(match[1]) <= 1;
  }

  const regionMap = {};
  proxies.forEach(p => {
    const region = getRegion(p.name);
    if (region && isValidSpeed(p.name)) {
      if (!regionMap[region]) regionMap[region] = [];
      regionMap[region].push(p.name);
    }
  });

  const autoTestGroups = [];
  Object.keys(regionMap).forEach(region => {
    const regionProxies = regionMap[region];
    if (regionProxies.length > 0) {
      autoTestGroups.push({
        name: region + '-Auto',
        type: 'url-test',
        url: 'http://www.gstatic.com/generate_204',
        interval: 600,
        tolerance: 200,
        proxies: regionProxies
      });
    }
  });

  if (!config['proxy-groups']) {
    config['proxy-groups'] = [];
  }
  config['proxy-groups'] = config['proxy-groups'].concat(autoTestGroups);

  return config;
}
```

This script is tested in `global_script_integration_test.dart` with real proxy data.

## Debugging Tests

### Enable Verbose Logging

```bash
flutter test --verbose
```

### Run Single Test

```bash
flutter test --name "should execute simple passthrough script"
```

### Debug in IDE

In VS Code or Android Studio, use the test runner to set breakpoints and step through tests.

## Coverage Goals

- **GlobalScriptManager**: ≥ 90% line coverage
- **GlobalScriptEditScreen**: ≥ 80% widget coverage
- **Integration**: All critical paths tested

## Continuous Improvement

Tests are automatically run on:
- Every push to any branch
- Every pull request
- Changes to global script feature files

Failed tests will block PR merges to ensure quality.

## Contributing

When adding new features to the global script system:

1. Add unit tests for new functionality
2. Add widget tests for new UI components
3. Add integration tests for complete workflows
4. Ensure all tests pass locally before pushing
5. Check that CI passes on your PR

## Resources

- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [flutter_test package](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)
- [flutter_js documentation](https://pub.dev/packages/flutter_js)
- [yaml package](https://pub.dev/packages/yaml)
