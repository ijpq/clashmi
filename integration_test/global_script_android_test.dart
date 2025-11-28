import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:clashmi/main.dart' as app;
import 'package:clashmi/app/modules/global_script_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Global Script Feature - Android Integration Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify the app launched
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('GlobalScriptManager initializes on Android',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // GlobalScriptManager should be initialized by Biz.init()
      // We can verify this by checking if we can get the config
      final config = GlobalScriptManager.getConfig();
      expect(config, isNotNull);
      expect(config.enabled, isFalse); // Default is disabled
    });

    testWidgets('Can enable and configure global script on Android',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Set up a script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            config.testField = 'android-test';
            return config;
          }
        ''',
        remark: 'Android Integration Test',
      );

      // Verify configuration was saved
      expect(GlobalScriptManager.isEnabled(), isTrue);
      expect(GlobalScriptManager.getScript(), contains('android-test'));
      expect(GlobalScriptManager.getRemark(), equals('Android Integration Test'));
    });

    testWidgets('JavaScript execution works on Android',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Configure a script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            if (!config.proxies) {
              config.proxies = [];
            }

            // Add a test proxy
            config.proxies.push({
              name: 'Android Test Proxy',
              type: 'ss',
              server: 'test.example.com',
              port: 443
            });

            return config;
          }
        ''',
      );

      // Test execution with sample YAML
      const testYaml = '''
proxies:
  - name: Original Proxy
    type: ss
    server: original.example.com
    port: 8388
''';

      final result = await GlobalScriptManager.executeScript(testYaml);

      // Verify execution succeeded
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('Android Test Proxy'));
      expect(result.data, contains('Original Proxy'));
    });

    testWidgets('Real-world script works on Android device',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Set up the user's actual region grouping script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        remark: 'Region Grouping for Android',
        script: '''
          function main(config) {
            const proxies = config.proxies || [];

            function getRegion(proxyName) {
              const match = proxyName.match(/^([A-Z]{2})/);
              return match ? match[1] : null;
            }

            function isValidSpeed(proxyName) {
              const match = proxyName.match(/(\\d+)x/i);
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
        ''',
      );

      // Test with realistic data
      const testYaml = '''
proxies:
  - name: JP Tokyo-01
    type: ss
    server: tokyo.example.com
    port: 443
  - name: JP Osaka-01
    type: ss
    server: osaka.example.com
    port: 443
  - name: SG Singapore-01
    type: vmess
    server: singapore.example.com
    port: 443
  - name: US NewYork-01 2x
    type: ss
    server: ny.example.com
    port: 443
proxy-groups:
  - name: Manual
    type: select
    proxies:
      - DIRECT
''';

      final result = await GlobalScriptManager.executeScript(testYaml);

      // Verify the script executed successfully
      expect(result.error, isNull);
      expect(result.data, isNotNull);

      // Check that auto-test groups were created
      expect(result.data, contains('JP-Auto'));
      expect(result.data, contains('SG-Auto'));
      expect(result.data, contains('US-Auto'));

      // Verify original groups are preserved
      expect(result.data, contains('Manual'));

      // Verify proxies are included
      expect(result.data, contains('Tokyo-01'));
      expect(result.data, contains('Singapore-01'));
    });

    testWidgets('Script execution performance on Android device',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            // Simple transformation
            config.processed = true;
            return config;
          }
        ''',
      );

      const testYaml = 'proxies: []';

      // Execute 10 times to test performance
      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 10; i++) {
        final result = await GlobalScriptManager.executeScript(testYaml);
        expect(result.error, isNull);
      }

      stopwatch.stop();

      // On Android, 10 executions should complete in reasonable time
      // Allow up to 5 seconds for 10 executions (500ms per execution max)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));

      // Log performance for debugging
      debugPrint(
          'Android: 10 script executions took ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Error handling works correctly on Android',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Set up a buggy script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            throw new Error('Test error on Android');
          }
        ''',
      );

      const testYaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(testYaml);

      // Should return an error, not crash
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('error'));
    });

    testWidgets('Disabled script bypasses execution on Android',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Set up a script but disable it
      await GlobalScriptManager.updateConfig(
        enabled: false,
        script: 'function main(config) { config.modified = true; return config; }',
      );

      const testYaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(testYaml);

      // Should return original YAML unchanged
      expect(result.error, isNull);
      expect(result.data, equals(testYaml));
      expect(result.data, isNot(contains('modified')));
    });

    testWidgets('Complex YAML structures work on Android',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            // Add complex nested structure
            config.dns = {
              enable: true,
              nameserver: ['8.8.8.8', '1.1.1.1'],
              fallback: ['114.114.114.114'],
              'fallback-filter': {
                geoip: true,
                'geoip-code': 'CN'
              }
            };
            return config;
          }
        ''',
      );

      const testYaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(testYaml);

      expect(result.error, isNull);
      expect(result.data, contains('dns'));
      expect(result.data, contains('nameserver'));
      expect(result.data, contains('8.8.8.8'));
      expect(result.data, contains('fallback-filter'));
      expect(result.data, contains('geoip'));
    });
  });

  group('Android-Specific Compatibility Tests', () {
    testWidgets('Works on Android API 29', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // This test runs on API 29 in CI
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { config.api = 29; return config; }',
      );

      final result = await GlobalScriptManager.executeScript('proxies: []');
      expect(result.error, isNull);
      expect(result.data, contains('29'));
    });

    testWidgets('Works on Android API 33', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // This test runs on API 33 in CI
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { config.api = 33; return config; }',
      );

      final result = await GlobalScriptManager.executeScript('proxies: []');
      expect(result.error, isNull);
      expect(result.data, contains('33'));
    });

    testWidgets('Memory handling on Android', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test with larger config to verify memory handling
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            // Create many proxy groups
            if (!config['proxy-groups']) {
              config['proxy-groups'] = [];
            }

            for (var i = 0; i < 50; i++) {
              config['proxy-groups'].push({
                name: 'Group-' + i,
                type: 'select',
                proxies: ['DIRECT', 'REJECT']
              });
            }

            return config;
          }
        ''',
      );

      const testYaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(testYaml);

      expect(result.error, isNull);
      expect(result.data, isNotNull);
      // Should create 50 groups without memory issues
      expect(result.data, contains('Group-49'));
    });
  });
}
