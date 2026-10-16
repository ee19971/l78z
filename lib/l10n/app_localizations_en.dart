// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabFestivals => 'Festivals';

  @override
  String get tabCalculator => 'Date Calc';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTools => 'Tools';

  @override
  String get tabCountdown => 'Countdown';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String appInitFailed(String error) {
    return 'Init failed: $error\nPlease check the browser console or whether COOP/COEP headers are missing.';
  }

  @override
  String get pickerSearchHint =>
      'Search country or capital, e.g. Japan, Paris, asia';

  @override
  String pickerNoMatch(String query) {
    return 'No country or capital matches \"$query\"';
  }

  @override
  String get setRegionTitle => 'Language & Region';

  @override
  String get setDisplayTitle => 'Display';

  @override
  String get setLanguage => 'Language';

  @override
  String get setFollowSystem => 'Follow system';

  @override
  String get setLanguageZh => '简体中文';

  @override
  String get setLanguageEn => 'English';

  @override
  String get setTimeZoneCity => 'Time zone city';

  @override
  String get setAutoDetect => 'Auto detected';

  @override
  String get setFont => 'Font';

  @override
  String get setFontSystem => 'System default';

  @override
  String get setFontWenKai => 'LXGW WenKai';

  @override
  String get setFontSans => 'Noto Sans SC';

  @override
  String get setFontSerif => 'Noto Serif SC';

  @override
  String get setFontCustom => 'Custom font';

  @override
  String get setFontCustomPick => 'Choose file…';

  @override
  String get setFontCustomNone => 'No font file chosen';

  @override
  String get setFontCustomMissing => 'File missing, reverted to system default';

  @override
  String setFontSize(int percent) {
    return 'Font size  $percent%';
  }

  @override
  String get setFontPreview => '永 Aa 互传助手 2026 — the quick brown fox';

  @override
  String get mainTitle => 'Home';

  @override
  String get mainOcr => 'OCR Scan';

  @override
  String get mainQrScan => 'QR Scan';

  @override
  String get mainStopwatch => 'Stopwatch';

  @override
  String get mainOnThisDay => 'Today in History';

  @override
  String get mainTzNotReady => 'Timezone data not ready';

  @override
  String get mainToday => 'Today!';

  @override
  String get mainTomorrow => 'Tomorrow';

  @override
  String mainInDays(int days) {
    return '$days days to go';
  }

  @override
  String get mainTodayTitle => 'Today';

  @override
  String get mainSolar => 'Solar';

  @override
  String get mainLunar => 'Lunar';

  @override
  String get mainGanZhi => 'Sexagenary';

  @override
  String get mainZodiac => 'Zodiac';

  @override
  String get mainJieQi => 'Solar term';

  @override
  String mainNextFestival(String name) {
    return 'Next: $name';
  }

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolsScan => 'Scan';

  @override
  String get toolsScanSub => 'Scan codes / decode images / OCR';

  @override
  String get toolsQr => 'QR / Barcode';

  @override
  String get toolsQrSub => '14 formats, with WiFi & business card templates';

  @override
  String get toolsLan => 'LAN Transfer';

  @override
  String get toolsLanSub => 'Transfer text & files between phone and PC';

  @override
  String get toolsSettings => 'Settings';

  @override
  String get setThemeColor => 'Theme color';

  @override
  String get setThemeZhusha => 'Cinnabar';

  @override
  String get setThemeYanzhi => 'Rouge';

  @override
  String get setThemeDailan => 'Dai Blue';

  @override
  String get setThemeShiqing => 'Azurite';

  @override
  String get setThemeZhuqing => 'Bamboo Green';

  @override
  String get setThemeXiangse => 'Straw Yellow';

  @override
  String otdLoadFailed(String error) {
    return 'Failed to load data: $error';
  }

  @override
  String get otdEvents => 'Events';

  @override
  String get otdBirths => 'Born today';

  @override
  String get otdDeaths => 'Died today';

  @override
  String otdCount(int n) {
    return '$n items';
  }

  @override
  String otdSummary(int events, int births, int deaths) {
    return '$events events · $births born · $deaths died';
  }

  @override
  String get otdEmpty => 'No entries recorded for this day';

  @override
  String get otdNoData => 'No data for this date';

  @override
  String get swTitle => 'Stopwatch';

  @override
  String get swStart => 'Start';

  @override
  String get swPause => 'Pause';

  @override
  String get swResume => 'Resume';

  @override
  String get swReset => 'Reset';

  @override
  String get swLap => 'Lap';

  @override
  String get swHint => 'Tap \"Lap\" while running to record laps';

  @override
  String swLapN(int n) {
    return 'Lap $n';
  }

  @override
  String get swTotal => 'Total';

  @override
  String get calcTitle => 'Date Calculator';

  @override
  String get calcTabProject => 'Project';

  @override
  String get calcTabDiff => 'Difference';

  @override
  String get calcTabTime => 'Time';

  @override
  String get calcDaysLabel => 'Days apart';

  @override
  String get calcUnitDays => 'days';

  @override
  String get calcHintNegative => 'May be negative';

  @override
  String get calcResult => 'Result';

  @override
  String calcNDays(int n) {
    return '$n days';
  }

  @override
  String calcLater(int n) {
    return 'End is $n days after start';
  }

  @override
  String calcEarlier(int n) {
    return 'End is $n days before start';
  }

  @override
  String get calcHoursLabel => 'Hours apart';

  @override
  String get calcUnitHours => 'h';

  @override
  String get calcMinutesLabel => 'Minutes apart';

  @override
  String get calcUnitMinutes => 'min';

  @override
  String get calcLunar => 'Lunar';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonClose => 'Close';

  @override
  String get cdTitle => 'Countdown';

  @override
  String get cdAdd => 'Add Countdown';

  @override
  String get cdEditTitle => 'Edit Countdown';

  @override
  String cdOpFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String cdSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String cdLoadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String cdDeleteTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get cdDeleteMsg => 'This cannot be undone.';

  @override
  String get commonDayUnit => 'days';

  @override
  String get cdRemain => 'Left';

  @override
  String get cdPassed => 'Passed';

  @override
  String get cdHas => 'After';

  @override
  String get cdUntilNext => 'Until next';

  @override
  String get cdToday => 'Today!';

  @override
  String get cdModeCountdown => 'Down';

  @override
  String get cdModeCountup => 'Up';

  @override
  String get cdModeYearly => 'Yearly';

  @override
  String get cdModeCountdownFull => 'Countdown: days left until target';

  @override
  String get cdModeCountupFull => 'Count up: days since target';

  @override
  String get cdModeYearlyFull => 'Yearly: birthdays, anniversaries';

  @override
  String cdTotal(int n) {
    return '$n countdowns';
  }

  @override
  String get cdEmpty => 'No countdowns yet';

  @override
  String get cdEmptyHint =>
      'Keep the important days here; widgets will watch them for you';

  @override
  String get cdPin => 'Pin';

  @override
  String get cdUnpin => 'Unpin';

  @override
  String get cdPinHint =>
      'Pinned items appear first and are preferred by widgets';

  @override
  String get cdPinSwitchHint =>
      'Appear first in the list; preferred by widgets';

  @override
  String get cdFieldTitle => 'Title';

  @override
  String get cdFieldTitleHint => 'e.g. Exam day, wedding anniversary';

  @override
  String get cdFieldTarget => 'Target date';

  @override
  String get cdFieldMode => 'Counting mode';

  @override
  String get cdFieldColor => 'Theme color';

  @override
  String get cdFieldNote => 'Note (optional)';

  @override
  String get cdErrTitleRequired => 'Please enter a title';

  @override
  String cdQuote(String text) {
    return '“$text”';
  }

  @override
  String get cdLifeTitle => 'Life Progress';

  @override
  String get cdLifeSubtitle =>
      'Set your birthday to show progress here and in widgets';

  @override
  String get cdLifeEdit => 'Edit';

  @override
  String cdLifePassed(String pct) {
    return '$pct% passed';
  }

  @override
  String cdLifeLived(int days) {
    return '$days days lived';
  }

  @override
  String cdLifeRemaining(int age, int days) {
    return '$days days until age $age';
  }

  @override
  String get cdLifeSetupTitle => 'Life Progress Setup';

  @override
  String get cdBirthday => 'Birthday';

  @override
  String get cdNotSet => 'Not set';

  @override
  String get cdLifespanField => 'Lifespan (years)';

  @override
  String get cdLifespanHelp => 'Used to compute total days; change anytime';

  @override
  String get cdQuoteField => 'Motto (optional)';

  @override
  String get cdQuoteHelp => 'Shown atop the progress card and widgets';

  @override
  String get cdDefaultQuote => 'Walk today or run tomorrow.';

  @override
  String get cdErrPickBirthday => 'Please pick your birthday';

  @override
  String get cdErrLifespan => 'Lifespan must be a positive integer';

  @override
  String get cdClearLife => 'Clear life progress';

  @override
  String get commonToday => 'Today';

  @override
  String get festTitle => 'Festivals';

  @override
  String get festRemain => 'Left';

  @override
  String festNoMatch(String query) {
    return 'No festival or solar term named \"$query\"';
  }

  @override
  String get festEmpty => 'No festivals or solar terms in the coming year';

  @override
  String festHiddenNotice(int n) {
    return '$n are hidden — restore them in settings';
  }

  @override
  String get festSearch => 'Search';

  @override
  String get festCloseSearch => 'Close search';

  @override
  String get festSearchHint => 'Search festival or solar term';

  @override
  String get festBadgeJieQi => 'Solar term';

  @override
  String get festBadgeFestival => 'Festival';

  @override
  String get festColorfulBg => 'Colorful backgrounds';

  @override
  String get festColorfulBgSub => 'Plain cards when off';

  @override
  String get festShowEmoji => 'Show emoji';

  @override
  String get festShowEmojiSub => 'Append an emoji after the festival name';

  @override
  String get festCoverColor => 'Cover color';

  @override
  String get festCoverRotate => 'Rotate';

  @override
  String get festCoverRandom => 'Random';

  @override
  String get festCoverRotateSub => 'Cycle through eight colors in order';

  @override
  String get festCoverRandomSub => 'Shuffled once a day; stable within the day';

  @override
  String get festHiddenTitle => 'Hidden festivals';

  @override
  String get festHiddenNone => 'Nothing is hidden';

  @override
  String festHiddenCount(int n) {
    return '$n hidden';
  }

  @override
  String festGroupVisible(int n) {
    return 'Visible ($n)';
  }

  @override
  String festGroupHidden(int n) {
    return 'Hidden ($n)';
  }

  @override
  String get calViewYear => 'Year view';

  @override
  String get calViewMonth => 'Month view';

  @override
  String get calViewWeek => 'Week view';

  @override
  String get calViewDay => 'Day view';

  @override
  String get calWeekHeader => 'SMTWTFS';

  @override
  String calYearTitle(int year) {
    return '$year';
  }

  @override
  String calPrev(String tag) {
    return 'Previous $tag';
  }

  @override
  String calNext(String tag) {
    return 'Next $tag';
  }

  @override
  String get calUnitYear => 'year';

  @override
  String get calUnitMonth => 'month';

  @override
  String get calUnitWeek => 'week';

  @override
  String get calUnitDay => 'day';

  @override
  String calMonthTitle(String month) {
    return '$month';
  }

  @override
  String calDaysCount(int days) {
    return '$days days';
  }

  @override
  String get calFestival => 'Festival';

  @override
  String get calDistance => 'From today';

  @override
  String calPassedDays(int days) {
    return '$days days ago';
  }

  @override
  String get calSettings => 'Calendar display';

  @override
  String get calCellLabelTitle => 'Day cell caption';

  @override
  String get calCellJieqiLunar => 'Solar term + lunar date';

  @override
  String get calCellFull => 'Full (festival, solar term, lunar date)';

  @override
  String get calCellLunarOnly => 'Lunar date only';

  @override
  String get calCellHidden => 'Hidden';

  @override
  String get calWeekStartTitle => 'Week starts on';

  @override
  String get calWeekStartSunday => 'Sunday';

  @override
  String get calWeekStartMonday => 'Monday';

  @override
  String get calOtherCalendarsTitle => 'Other calendars';

  @override
  String get calTao => 'Taoist calendar';

  @override
  String get calFoto => 'Buddhist calendar';

  @override
  String get commonNone => 'None';

  @override
  String get scanTitlePair => 'Pair by QR';

  @override
  String get scanTitleOcr => 'OCR Scan';

  @override
  String get scanTitleScan => 'Scan';

  @override
  String get scanTakePhoto => 'Camera';

  @override
  String get scanPickGallery => 'From album';

  @override
  String get scanPickImage => 'Pick image';

  @override
  String get scanActionOcr => 'Recognize text (OCR)';

  @override
  String get scanActionBarcode => 'Scan QR / barcode';

  @override
  String get scanStageRead => 'Loading image';

  @override
  String get scanStagePrepareModel => 'Preparing OCR model';

  @override
  String get scanStageDownloadModel =>
      'Downloading OCR model (~132MB, first time)';

  @override
  String get scanStageRecognizing => 'Recognizing text';

  @override
  String get scanStageDone => 'Recognition done';

  @override
  String get scanStageDecoding => 'Decoding QR / barcode';

  @override
  String get scanStageDecoded => 'Decoded';

  @override
  String get scanModelDownloadTitle => 'Download OCR model';

  @override
  String scanModelDownloadBody(int size) {
    return 'Text recognition needs a model download (~${size}MB, one time only), then everything works offline. Wi-Fi is recommended.';
  }

  @override
  String get scanModelDownloadAction => 'Start download';

  @override
  String scanModelDownloadFailed(String error) {
    return 'Model download failed: $error';
  }

  @override
  String scanFailed(String stage, String error) {
    return 'Failed at $stage: $error';
  }

  @override
  String get scanNoCode =>
      'No code found — face the screen, avoid glare, get closer';

  @override
  String scanSavedDevice(String name, String ip) {
    return 'Saved device $name ($ip)';
  }

  @override
  String get scanOcrResult => 'OCR Result';

  @override
  String get scanNoText => '(no text recognized)';

  @override
  String get scanDecodeResult => 'Decode Result';

  @override
  String scanStagePercent(String stage, int percent) {
    return '$stage ($percent%)';
  }

  @override
  String get qrTitle => 'Generate QR / Barcode';

  @override
  String get qrTemplateTitle => 'Content template';

  @override
  String get qrPreview => 'Preview';

  @override
  String get qrGenerate => 'Generate';

  @override
  String get qrGenerating => 'Generating…';

  @override
  String get qrNotSet => 'Not set';

  @override
  String get qrGroupMatrix => 'QR / matrix codes';

  @override
  String get qrGroupStacked => 'Stacked 2D';

  @override
  String get qrGroupRetail => 'Retail barcodes';

  @override
  String get qrGroupIndustrial => 'Logistics / industrial';

  @override
  String get qrGroupOther => 'Other';

  @override
  String get qrNameQrCode => 'QR code';

  @override
  String get qrDim2 => '2D';

  @override
  String get qrDim1 => '1D';

  @override
  String get qrHintQrCode => 'Any text, URLs, Chinese included';

  @override
  String get qrHintDataMatrix => 'Any text; tiny, often on small parts';

  @override
  String get qrHintAztec => 'Any text; common on boarding passes & tickets';

  @override
  String get qrHintPdf417 => 'Any text; holds more, common on ID cards';

  @override
  String get qrHintEan13 => '12 or 13 digits; last is a check digit';

  @override
  String get qrHintEan8 => '7 or 8 digits';

  @override
  String get qrHintUpcA => '11 or 12 digits';

  @override
  String get qrHintUpcE => '7 or 8 digits; first must be 0 or 1';

  @override
  String get qrHintCode128 => 'Any ASCII text; most common on parcels';

  @override
  String get qrHintCode39 => '0-9 A-Z plus - . \$ / + % and space';

  @override
  String get qrHintCode93 => 'Any ASCII text';

  @override
  String get qrHintItf => 'Even number of digits; common on cartons';

  @override
  String get qrHintCodabar => 'Digits with A/B/C/D start/stop, e.g. A123456B';

  @override
  String get qrHintTelepen => 'Any ASCII text; rarely used';

  @override
  String get qrTplCustom => 'Custom';

  @override
  String get qrTplWifi => 'WiFi';

  @override
  String get qrTplUrl => 'URL';

  @override
  String get qrTplVcard => 'Contact';

  @override
  String get qrTplPhone => 'Phone';

  @override
  String get qrTplSms => 'SMS';

  @override
  String get qrTplEmail => 'Email';

  @override
  String get qrTplCalendar => 'Calendar';

  @override
  String get qrTplGeo => 'Location';

  @override
  String qrFormatLabel(String name, String dim) {
    return '$name ($dim)';
  }

  @override
  String qrContentReq(String hint) {
    return 'Content rules: $hint';
  }

  @override
  String qrSelfOnly(String name) {
    return 'Note: $name can only be generated here — the built-in scanner cannot read it; other scanner apps can.';
  }

  @override
  String qrRequirement(String name, String hint) {
    return '\"$name\" requires: $hint';
  }

  @override
  String qrFillField(String label) {
    return 'Please fill in $label';
  }

  @override
  String get qrFillContent => 'Please enter content';

  @override
  String qrNoDigits(String label) {
    return 'No usable digits in $label';
  }

  @override
  String get qrPickStart => 'Please pick a start time';

  @override
  String get qrGeoNotNumber => 'Latitude/longitude must be numbers';

  @override
  String get qrFieldContent => 'Content';

  @override
  String get qrFieldSsid => 'Network name (SSID)';

  @override
  String get qrFieldPass => 'Password';

  @override
  String get qrPassHint => 'Leave empty when security is None';

  @override
  String get qrFieldSecurity => 'Security';

  @override
  String get qrEncNone => 'None';

  @override
  String get qrFieldUrl => 'URL';

  @override
  String get qrUrlHint => 'e.g. example.com; https:// is added automatically';

  @override
  String get qrFieldName => 'Name';

  @override
  String get qrFieldMobile => 'Mobile';

  @override
  String get qrFieldEmail => 'Email';

  @override
  String get qrFieldOrg => 'Organization';

  @override
  String get qrFieldJob => 'Job title';

  @override
  String get qrFieldPhoneNumber => 'Phone number';

  @override
  String get qrPhoneHint => 'Spaces and dashes are removed automatically';

  @override
  String get qrFieldSmsTo => 'Recipient number';

  @override
  String get qrFieldSmsBody => 'Message';

  @override
  String get qrFieldMailTo => 'Recipient email';

  @override
  String get qrFieldSubject => 'Subject';

  @override
  String get qrFieldBody => 'Body';

  @override
  String get qrFieldCalTitle => 'Title';

  @override
  String get qrStartTime => 'Start time';

  @override
  String get qrEndTime => 'End time';

  @override
  String get qrEndHint => 'Defaults to 1 hour after start if left empty';

  @override
  String get qrFieldLocation => 'Location';

  @override
  String get qrFieldLat => 'Latitude';

  @override
  String get qrFieldLng => 'Longitude';

  @override
  String get lanTitle => 'LAN Transfer';

  @override
  String get lanReceiver => 'Receiver';

  @override
  String get lanSender => 'Sender';

  @override
  String get lanStartServer => 'Start server';

  @override
  String get lanStopServer => 'Stop server';

  @override
  String get lanServerKeepAlive =>
      'The server keeps running after you leave this page; peers can still connect';

  @override
  String get lanQrHint => 'Scan this QR code with another device to pair';

  @override
  String get lanUnpaired => 'No paired device';

  @override
  String lanPeerInfo(String name, String addr) {
    return 'Target: $name ($addr)';
  }

  @override
  String get lanPair => 'Pair by QR';

  @override
  String get lanTest => 'Test';

  @override
  String get lanTextContent => 'Text content';

  @override
  String get lanSendText => 'Send text';

  @override
  String get lanSendFile => 'Send file';

  @override
  String get lanLogTitle => 'Log';

  @override
  String get lanLsTitle => 'LocalSend devices';

  @override
  String get lanLsOff => 'Compat layer not running';

  @override
  String lanLsPortInfo(int port) {
    return 'Port $port; interoperates with official LocalSend';
  }

  @override
  String lanLsNotice(String error) {
    return 'Note: $error';
  }

  @override
  String get lanNoDevice =>
      'No devices found. Make sure both devices are on the same network and wait a few seconds';

  @override
  String lanSendToAlias(String alias) {
    return 'Send file to $alias';
  }

  @override
  String lanSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String lanSnackSent(String name) {
    return 'Sent $name';
  }

  @override
  String get lanLogLsDisabled => 'LocalSend compat layer disabled in settings';

  @override
  String lanLogLsStarted(int port) {
    return 'LocalSend compat layer started on port $port; official LocalSend can discover this device';
  }

  @override
  String lanLogLsStartedNoMcast(int port, String reason) {
    return 'LocalSend compat layer started (port $port) but multicast is unavailable: $reason; only active scans can find this device';
  }

  @override
  String lanLogLsStartFailed(String error) {
    return 'Failed to start LocalSend compat layer: $error';
  }

  @override
  String get lanMcastUnavailable => 'multicast unavailable';

  @override
  String get lanUnknown => 'unknown reason';

  @override
  String lanLogLsDiscovered(String alias, String addr) {
    return 'Discovered LocalSend device: $alias ($addr)';
  }

  @override
  String lanLogLsRegistered(String alias, String ip) {
    return '$alias registered to this device via LocalSend ($ip)';
  }

  @override
  String lanLogLsIncoming(String alias, int n, String ip, String size) {
    return '$alias wants to push $n files ($ip, $size total)';
  }

  @override
  String lanLogLsReceived(String name) {
    return 'LocalSend received file: $name';
  }

  @override
  String lanLogLsRecvFailed(String name, String error) {
    return 'LocalSend failed to receive $name: $error';
  }

  @override
  String lanLogLsSessionEnd(int ok, int fail) {
    return 'LocalSend session ended: $ok ok, $fail failed';
  }

  @override
  String lanLogLsError(String message) {
    return 'LocalSend: $message';
  }

  @override
  String lanLogTextReceived(String kind, String from, String text) {
    return 'Received text [$kind] from $from:\n$text';
  }

  @override
  String lanLogReverseRegistered(String name, String addr) {
    return '✓ $name registered back; you can now send both ways\n$addr';
  }

  @override
  String lanLogServerStarted(String addr) {
    return 'Server started: $addr';
  }

  @override
  String lanLogServerPort(int port) {
    return 'Server started on port $port';
  }

  @override
  String lanLogServerAlts(String list) {
    return 'Alternate addresses: $list';
  }

  @override
  String get lanLogServerStopped => 'Server stopped';

  @override
  String lanLogStartFailed(String error) {
    return 'Failed to start: $error';
  }

  @override
  String get lanLogSavedDownloads => '\nSaved to the system Downloads folder';

  @override
  String lanLogSaveFailed(String error) {
    return '\n⚠ Failed to save to Downloads ($error); the file stays in app-private storage';
  }

  @override
  String lanLogFileReceived(
    String from,
    String name,
    String size,
    String path,
    String note,
  ) {
    return 'Received $name ($size) from $from\nSaved: $path$note';
  }

  @override
  String lanLogTestFailed(String error) {
    return 'Connection test error: $error';
  }

  @override
  String lanLogPeerUnreachable(String name, String ips) {
    return '⚠ Cannot reach $name (tried $ips).\nMake sure both devices are on the same Wi-Fi/LAN and the peer\'s receive server is running';
  }

  @override
  String lanLogConnOk(String addr) {
    return '✓ Connected $addr';
  }

  @override
  String lanLogConnOkAlt(String addr, String preferred) {
    return '✓ Connected via reachable address $addr (preferred $preferred from the QR is unreachable)';
  }

  @override
  String lanLogNeedServer(String name) {
    return '⚠ This device\'s receive server is not running, so $name cannot send to it.\nTap \"Start server\" above and ask the peer to scan your QR code again';
  }

  @override
  String lanLogToldPeer(String name) {
    return '✓ Told $name this device\'s address; both sides can now send';
  }

  @override
  String lanLogReverseFailed(String name, String error) {
    return '⚠ Could not register back to $name: $error';
  }

  @override
  String lanLogPaired(String name, String addr) {
    return 'Paired device: $name ($addr)';
  }

  @override
  String lanLogTextSent(String name) {
    return 'Sent text to $name';
  }

  @override
  String lanLogSendTextFailed(String error) {
    return '⚠ Failed to send text: $error';
  }

  @override
  String lanLogFileSent(String name, String to) {
    return 'Sent file $name to $to';
  }

  @override
  String lanLogSendFileFailed(String error) {
    return '⚠ Failed to send file: $error';
  }

  @override
  String lanLogLsSent(String name, String alias) {
    return 'Sent $name to $alias via LocalSend';
  }

  @override
  String lanLogLsSendFailed(String error) {
    return 'LocalSend send failed: $error';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutNoLan => 'No LAN address detected';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutLoadFailed => 'Failed to read device info';

  @override
  String get aboutSectionDevice => 'This device';

  @override
  String get aboutLocalIp => 'Local IP';

  @override
  String get aboutListenPort => 'Listen port';

  @override
  String get aboutFingerprint => 'Device fingerprint';

  @override
  String get aboutFingerprintHint =>
      'Created when the LocalSend compat layer is on; peers use it to identify this device';

  @override
  String get aboutSectionLicense => 'License';

  @override
  String get aboutLicenseTitle =>
      'This project is licensed under the Apache License 2.0';

  @override
  String get aboutLicenseBody =>
      'Commercial use, modification and distribution are allowed.\nWhen redistributing copies, keep the LICENSE and NOTICE files of the repository.\n\nThe full license text is in the LICENSE file at the project root.';

  @override
  String get aboutSectionThirdParty => 'Third-party components';

  @override
  String get aboutSectionFonts => 'Bundled fonts';

  @override
  String get commonSaved => 'Saved';

  @override
  String commonSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get setConfigLoadFailed => 'Failed to load config';

  @override
  String get setSectionTransfer => 'Transfer';

  @override
  String get setDeviceName => 'Device name';

  @override
  String get setDeviceNameHelp => 'Shown in the peer\'s device list';

  @override
  String get setPortLabel => 'Listen port';

  @override
  String setPortHelp(int port) {
    return 'Default $port. Falls back to another port when occupied; transfers are unaffected';
  }

  @override
  String get setPinLabel => 'Transfer PIN (optional)';

  @override
  String get setPinHelp =>
      'Leave empty to skip verification. When set, peers must enter it to push files';

  @override
  String get setVerifyHash => 'Verify file hashes';

  @override
  String get setVerifyHashSub =>
      'Compare received files against the sender\'s SHA-256';

  @override
  String get setLsCompat => 'Enable LocalSend compatibility';

  @override
  String get setLsCompatSub =>
      'Auto-discover official LocalSend on the same network: no QR code needed';

  @override
  String get setSectionDesktopWidget => 'Desktop widget';

  @override
  String get setDesktopWidgetCard => 'Show countdown card';

  @override
  String get setDesktopWidgetSub =>
      'Pin countdown cards to the desktop; starts with Windows';

  @override
  String get setDesktopWidgetErr =>
      'Widget program l78z_widget.exe not found (it must be next to the app)';

  @override
  String get setSectionAbout => 'About';

  @override
  String get setAboutTitle => 'About 互传助手';

  @override
  String get setAboutSub => 'Version, license and third-party components';

  @override
  String onBcLabel(int year) {
    return '$year BC';
  }
}
