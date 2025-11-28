import 'package:clashmi/app/modules/global_script_manager.dart';
import 'package:clashmi/i18n/strings.g.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:clashmi/screens/theme_config.dart';
import 'package:clashmi/screens/widgets/framework.dart';
import 'package:clashmi/screens/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

class GlobalScriptEditScreen extends LasyRenderingStatefulWidget {
  static RouteSettings routSettings() {
    return const RouteSettings(name: "GlobalScriptEditScreen");
  }

  const GlobalScriptEditScreen({super.key});

  @override
  State<GlobalScriptEditScreen> createState() => _GlobalScriptEditScreenState();
}

class _GlobalScriptEditScreenState
    extends LasyRenderingState<GlobalScriptEditScreen> {
  late CodeLineEditingController _codeController;
  final _textControllerRemark = TextEditingController();
  final _focusNode = FocusNode();
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    final config = GlobalScriptManager.getConfig();
    _enabled = config.enabled;
    _textControllerRemark.text = config.remark;
    _codeController = CodeLineEditingController.fromText(config.script);

    _focusNode.onKeyEvent = ((_, event) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final key = event.logicalKey;
      if (!keys.contains(key)) {
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _codeController.moveCursor(AxisDirection.up);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _codeController.moveCursor(AxisDirection.down);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _codeController.moveCursor(AxisDirection.left);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _codeController.moveCursor(AxisDirection.right);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _textControllerRemark.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tcontext = Translations.of(context);
    Size windowSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Column(
            children: [
              // Header row with back button, title, and save button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 50,
                      height: 30,
                      child: Icon(
                        Icons.arrow_back_ios_outlined,
                        size: 26,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: windowSize.width - 50 * 2,
                    child: Text(
                      tcontext.meta.globalScript,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: ThemeConfig.kFontWeightTitle,
                          fontSize: ThemeConfig.kFontSizeTitle),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      onTapSave();
                    },
                    child: const SizedBox(
                      width: 50,
                      height: 30,
                      child: Icon(
                        Icons.done_outlined,
                        size: 26,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),

              // Settings card with enable toggle and remark field
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    child: Column(
                      children: [
                        // Enable/Disable toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tcontext.meta.globalScriptEnable,
                              style: const TextStyle(fontSize: 16),
                            ),
                            Switch(
                              value: _enabled,
                              onChanged: (value) {
                                setState(() {
                                  _enabled = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Remark field
                        TextFieldEx(
                          controller: _textControllerRemark,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: tcontext.meta.remark,
                            hintText: tcontext.meta.remark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Code editor section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 5, 8, 10),
                            child: Text(
                              tcontext.meta.globalScriptJsCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: CodeEditor(
                              controller: _codeController,
                              focusNode: _focusNode,
                              wordWrap: false,
                              readOnly: false,
                              indicatorBuilder:
                                  (context, editingController, chunkController,
                                      notifier) {
                                return Row(
                                  children: [
                                    DefaultCodeLineNumber(
                                      controller: editingController,
                                      notifier: notifier,
                                    ),
                                    DefaultCodeChunkIndicator(
                                      width: 20,
                                      controller: chunkController,
                                      notifier: notifier,
                                    )
                                  ],
                                );
                              },
                              style: CodeEditorStyle(
                                codeTheme: CodeHighlightTheme(
                                  languages: {
                                    'javascript': CodeHighlightThemeMode(
                                      mode: langJavascript,
                                    ),
                                  },
                                  theme: atomOneLightTheme,
                                ),
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onTapSave() async {
    final config = GlobalScriptManager.getConfig();
    String remarkText = _textControllerRemark.text.trim();
    String scriptText = _codeController.text;

    // Check if anything changed
    if (config.enabled == _enabled &&
        config.remark == remarkText &&
        config.script == scriptText) {
      Navigator.pop(context);
      return;
    }

    // Save the configuration
    try {
      await GlobalScriptManager.updateConfig(
        enabled: _enabled,
        remark: remarkText,
        script: scriptText,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (err) {
      if (mounted) {
        final tcontext = Translations.of(context);
        DialogUtils.showAlertDialog(
          context,
          "${tcontext.meta.globalScriptSaveFailed}: ${err.toString()}",
        );
      }
    }
  }
}
