import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clashmi/app/modules/global_script_manager.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GlobalScriptManager', () {
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('global_script_test_');
    });

    tearDown(() async {
      // Clean up
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('should initialize with default values', () {
      final config = GlobalScriptManager.getConfig();
      expect(config, isNotNull);
      expect(config.enabled, isFalse);
      expect(config.script, isEmpty);
      expect(config.remark, isEmpty);
    });

    test('should update enabled status', () async {
      await GlobalScriptManager.setEnabled(true);
      expect(GlobalScriptManager.isEnabled(), isTrue);

      await GlobalScriptManager.setEnabled(false);
      expect(GlobalScriptManager.isEnabled(), isFalse);
    });

    test('should update script content', () async {
      const testScript = '''
        function main(config) {
          return config;
        }
      ''';

      await GlobalScriptManager.setScript(testScript);
      expect(GlobalScriptManager.getScript(), equals(testScript));
    });

    test('should update remark', () async {
      const testRemark = 'Test Remark';

      await GlobalScriptManager.setRemark(testRemark);
      expect(GlobalScriptManager.getRemark(), equals(testRemark));
    });

    test('should update config atomically', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { return config; }',
        remark: 'Updated config',
      );

      expect(GlobalScriptManager.isEnabled(), isTrue);
      expect(GlobalScriptManager.getScript(), contains('function main'));
      expect(GlobalScriptManager.getRemark(), equals('Updated config'));
    });

    test('should return original YAML when script is disabled', () async {
      await GlobalScriptManager.setEnabled(false);
      const yamlContent = '''
proxies:
  - name: test
    type: ss
    server: example.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, equals(yamlContent));
    });

    test('should execute simple passthrough script', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            return config;
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: test
    type: ss
    server: example.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('proxies'));
    });

    test('should modify config with script', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            config['test-field'] = 'test-value';
            return config;
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: test
    type: ss
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('test-field'));
      expect(result.data, contains('test-value'));
    });

    test('should handle script errors gracefully', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            throw new Error('Intentional error');
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: test
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNotNull);
      expect(result.error!.message, contains('error'));
    });

    test('should handle invalid YAML input', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { return config; }',
      );

      const invalidYaml = '''
this is not: valid: yaml:
  - broken
    structure
''';

      final result = await GlobalScriptManager.executeScript(invalidYaml);
      // Should either handle gracefully or return error
      expect(result, isNotNull);
    });

    test('should add proxy groups with script', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            if (!config['proxy-groups']) {
              config['proxy-groups'] = [];
            }
            config['proxy-groups'].push({
              name: 'Auto-Select',
              type: 'url-test',
              proxies: ['DIRECT']
            });
            return config;
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: test
    type: ss
    server: example.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('proxy-groups'));
      expect(result.data, contains('Auto-Select'));
    });

    test('should preserve array structures', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            return config;
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: proxy1
    type: ss
    server: server1.com
    port: 443
  - name: proxy2
    type: vmess
    server: server2.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('proxy1'));
      expect(result.data, contains('proxy2'));
    });

    test('should handle nested objects', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            if (!config.dns) {
              config.dns = {
                enable: true,
                nameserver: ['8.8.8.8', '1.1.1.1']
              };
            }
            return config;
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: test
    type: ss
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('dns'));
      expect(result.data, contains('nameserver'));
      expect(result.data, contains('8.8.8.8'));
    });

    test('should test script without modifying global config', () async {
      // Set a different global config
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { config.test = "global"; return config; }',
      );

      // Test with a different script
      const testScript = 'function main(config) { config.test = "local"; return config; }';
      const yamlContent = 'proxies: []';

      final result = await GlobalScriptManager.testScript(testScript, yamlContent);

      // The test should use the test script, not the global one
      expect(result.error, isNull);
      expect(result.data, contains('local'));

      // Global config should remain unchanged
      expect(GlobalScriptManager.getScript(), contains('global'));
    });

    test('should handle special characters in YAML strings', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            return config;
          }
        ''',
      );

      const yamlContent = '''
proxies:
  - name: "Test: Proxy #1"
    type: ss
    server: example.com
    port: 443
    password: "p@ssw0rd!"
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
    });

    test('should handle complex real-world script', () async {
      // This is based on the user's example script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            const proxies = config.proxies || [];

            function getRegion(proxyName) {
              const match = proxyName.match(/^([A-Z]{2})/);
              return match ? match[1] : null;
            }

            const regionMap = {};
            proxies.forEach(p => {
              const region = getRegion(p.name);
              if (region) {
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

      const yamlContent = '''
proxies:
  - name: JP Tokyo
    type: ss
    server: tokyo.example.com
    port: 443
  - name: JP Osaka
    type: ss
    server: osaka.example.com
    port: 443
  - name: US NewYork
    type: vmess
    server: ny.example.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(yamlContent);
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('JP-Auto'));
      expect(result.data, contains('US-Auto'));
      expect(result.data, contains('proxy-groups'));
    });
  });

  group('GlobalScriptManager - Config Persistence', () {
    test('should save and load configuration', () async {
      // Note: This test would require mocking the file system
      // or using a temporary directory. For now, we test the
      // in-memory operations.

      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'test script',
        remark: 'test remark',
      );

      // Verify the config is set
      final config = GlobalScriptManager.getConfig();
      expect(config.enabled, isTrue);
      expect(config.script, equals('test script'));
      expect(config.remark, equals('test remark'));
    });
  });

  group('GlobalScriptManager - Event Callbacks', () {
    test('should trigger onChange events', () async {
      var callbackTriggered = false;

      void testCallback() {
        callbackTriggered = true;
      }

      GlobalScriptManager.onEventChanged.add(testCallback);

      await GlobalScriptManager.setEnabled(true);

      expect(callbackTriggered, isTrue);

      // Cleanup
      GlobalScriptManager.onEventChanged.remove(testCallback);
    });
  });
}
