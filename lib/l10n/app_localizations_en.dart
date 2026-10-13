// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => '你好';

  @override
  String get helloWorld => '你好世界!';

  @override
  String rustDemo(String greetResult, String addResult) {
    return '操作: 调用 Rust `greet(\"Tom\")`\n结果: $greetResult\n\n1 + 2 = $addResult';
  }
}
