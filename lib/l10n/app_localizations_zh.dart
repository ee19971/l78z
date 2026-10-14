// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tabFestivals => '节日节气';

  @override
  String get tabCalculator => '日期计算';

  @override
  String get tabHome => '主页面';

  @override
  String get tabTools => '工具';

  @override
  String get tabCountdown => '倒数日';

  @override
  String get tabCalendar => '日历';

  @override
  String appInitFailed(String error) {
    return '初始化失败: $error\n请检查浏览器控制台或查看是否缺少 COOP/COEP 请求头';
  }

  @override
  String get pickerSearchHint => '搜索国家或首都，如 日本、巴黎、asia';

  @override
  String pickerNoMatch(String query) {
    return '没有匹配「$query」的国家或首都';
  }

  @override
  String get setRegionTitle => '语言与地区';

  @override
  String get setDisplayTitle => '显示';

  @override
  String get setLanguage => '语言';

  @override
  String get setFollowSystem => '跟随系统';

  @override
  String get setLanguageZh => '简体中文';

  @override
  String get setLanguageEn => 'English';

  @override
  String get setTimeZoneCity => '时区城市';

  @override
  String get setAutoDetect => '自动检测';

  @override
  String get setFont => '字体';

  @override
  String get setFontSystem => '系统默认';

  @override
  String get setFontSans => '思源黑体';

  @override
  String get setFontSerif => '思源宋体';

  @override
  String setFontSize(int percent) {
    return '字号  $percent%';
  }

  @override
  String get setFontPreview => '永 Aa 互传助手 2026 — the quick brown fox';

  @override
  String get mainTitle => '主页面';

  @override
  String get mainOcr => 'OCR 识别';

  @override
  String get mainQrScan => '二维码扫描';

  @override
  String get mainStopwatch => '秒表';

  @override
  String get mainOnThisDay => '历史上的今天';

  @override
  String get mainTzNotReady => '时区库未就绪';

  @override
  String get mainToday => '就在今天';

  @override
  String get mainTomorrow => '明天';

  @override
  String mainInDays(int days) {
    return '还有 $days 天';
  }

  @override
  String get mainTodayTitle => '今天';

  @override
  String get mainSolar => '公历';

  @override
  String get mainLunar => '农历';

  @override
  String get mainGanZhi => '干支';

  @override
  String get mainZodiac => '生肖';

  @override
  String get mainJieQi => '节气';

  @override
  String mainNextFestival(String name) {
    return '下一个：$name';
  }

  @override
  String get toolsTitle => '工具';

  @override
  String get toolsScan => '扫一扫';

  @override
  String get toolsScanSub => '扫码 / 选图解码 / 图片 OCR';

  @override
  String get toolsQr => '二维码 / 条形码';

  @override
  String get toolsQrSub => '14 种格式，支持 WiFi、名片等模板';

  @override
  String get toolsLan => '局域网传输';

  @override
  String get toolsLanSub => '手机与电脑互传文本与文件';

  @override
  String get toolsSettings => '设置';

  @override
  String get toolsSettingsSub => '互传配置、版本与开源许可';

  @override
  String otdLoadFailed(String error) {
    return '数据加载失败：$error';
  }

  @override
  String get otdEvents => '大事记';

  @override
  String get otdBirths => '今天出生';

  @override
  String get otdDeaths => '今天逝世';

  @override
  String otdCount(int n) {
    return '$n 条';
  }

  @override
  String otdSummary(int events, int births, int deaths) {
    return '大事 $events · 诞生 $births · 逝世 $deaths';
  }

  @override
  String get otdEmpty => '这一天暂无收录的条目';

  @override
  String get otdNoData => '本日暂无数据';

  @override
  String get swTitle => '秒表';

  @override
  String get swStart => '开始';

  @override
  String get swPause => '暂停';

  @override
  String get swResume => '继续';

  @override
  String get swReset => '复位';

  @override
  String get swLap => '计次';

  @override
  String get swHint => '计时中点「计次」开始计圈';

  @override
  String swLapN(int n) {
    return '第 $n 圈';
  }

  @override
  String get swTotal => '总计';

  @override
  String get calcTitle => '日期计算';

  @override
  String get calcTabProject => '日期推算';

  @override
  String get calcTabDiff => '日期间隔';

  @override
  String get calcTabTime => '时间推算';

  @override
  String get calcDaysLabel => '相差的日子';

  @override
  String get calcUnitDays => '天';

  @override
  String get calcHintNegative => '可为负数';

  @override
  String get calcResult => '推算结果';

  @override
  String calcNDays(int n) {
    return '$n 天';
  }

  @override
  String calcLater(int n) {
    return '终点比起点晚 $n 天';
  }

  @override
  String calcEarlier(int n) {
    return '终点比起点早 $n 天';
  }

  @override
  String get calcHoursLabel => '相差的小时';

  @override
  String get calcUnitHours => '时';

  @override
  String get calcMinutesLabel => '相差的分钟';

  @override
  String get calcUnitMinutes => '分';

  @override
  String get calcLunar => '农历';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSave => '保存';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRetry => '重试';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonClose => '关闭';

  @override
  String get cdTitle => '倒数日';

  @override
  String get cdAdd => '添加倒数日';

  @override
  String get cdEditTitle => '编辑倒数日';

  @override
  String cdOpFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String cdSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String cdLoadFailed(String error) {
    return '读取失败:$error';
  }

  @override
  String cdDeleteTitle(String title) {
    return '删除「$title」';
  }

  @override
  String get cdDeleteMsg => '删除后无法恢复。';

  @override
  String get commonDayUnit => '天';

  @override
  String get cdRemain => '还剩';

  @override
  String get cdPassed => '已过';

  @override
  String get cdHas => '还有';

  @override
  String get cdUntilNext => '距下次';

  @override
  String get cdToday => '就是今天';

  @override
  String get cdModeCountdown => '倒数';

  @override
  String get cdModeCountup => '正数';

  @override
  String get cdModeYearly => '每年';

  @override
  String get cdModeCountdownFull => '倒数：距离目标日还剩几天';

  @override
  String get cdModeCountupFull => '正数：目标日已经过去几天';

  @override
  String get cdModeYearlyFull => '每年重复：生日、纪念日';

  @override
  String cdTotal(int n) {
    return '共 $n 个倒数日';
  }

  @override
  String get cdEmpty => '还没有倒数日';

  @override
  String get cdEmptyHint => '把重要的日子记下来，桌面部件会替你盯着';

  @override
  String get cdPin => '置顶';

  @override
  String get cdUnpin => '取消置顶';

  @override
  String get cdPinHint => '置顶的会排在最前，桌面部件也优先显示';

  @override
  String get cdPinSwitchHint => '排在列表最前，桌面部件也优先显示';

  @override
  String get cdFieldTitle => '标题';

  @override
  String get cdFieldTitleHint => '例如：考研初试、结婚纪念日';

  @override
  String get cdFieldTarget => '目标日期';

  @override
  String get cdFieldMode => '计数方式';

  @override
  String get cdFieldColor => '主题色';

  @override
  String get cdFieldNote => '备注（可选）';

  @override
  String get cdErrTitleRequired => '请填写标题';

  @override
  String cdQuote(String text) {
    return '「$text」';
  }

  @override
  String get cdLifeTitle => '人生进度';

  @override
  String get cdLifeSubtitle => '设置出生日期后，这里和桌面部件都会显示进度';

  @override
  String get cdLifeEdit => '修改';

  @override
  String cdLifePassed(String pct) {
    return '已过 $pct%';
  }

  @override
  String cdLifeLived(int days) {
    return '已活 $days 天';
  }

  @override
  String cdLifeRemaining(int age, int days) {
    return '距 $age 岁预期寿命还有 $days 天';
  }

  @override
  String get cdLifeSetupTitle => '人生进度设置';

  @override
  String get cdBirthday => '出生日期';

  @override
  String get cdNotSet => '未设置';

  @override
  String get cdLifespanField => '预期寿命（岁）';

  @override
  String get cdLifespanHelp => '用于折算总天数，随时可以改';

  @override
  String get cdQuoteField => '人生格言（可选）';

  @override
  String get cdQuoteHelp => '显示在进度卡片和桌面部件顶部';

  @override
  String get cdDefaultQuote => '今天不走，明天要跑。';

  @override
  String get cdErrPickBirthday => '请选择出生日期';

  @override
  String get cdErrLifespan => '预期寿命需为正整数';

  @override
  String get cdClearLife => '清除人生进度';

  @override
  String get commonToday => '今天';

  @override
  String get festTitle => '节日节气';

  @override
  String get festRemain => '还有';

  @override
  String festNoMatch(String query) {
    return '没有叫「$query」的节日或节气';
  }

  @override
  String get festEmpty => '未来一年没有可显示的节日节气';

  @override
  String festHiddenNotice(int n) {
    return '有 $n 个被隐藏了，可到设置里恢复';
  }

  @override
  String get festSearch => '搜索';

  @override
  String get festCloseSearch => '关闭搜索';

  @override
  String get festSearchHint => '搜索节日或节气';

  @override
  String get festBadgeJieQi => '节气';

  @override
  String get festBadgeFestival => '节日';

  @override
  String get festColorfulBg => '显示彩色背景';

  @override
  String get festColorfulBgSub => '关闭后卡片改为素色';

  @override
  String get festShowEmoji => '显示表情';

  @override
  String get festShowEmojiSub => '在节日名称后追加一个 emoji';

  @override
  String get festCoverColor => '封面颜色';

  @override
  String get festCoverRotate => '轮换';

  @override
  String get festCoverRandom => '随机';

  @override
  String get festCoverRotateSub => '按列表顺序在八种颜色里循环';

  @override
  String get festCoverRandomSub => '每天打乱一次，同一天内保持不变';

  @override
  String get festHiddenTitle => '隐藏的节日';

  @override
  String get festHiddenNone => '当前没有隐藏任何节日';

  @override
  String festHiddenCount(int n) {
    return '已隐藏 $n 项';
  }

  @override
  String festGroupVisible(int n) {
    return '可显示（$n）';
  }

  @override
  String festGroupHidden(int n) {
    return '已隐藏（$n）';
  }

  @override
  String get calViewYear => '年视图';

  @override
  String get calViewMonth => '月视图';

  @override
  String get calViewWeek => '周视图';

  @override
  String get calViewDay => '日视图';

  @override
  String get calWeekHeader => '日一二三四五六';

  @override
  String calYearTitle(int year) {
    return '$year年';
  }

  @override
  String calPrev(String tag) {
    return '上一$tag';
  }

  @override
  String calNext(String tag) {
    return '下一$tag';
  }

  @override
  String get calUnitYear => '年';

  @override
  String get calUnitMonth => '月';

  @override
  String get calUnitWeek => '周';

  @override
  String get calUnitDay => '日';

  @override
  String calMonthTitle(String month) {
    return '$month月';
  }

  @override
  String calDaysCount(int days) {
    return '$days天';
  }

  @override
  String get calFestival => '节日';

  @override
  String get calDistance => '距今';

  @override
  String calPassedDays(int days) {
    return '已过 $days 天';
  }

  @override
  String get scanTitlePair => '扫码配对';

  @override
  String get scanTitleOcr => 'OCR 识别';

  @override
  String get scanTitleScan => '扫一扫';

  @override
  String get scanTakePhoto => '拍照';

  @override
  String get scanPickGallery => '相册选图';

  @override
  String get scanPickImage => '选图';

  @override
  String get scanActionOcr => '识别文字 OCR';

  @override
  String get scanActionBarcode => '扫二维码/条形码';

  @override
  String get scanStageRead => '读取图片';

  @override
  String get scanStagePrepareModel => '准备 OCR 模型（首次约 140MB）';

  @override
  String get scanStageRecognizing => '正在识别文字';

  @override
  String get scanStageDone => '识别完成';

  @override
  String get scanStageDecoding => '正在解码二维码/条形码';

  @override
  String get scanStageDecoded => '解码完成';

  @override
  String scanFailed(String stage, String error) {
    return '识别失败 · $stage：$error';
  }

  @override
  String get scanNoCode => '没识别出码——试试正对屏幕、避开反光、靠近一点';

  @override
  String scanSavedDevice(String name, String ip) {
    return '已保存设备 $name ($ip)';
  }

  @override
  String get scanOcrResult => 'OCR 结果';

  @override
  String get scanNoText => '（未识别到文字）';

  @override
  String get scanDecodeResult => '解码结果';

  @override
  String scanStagePercent(String stage, int percent) {
    return '$stage（$percent%）';
  }

  @override
  String get qrTitle => '生成二维码 / 条形码';

  @override
  String get qrTemplateTitle => '内容模板';

  @override
  String get qrPreview => '预览';

  @override
  String get qrGenerate => '生成';

  @override
  String get qrGenerating => '生成中…';

  @override
  String get qrNotSet => '未设置';

  @override
  String get qrGroupMatrix => '二维码 / 矩阵码';

  @override
  String get qrGroupStacked => '堆叠二维';

  @override
  String get qrGroupRetail => '商品条码';

  @override
  String get qrGroupIndustrial => '物流 / 工业';

  @override
  String get qrGroupOther => '其他';

  @override
  String get qrNameQrCode => '二维码';

  @override
  String get qrDim2 => '二维';

  @override
  String get qrDim1 => '一维';

  @override
  String get qrHintQrCode => '任意文本、网址、中文都可以';

  @override
  String get qrHintDataMatrix => '任意文本，体积小，常印在小零件上';

  @override
  String get qrHintAztec => '任意文本，常见于登机牌、火车票';

  @override
  String get qrHintPdf417 => '任意文本，可存较长内容，常见于各类证件';

  @override
  String get qrHintEan13 => '12 或 13 位数字，末位是校验位';

  @override
  String get qrHintEan8 => '7 或 8 位数字';

  @override
  String get qrHintUpcA => '11 或 12 位数字';

  @override
  String get qrHintUpcE => '7 或 8 位数字，首位须为 0 或 1';

  @override
  String get qrHintCode128 => '任意 ASCII 文本，快递单最常用';

  @override
  String get qrHintCode39 => '限 0-9 A-Z 与 - . \$ / + % 和空格';

  @override
  String get qrHintCode93 => '任意 ASCII 文本';

  @override
  String get qrHintItf => '偶数位数字，常见于外箱包装';

  @override
  String get qrHintCodabar => '数字加 A/B/C/D 作起止符，如 A123456B';

  @override
  String get qrHintTelepen => '任意 ASCII 文本，较少使用';

  @override
  String get qrTplCustom => '自定义';

  @override
  String get qrTplWifi => 'WiFi';

  @override
  String get qrTplUrl => '网址';

  @override
  String get qrTplVcard => '名片';

  @override
  String get qrTplPhone => '电话';

  @override
  String get qrTplSms => '短信';

  @override
  String get qrTplEmail => '邮件';

  @override
  String get qrTplCalendar => '日历';

  @override
  String get qrTplGeo => '位置';

  @override
  String qrFormatLabel(String name, String dim) {
    return '$name（$dim）';
  }

  @override
  String qrContentReq(String hint) {
    return '内容要求：$hint';
  }

  @override
  String qrSelfOnly(String name) {
    return '注意：$name 只能生成，本应用的扫一扫识别不了，用其他扫码工具可以正常扫。';
  }

  @override
  String qrRequirement(String name, String hint) {
    return '「$name」要求：$hint';
  }

  @override
  String qrFillField(String label) {
    return '请填写$label';
  }

  @override
  String get qrFillContent => '请填写内容';

  @override
  String qrNoDigits(String label) {
    return '$label里没有可用数字';
  }

  @override
  String get qrPickStart => '请选择开始时间';

  @override
  String get qrGeoNotNumber => '经纬度必须是数字';

  @override
  String get qrFieldContent => '内容';

  @override
  String get qrFieldSsid => '网络名称 (SSID)';

  @override
  String get qrFieldPass => '密码';

  @override
  String get qrPassHint => '加密方式选「无密码」时留空';

  @override
  String get qrFieldSecurity => '加密方式';

  @override
  String get qrEncNone => '无密码';

  @override
  String get qrFieldUrl => '网址';

  @override
  String get qrUrlHint => '例如 example.com，不写开头会自动补 https://';

  @override
  String get qrFieldName => '姓名';

  @override
  String get qrFieldMobile => '手机';

  @override
  String get qrFieldEmail => '邮箱';

  @override
  String get qrFieldOrg => '公司';

  @override
  String get qrFieldJob => '职位';

  @override
  String get qrFieldPhoneNumber => '电话号码';

  @override
  String get qrPhoneHint => '空格、横线会被自动去掉';

  @override
  String get qrFieldSmsTo => '收件号码';

  @override
  String get qrFieldSmsBody => '短信内容';

  @override
  String get qrFieldMailTo => '收件邮箱';

  @override
  String get qrFieldSubject => '主题';

  @override
  String get qrFieldBody => '正文';

  @override
  String get qrFieldCalTitle => '标题';

  @override
  String get qrStartTime => '开始时间';

  @override
  String get qrEndTime => '结束时间';

  @override
  String get qrEndHint => '不选结束时间则按开始后 1 小时计算';

  @override
  String get qrFieldLocation => '地点';

  @override
  String get qrFieldLat => '纬度';

  @override
  String get qrFieldLng => '经度';

  @override
  String get lanTitle => '局域网传输';

  @override
  String get lanReceiver => '接收端';

  @override
  String get lanSender => '发送端';

  @override
  String get lanStartServer => '启动服务';

  @override
  String get lanStopServer => '停止服务';

  @override
  String get lanServerKeepAlive => '退出本页面服务仍会保持运行，对端可以继续连';

  @override
  String get lanQrHint => '用另一台设备扫描此二维码配对';

  @override
  String get lanUnpaired => '未配对设备';

  @override
  String lanPeerInfo(String name, String addr) {
    return '目标: $name ($addr)';
  }

  @override
  String get lanPair => '扫码配对';

  @override
  String get lanTest => '测试';

  @override
  String get lanTextContent => '文本内容';

  @override
  String get lanSendText => '发送文本';

  @override
  String get lanSendFile => '发送文件';

  @override
  String get lanLogTitle => '记录';

  @override
  String get lanLsTitle => 'LocalSend 设备';

  @override
  String get lanLsOff => '兼容层未运行';

  @override
  String lanLsPortInfo(int port) {
    return '端口 $port，与官方 LocalSend 自动互通';
  }

  @override
  String lanLsNotice(String error) {
    return '注意：$error';
  }

  @override
  String get lanNoDevice => '未发现设备。确认两台设备连的是同一个网络，稍等几秒';

  @override
  String lanSendToAlias(String alias) {
    return '发送文件到 $alias';
  }

  @override
  String lanSendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String lanSnackSent(String name) {
    return '已发送 $name';
  }

  @override
  String get lanLogLsDisabled => 'LocalSend 兼容层已按设置关闭';

  @override
  String lanLogLsStarted(int port) {
    return 'LocalSend 兼容层已启动，端口 $port，官方 LocalSend 可自动发现本机';
  }

  @override
  String lanLogLsStartedNoMcast(int port, String reason) {
    return 'LocalSend 兼容层已启动（端口 $port），但多播不可用：$reason，只能被主动扫描发现';
  }

  @override
  String lanLogLsStartFailed(String error) {
    return 'LocalSend 兼容层启动失败：$error';
  }

  @override
  String get lanMcastUnavailable => '多播不可用';

  @override
  String get lanUnknown => '未知原因';

  @override
  String lanLogLsDiscovered(String alias, String addr) {
    return '发现 LocalSend 设备：$alias（$addr）';
  }

  @override
  String lanLogLsRegistered(String alias, String ip) {
    return '$alias 通过 LocalSend 协议注册到本机（$ip）';
  }

  @override
  String lanLogLsIncoming(String alias, int n, String ip, String size) {
    return '$alias 请求推送 $n 个文件（$ip，共 $size）';
  }

  @override
  String lanLogLsReceived(String name) {
    return 'LocalSend 收到文件：$name';
  }

  @override
  String lanLogLsRecvFailed(String name, String error) {
    return 'LocalSend 文件接收失败：$name（$error）';
  }

  @override
  String lanLogLsSessionEnd(int ok, int fail) {
    return 'LocalSend 会话结束：成功 $ok，失败 $fail';
  }

  @override
  String lanLogLsError(String message) {
    return 'LocalSend：$message';
  }

  @override
  String lanLogTextReceived(String kind, String from, String text) {
    return '收到文本 [$kind] 来自 $from:\n$text';
  }

  @override
  String lanLogReverseRegistered(String name, String addr) {
    return '✓ $name 已反向注册，现在可以互相发送\n$addr';
  }

  @override
  String lanLogServerStarted(String addr) {
    return '服务已启动：$addr';
  }

  @override
  String lanLogServerPort(int port) {
    return '服务已启动，端口 $port';
  }

  @override
  String lanLogServerAlts(String list) {
    return '备选地址: $list';
  }

  @override
  String get lanLogServerStopped => '服务已停止';

  @override
  String lanLogStartFailed(String error) {
    return '启动失败: $error';
  }

  @override
  String get lanLogSavedDownloads => '\n已存入系统\"下载\"目录';

  @override
  String lanLogSaveFailed(String error) {
    return '\n⚠ 存入下载目录失败（$error），文件仍留在应用私有目录';
  }

  @override
  String lanLogFileReceived(
    String from,
    String name,
    String size,
    String path,
    String note,
  ) {
    return '收到来自 $from 的文件 $name（$size）\n已保存: $path$note';
  }

  @override
  String lanLogTestFailed(String error) {
    return '测试连接出错: $error';
  }

  @override
  String lanLogPeerUnreachable(String name, String ips) {
    return '⚠ 连不上 $name（尝试了 $ips）。\n请确认两台设备连的是同一个 Wi-Fi/局域网，且对方已启动接收服务';
  }

  @override
  String lanLogConnOk(String addr) {
    return '✓ 连接正常 $addr';
  }

  @override
  String lanLogConnOkAlt(String addr, String preferred) {
    return '✓ 连接正常，改用可达地址 $addr（二维码首选的 $preferred 连不上）';
  }

  @override
  String lanLogNeedServer(String name) {
    return '⚠ 本机接收服务未运行，$name 还不能给本机发送。\n点上方「启动服务」后，请对方重新扫一次你的二维码';
  }

  @override
  String lanLogToldPeer(String name) {
    return '✓ 已把本机地址告诉 $name，现在双方都能互发';
  }

  @override
  String lanLogReverseFailed(String name, String error) {
    return '⚠ 无法反向注册给 $name：$error';
  }

  @override
  String lanLogPaired(String name, String addr) {
    return '已配对设备: $name ($addr)';
  }

  @override
  String lanLogTextSent(String name) {
    return '已发送文本到 $name';
  }

  @override
  String lanLogSendTextFailed(String error) {
    return '⚠ 发送文本失败：$error';
  }

  @override
  String lanLogFileSent(String name, String to) {
    return '已发送文件 $name 到 $to';
  }

  @override
  String lanLogSendFileFailed(String error) {
    return '⚠ 发送文件失败：$error';
  }

  @override
  String lanLogLsSent(String name, String alias) {
    return '已通过 LocalSend 发送 $name 到 $alias';
  }

  @override
  String lanLogLsSendFailed(String error) {
    return 'LocalSend 发送失败：$error';
  }

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutNoLan => '未检测到局域网地址';

  @override
  String aboutVersion(String version, String build) {
    return '版本 $version ($build)';
  }

  @override
  String get aboutLoadFailed => '信息读取失败';

  @override
  String get aboutSectionDevice => '本机信息';

  @override
  String get aboutLocalIp => '本地 IP';

  @override
  String get aboutListenPort => '监听端口';

  @override
  String get aboutFingerprint => '设备指纹';

  @override
  String get aboutFingerprintHint => '启用 LocalSend 兼容后生成，对方据此识别本机身份';

  @override
  String get aboutSectionLicense => '开源许可';

  @override
  String get aboutLicenseTitle => '本项目采用 Apache License 2.0';

  @override
  String get aboutLicenseBody =>
      '允许商业使用、修改与分发。分发本软件的副本时，\n请保留仓库中的 LICENSE 与 NOTICE 文件。\n\n完整许可文本见项目根目录的 LICENSE 文件。';

  @override
  String get aboutSectionThirdParty => '第三方组件';

  @override
  String get commonSaved => '已保存';

  @override
  String commonSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get setConfigLoadFailed => '配置读取失败';

  @override
  String get setSectionTransfer => '互传';

  @override
  String get setDeviceName => '设备名称';

  @override
  String get setDeviceNameHelp => '对方设备列表里显示的名字';

  @override
  String get setPortLabel => '监听端口';

  @override
  String setPortHelp(int port) {
    return '默认 $port。被占用时会自动改用其他端口，不影响互传';
  }

  @override
  String get setPinLabel => '传输 PIN（可选）';

  @override
  String get setPinHelp => '留空表示不校验。设置后，对方必须输入才能推送文件';

  @override
  String get setVerifyHash => '校验文件哈希';

  @override
  String get setVerifyHashSub => '收到文件后比对发送方提供的 SHA-256';

  @override
  String get setLsCompat => '启用 LocalSend 兼容';

  @override
  String get setLsCompatSub => '与官方 LocalSend 同一网络自动互通：不用扫码，进入传输页就会自动发现';

  @override
  String get setSectionAbout => '关于';

  @override
  String get setAboutTitle => '关于互传助手';

  @override
  String get setAboutSub => '版本、开源许可与第三方组件';

  @override
  String onBcLabel(int year) {
    return '前$year';
  }
}
