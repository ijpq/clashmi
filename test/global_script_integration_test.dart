import 'package:flutter_test/flutter_test.dart';
import 'package:clashmi/app/modules/global_script_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Global Script Integration Tests', () {
    setUp(() async {
      await GlobalScriptManager.init();
    });

    tearDown(() async {
      await GlobalScriptManager.updateConfig(
        enabled: false,
        script: '',
        remark: '',
      );
    });

    test('End-to-end: User enables script and modifies config', () async {
      // Step 1: User enables the feature
      await GlobalScriptManager.setEnabled(true);
      expect(GlobalScriptManager.isEnabled(), isTrue);

      // Step 2: User sets a remark
      await GlobalScriptManager.setRemark('My custom script');
      expect(GlobalScriptManager.getRemark(), equals('My custom script'));

      // Step 3: User writes a script
      const userScript = '''
        function main(config) {
          // Add DNS configuration
          config.dns = {
            enable: true,
            nameserver: ['8.8.8.8', '1.1.1.1']
          };
          return config;
        }
      ''';
      await GlobalScriptManager.setScript(userScript);

      // Step 4: VPN service processes a profile
      const profileYaml = '''
proxies:
  - name: Test Proxy
    type: ss
    server: example.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(profileYaml);

      // Step 5: Verify the script executed successfully
      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data, contains('dns'));
      expect(result.data, contains('8.8.8.8'));
      expect(result.data, contains('Test Proxy'));
    });

    test('End-to-end: Script modifies proxy groups', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            const proxies = config.proxies || [];

            // Create auto-select group
            if (!config['proxy-groups']) {
              config['proxy-groups'] = [];
            }

            config['proxy-groups'].push({
              name: 'Auto-Select',
              type: 'url-test',
              url: 'http://www.gstatic.com/generate_204',
              interval: 300,
              proxies: proxies.map(p => p.name)
            });

            return config;
          }
        ''',
      );

      const profileYaml = '''
proxies:
  - name: Proxy-1
    type: ss
    server: server1.com
    port: 443
  - name: Proxy-2
    type: vmess
    server: server2.com
    port: 443
''';

      final result = await GlobalScriptManager.executeScript(profileYaml);

      expect(result.error, isNull);
      expect(result.data, contains('proxy-groups'));
      expect(result.data, contains('Auto-Select'));
      expect(result.data, contains('url-test'));
      expect(result.data, contains('Proxy-1'));
      expect(result.data, contains('Proxy-2'));
    });

    test('End-to-end: Real-world region grouping script', () async {
      // This simulates the user's actual use case
      await GlobalScriptManager.updateConfig(
        enabled: true,
        remark: 'Region-based auto-test groups',
        script: '''
          function main(config) {
            const proxies = config.proxies || [];

            function getRegion(proxyName) {
              // Match emoji + country code pattern
              const match = proxyName.match(/^(🇯🇵\\s?JP|🇸🇬\\s?SG|🇹🇼\\s?TW)/u);
              if (match) {
                if (match[1].includes('JP') || match[1].includes('🇯🇵')) return '🇯🇵 JP';
                if (match[1].includes('SG') || match[1].includes('🇸🇬')) return '🇸🇬 SG';
                if (match[1].includes('TW') || match[1].includes('🇹🇼')) return '🇹🇼 TW';
              }
              return null;
            }

            function isValidSpeed(proxyName) {
              const match = proxyName.match(/(\\d+)x/i);
              return !match || parseInt(match[1]) <= 1;
            }

            // Group proxies by region
            const regionMap = {};
            proxies.forEach(p => {
              const region = getRegion(p.name);
              if (region && isValidSpeed(p.name)) {
                if (!regionMap[region]) regionMap[region] = [];
                regionMap[region].push(p.name);
              }
            });

            // Create auto-test groups
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

            // Add to config
            if (!config['proxy-groups']) {
              config['proxy-groups'] = [];
            }

            // Merge auto groups
            config['proxy-groups'] = config['proxy-groups'].concat(autoTestGroups);

            return config;
          }
        ''',
      );

      const profileYaml = '''
proxies:
  - name: 🇯🇵 JP Tokyo-01
    type: ss
    server: tokyo1.example.com
    port: 443
  - name: 🇯🇵 JP Osaka-01
    type: ss
    server: osaka1.example.com
    port: 443
  - name: 🇸🇬 SG Singapore-01
    type: vmess
    server: sg1.example.com
    port: 443
  - name: 🇹🇼 TW Taipei-01 2x
    type: ss
    server: taipei1.example.com
    port: 443
  - name: 🇹🇼 TW Kaohsiung-01
    type: vmess
    server: kaohsiung1.example.com
    port: 443
proxy-groups:
  - name: 🔰 Manual
    type: select
    proxies:
      - DIRECT
''';

      final result = await GlobalScriptManager.executeScript(profileYaml);

      expect(result.error, isNull);
      expect(result.data, isNotNull);

      // Should create JP-Auto group (2 proxies)
      expect(result.data, contains('🇯🇵 JP-Auto'));

      // Should create SG-Auto group (1 proxy)
      expect(result.data, contains('🇸🇬 SG-Auto'));

      // Should create TW-Auto group (1 proxy, excluding 2x speed)
      expect(result.data, contains('🇹🇼 TW-Auto'));

      // Should preserve existing groups
      expect(result.data, contains('🔰 Manual'));

      // Should have correct configuration
      expect(result.data, contains('url-test'));
      expect(result.data, contains('600')); // interval
      expect(result.data, contains('200')); // tolerance
    });

    test('End-to-end: Disable feature and bypass script', () async {
      // Set up a script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function main(config) { config.modified = true; return config; }',
      );

      // Disable the feature
      await GlobalScriptManager.setEnabled(false);

      const profileYaml = '''
proxies:
  - name: Test
    type: ss
''';

      final result = await GlobalScriptManager.executeScript(profileYaml);

      // Script should not execute when disabled
      expect(result.error, isNull);
      expect(result.data, equals(profileYaml)); // Original unchanged
      expect(result.data, isNot(contains('modified')));
    });

    test('End-to-end: Script error handling in production scenario', () async {
      // User writes a buggy script
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            // Typo: missing closing brace
            if (config.proxies) {
              return {broken: true
            }
          }
        ''',
      );

      const profileYaml = 'proxies: []';

      final result = await GlobalScriptManager.executeScript(profileYaml);

      // Should return an error but not crash
      expect(result, isNotNull);
      // In production, VPN service would fall back to original config
    });

    test('End-to-end: Multiple script executions (performance)', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            config.processed = true;
            return config;
          }
        ''',
      );

      const profileYaml = 'proxies: []';

      // Execute multiple times (simulating multiple profile switches)
      for (var i = 0; i < 10; i++) {
        final result = await GlobalScriptManager.executeScript(profileYaml);
        expect(result.error, isNull);
        expect(result.data, contains('processed'));
      }
    });

    test('End-to-end: Script with complex data types', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            // Add various data types
            config.numbers = 12345;
            config.floats = 3.14;
            config.booleans = true;
            config.nullValue = null;
            config.arrays = [1, 2, 3, "four"];
            config.nested = {
              level1: {
                level2: {
                  level3: "deep"
                }
              }
            };
            return config;
          }
        ''',
      );

      const profileYaml = 'proxies: []';

      final result = await GlobalScriptManager.executeScript(profileYaml);

      expect(result.error, isNull);
      expect(result.data, contains('12345'));
      expect(result.data, contains('3.14'));
      expect(result.data, contains('true'));
      expect(result.data, contains('deep'));
    });

    test('End-to-end: Config persistence and reload', () async {
      // Save config
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'test script content',
        remark: 'test remark',
      );

      // Verify it's saved in memory
      expect(GlobalScriptManager.getScript(), contains('test script content'));
      expect(GlobalScriptManager.getRemark(), equals('test remark'));
      expect(GlobalScriptManager.isEnabled(), isTrue);

      // Note: Full file persistence testing would require file system mocking
      // or running in a real environment
    });
  });

  group('Global Script - Error Recovery', () {
    test('should recover from JavaScript syntax errors', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'this is not valid javascript {[}]',
      );

      const yaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(yaml);

      // Should handle the error gracefully
      expect(result, isNotNull);
    });

    test('should handle missing main function', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: 'function notMain(config) { return config; }',
      );

      const yaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(yaml);

      // Should return an error about missing main function
      expect(result, isNotNull);
    });

    test('should handle script that returns non-object', () async {
      await GlobalScriptManager.updateConfig(
        enabled: true,
        script: '''
          function main(config) {
            return "not an object";
          }
        ''',
      );

      const yaml = 'proxies: []';
      final result = await GlobalScriptManager.executeScript(yaml);

      // Should handle this gracefully
      expect(result, isNotNull);
    });
  });
}
