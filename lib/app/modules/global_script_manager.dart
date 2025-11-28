// ignore_for_file: unused_catch_stack, empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clashmi/app/runtime/return_result.dart';
import 'package:clashmi/app/utils/file_utils.dart';
import 'package:clashmi/app/utils/log.dart';
import 'package:clashmi/app/utils/path_utils.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:yaml/yaml.dart';

class GlobalScriptSetting {
  GlobalScriptSetting({
    this.enabled = false,
    this.remark = "",
    this.script = "",
  });

  bool enabled = false;
  String remark = "";
  String script = "";

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'remark': remark,
        'script': script,
      };

  void fromJson(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    enabled = map['enabled'] ?? false;
    remark = map['remark'] ?? '';
    script = map['script'] ?? '';
  }
}

class GlobalScriptManager {
  static final GlobalScriptSetting _config = GlobalScriptSetting();
  static final List<void Function()> onEventChanged = [];
  static bool _saving = false;
  static JavascriptRuntime? _jsRuntime;

  static Future<void> init() async {
    await load();
    _initJsRuntime();
  }

  static void _initJsRuntime() {
    try {
      _jsRuntime = getJavascriptRuntime();
    } catch (err) {
      Log.w("GlobalScriptManager._initJsRuntime exception ${err.toString()}");
    }
  }

  static Future<void> uninit() async {
    _jsRuntime?.dispose();
    _jsRuntime = null;
  }

  static Future<void> reload() async {
    await load();
  }

  static Future<void> save() async {
    if (_saving) {
      return;
    }
    _saving = true;
    String filePath = await PathUtils.globalScriptConfigFilePath();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String content = encoder.convert(_config);
    try {
      await File(filePath).writeAsString(content, flush: true);
    } catch (err, stacktrace) {
      Log.w("GlobalScriptManager.save exception ${err.toString()} ");
    }
    _saving = false;
  }

  static Future<void> load() async {
    String filePath = await PathUtils.globalScriptConfigFilePath();
    var file = File(filePath);
    bool exists = await file.exists();
    if (exists) {
      try {
        String content = await file.readAsString();
        if (content.isNotEmpty) {
          var config = jsonDecode(content);
          _config.fromJson(config);
        }
      } catch (err, stacktrace) {
        Log.w("GlobalScriptManager.load exception ${err.toString()} ");
      }
    } else {
      await save();
    }
  }

  static GlobalScriptSetting getConfig() {
    return _config;
  }

  static bool isEnabled() {
    return _config.enabled;
  }

  static String getScript() {
    return _config.script;
  }

  static String getRemark() {
    return _config.remark;
  }

  static Future<void> setEnabled(bool enabled) async {
    if (_config.enabled == enabled) {
      return;
    }
    _config.enabled = enabled;
    await save();
    for (var event in onEventChanged) {
      event();
    }
  }

  static Future<void> setScript(String script) async {
    _config.script = script;
    await save();
    for (var event in onEventChanged) {
      event();
    }
  }

  static Future<void> setRemark(String remark) async {
    _config.remark = remark;
    await save();
    for (var event in onEventChanged) {
      event();
    }
  }

  static Future<void> updateConfig({
    bool? enabled,
    String? script,
    String? remark,
  }) async {
    bool changed = false;
    if (enabled != null && _config.enabled != enabled) {
      _config.enabled = enabled;
      changed = true;
    }
    if (script != null && _config.script != script) {
      _config.script = script;
      changed = true;
    }
    if (remark != null && _config.remark != remark) {
      _config.remark = remark;
      changed = true;
    }

    if (changed) {
      await save();
      for (var event in onEventChanged) {
        event();
      }
    }
  }

  /// Execute the global script on a YAML config
  /// Returns the modified YAML string, or the original if script is disabled or fails
  static Future<ReturnResult<String>> executeScript(String yamlContent) async {
    if (!_config.enabled || _config.script.isEmpty) {
      return ReturnResult(data: yamlContent);
    }

    try {
      // Parse YAML to Map
      final dynamic yamlData = loadYaml(yamlContent);
      Map<String, dynamic> configMap;

      if (yamlData is Map) {
        configMap = Map<String, dynamic>.from(yamlData as Map);
      } else {
        return ReturnResult(
          error: ReturnResultError("Invalid YAML format: not a map"),
        );
      }

      // Convert to JSON for JavaScript
      final configJson = jsonEncode(configMap);

      // Ensure JS runtime is initialized
      if (_jsRuntime == null) {
        _initJsRuntime();
      }

      if (_jsRuntime == null) {
        return ReturnResult(
          error: ReturnResultError("JavaScript runtime not initialized"),
        );
      }

      // Wrap the script execution in a try-catch
      final wrappedScript = '''
        (function() {
          try {
            var config = JSON.parse('${_escapeForJs(configJson)}');
            ${_config.script}
            var result = main(config);
            return JSON.stringify(result);
          } catch (e) {
            throw new Error('Script execution error: ' + e.message);
          }
        })()
      ''';

      final jsResult = _jsRuntime!.evaluate(wrappedScript);

      if (jsResult.isError) {
        return ReturnResult(
          error: ReturnResultError("Script error: ${jsResult.stringResult}"),
        );
      }

      // Parse the result back to Dart Map
      final resultJson = jsResult.stringResult;
      final resultMap = jsonDecode(resultJson) as Map<String, dynamic>;

      // Convert Map back to YAML
      final resultYaml = _mapToYaml(resultMap);

      return ReturnResult(data: resultYaml);
    } catch (err, stacktrace) {
      Log.w("GlobalScriptManager.executeScript exception: ${err.toString()}");
      return ReturnResult(
        error: ReturnResultError("Failed to execute script: ${err.toString()}"),
      );
    }
  }

  /// Escape string for JavaScript string literal
  static String _escapeForJs(String str) {
    return str
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Convert Dart Map to YAML string
  static String _mapToYaml(Map<String, dynamic> map, [int indent = 0]) {
    final buffer = StringBuffer();
    final indentStr = '  ' * indent;

    map.forEach((key, value) {
      buffer.write(indentStr);
      buffer.write('$key: ');

      if (value is Map) {
        buffer.write('\n');
        buffer.write(_mapToYaml(Map<String, dynamic>.from(value as Map), indent + 1));
      } else if (value is List) {
        buffer.write('\n');
        for (var item in value) {
          buffer.write('$indentStr  - ');
          if (item is Map) {
            buffer.write('\n');
            final itemYaml = _mapToYaml(Map<String, dynamic>.from(item as Map), indent + 2);
            // Remove the first indent since we already added the dash
            final lines = itemYaml.split('\n');
            for (int i = 0; i < lines.length; i++) {
              if (i > 0) {
                buffer.write('$indentStr    ');
              }
              buffer.write(lines[i].replaceFirst(RegExp(r'^  '), ''));
              if (i < lines.length - 1) {
                buffer.write('\n');
              }
            }
            buffer.write('\n');
          } else {
            buffer.write(_formatValue(item));
            buffer.write('\n');
          }
        }
      } else {
        buffer.write(_formatValue(value));
        buffer.write('\n');
      }
    });

    return buffer.toString();
  }

  /// Format a value for YAML output
  static String _formatValue(dynamic value) {
    if (value == null) {
      return 'null';
    } else if (value is String) {
      // Check if string needs quoting
      if (value.contains(':') ||
          value.contains('#') ||
          value.contains('[') ||
          value.contains(']') ||
          value.contains('{') ||
          value.contains('}') ||
          value.contains(',') ||
          value.startsWith(' ') ||
          value.endsWith(' ') ||
          value.contains('\n')) {
        return '"${value.replaceAll('"', '\\"')}"';
      }
      return value;
    } else if (value is bool) {
      return value.toString();
    } else if (value is num) {
      return value.toString();
    } else {
      return value.toString();
    }
  }

  /// Test the script with a sample config
  static Future<ReturnResult<String>> testScript(
      String script, String yamlContent) async {
    final tempConfig = GlobalScriptSetting(
      enabled: true,
      script: script,
    );

    // Temporarily swap config
    final originalScript = _config.script;
    final originalEnabled = _config.enabled;
    _config.script = tempConfig.script;
    _config.enabled = tempConfig.enabled;

    try {
      final result = await executeScript(yamlContent);
      return result;
    } finally {
      // Restore original config
      _config.script = originalScript;
      _config.enabled = originalEnabled;
    }
  }
}
