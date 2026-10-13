// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get title => '你好';

  @override
  String get helloWorld => '你好世界!';

  @override
  String rustDemo(String greetResult, String addResult) {
    return '操作: 调用 Rust `greet(\"Tom\")`\n结果: $greetResult\n\n1 + 2 = $addResult';
  }
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get title => '你好';

  @override
  String get helloWorld => '你好世界!';

  @override
  String rustDemo(String greetResult, String addResult) {
    return '操作: 调用 Rust `greet(\"Tom\")`\n结果: $greetResult\n\n1 + 2 = $addResult';
  }
}
