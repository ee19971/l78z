//! 倒数日：数据模型、增删改查与天数计算。
//!
//! 数据存 JSON，路径由 Dart 侧传入，与 [`config.rs`] 同一套约定
//! （原子写、损坏留档、绝不把坏文件抛给 UI）。
//!
//! **这份 JSON 同时是对原生层的契约**：桌面小部件跑在 launcher 进程里，
//! 调不到 Rust，只能由 Kotlin 直接读同一个文件（见
//! `android/app/src/main/kotlin/com/example/l78z/widget/CountdownStore.kt`）。
//! 改字段名或日期格式时，两边必须一起改，否则 widget 会静默读成空列表。

use std::path::Path;

use chrono::{Datelike, Local, NaiveDate};
use serde::{Deserialize, Serialize};

/// 数据文件名，Dart 侧用它拼文档目录下的完整路径。
pub const FILE_NAME: &str = "countdown-events.json";

fn default_color() -> String {
    "#6750A4".to_string()
}

/// 计数模式。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum CountMode {
    /// 倒数：距离目标日还剩几天。
    #[default]
    Countdown,
    /// 正数：目标日已经过去几天。
    Countup,
    /// 每年重复：生日、纪念日这类，始终指向下一个周年。
    Yearly,
}

/// 单条倒数日。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CountdownEvent {
    /// 唯一标识。单日 widget 靠它记住「桌面显示哪一条」。
    ///
    /// 新建时若为空，由 [`countdown_save`] 补一个；不引入 uuid 依赖——
    /// 这个 id 只在本文件范围内需要唯一。
    pub id: String,

    /// 标题。
    pub title: String,

    /// 目标日期，格式 `YYYY-MM-DD`。
    ///
    /// 存日期字符串而不是时间戳：倒数日是「日历意义上的天」，
    /// 时区一变、夏令时一来，时间戳差值就会比日历差值多或少一天。
    pub date: String,

    /// 计数模式。
    #[serde(default)]
    pub mode: CountMode,

    /// 主题色 `#RRGGBB`，页面与桌面部件共用，保证观感一致。
    #[serde(default = "default_color")]
    pub color: String,

    /// 是否置顶：列表排在最前，widget 也优先选中。
    #[serde(default)]
    pub pinned: bool,

    /// 备注。
    #[serde(default)]
    pub note: String,

    /// 距目标日的天数：正数=还剩，负数=已过，0=当天。
    ///
    /// `skip` 表示完全不落盘——这个值明天就变了，存下来只会变成错的。
    /// 每次读取都按「今天」重算。
    #[serde(skip)]
    pub days_left: i64,
}

impl Default for CountdownEvent {
    fn default() -> Self {
        Self {
            id: String::new(),
            title: String::new(),
            date: String::new(),
            mode: CountMode::default(),
            // 主题色不能跟着 derive 走成空串，否则新建事件会没颜色。
            color: default_color(),
            pinned: false,
            note: String::new(),
            days_left: 0,
        }
    }
}

/// 人生进度所需的个人参数。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LifeProfile {
    /// 出生日期，`YYYY-MM-DD`。
    pub birthday: String,

    /// 预期寿命（岁）。
    ///
    /// 折算成天数时用 365.2425（回归年平均长度），
    /// 直接乘 365 会把每四年少算的一天累积成可见误差。
    pub lifespan: u32,

    /// 人生格言，显示在进度卡片和桌面部件顶部。
    ///
    /// `default` 保证旧数据（没这个字段）读进来仍是默认那句，不会变成空串。
    #[serde(default = "default_quote")]
    pub quote: String,
}

/// 格言的默认值。桌面部件的 Kotlin 侧也有一份相同的兜底，改这里要同步。
fn default_quote() -> String {
    "今天不走，明天要跑。".to_string()
}

/// 人生进度的计算结果。
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct LifeProgress {
    /// 已活天数。
    pub lived_days: i64,

    /// 预期总天数。
    pub total_days: f64,

    /// 已过百分比，0.0~100.0。
    pub percent: f64,

    /// 还剩多少天。
    pub days_left: i64,
}

/// 文件里的顶层结构。
///
/// 与 Kotlin 侧 `CountdownStore` 的解析一一对应。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CountdownData {
    #[serde(default)]
    pub events: Vec<CountdownEvent>,

    #[serde(default)]
    pub life: Option<LifeProfile>,
}

// ---------------------------------------------------------------------------
// 对外接口
// ---------------------------------------------------------------------------

/// 读全部事件：算好 `days_left`，并按「置顶优先、近者在前」排好序。
pub fn countdown_events(path: String) -> anyhow::Result<Vec<CountdownEvent>> {
    Ok(load_data(&path)?.events)
}

/// 新增或更新一条事件，返回重排后的完整列表。
///
/// `event.id` 为空时自动生成，调用方不必自己造 id。
pub fn countdown_save(path: String, mut event: CountdownEvent) -> anyhow::Result<Vec<CountdownEvent>> {
    anyhow::ensure!(!event.title.trim().is_empty(), "标题不能为空");
    anyhow::ensure!(parse_date(&event.date).is_some(), "日期格式应为 YYYY-MM-DD");

    event.title = event.title.trim().to_string();
    if event.id.trim().is_empty() {
        event.id = new_id();
    }

    let mut data = load_data(&path)?;
    match data.events.iter_mut().find(|e| e.id == event.id) {
        Some(slot) => *slot = event,
        None => data.events.push(event),
    }
    finish(&path, &mut data)?;
    Ok(data.events)
}

/// 删除一条事件；id 不存在时静默返回现有列表。
pub fn countdown_delete(path: String, id: String) -> anyhow::Result<Vec<CountdownEvent>> {
    let mut data = load_data(&path)?;
    data.events.retain(|e| e.id != id);
    finish(&path, &mut data)?;
    Ok(data.events)
}

/// 切换一条事件的置顶状态，返回重排后的完整列表。
pub fn countdown_toggle_pin(path: String, id: String) -> anyhow::Result<Vec<CountdownEvent>> {
    let mut data = load_data(&path)?;
    if let Some(ev) = data.events.iter_mut().find(|e| e.id == id) {
        ev.pinned = !ev.pinned;
    }
    finish(&path, &mut data)?;
    Ok(data.events)
}

/// 读人生进度参数；从未设置过时返回 `None`。
pub fn countdown_life(path: String) -> anyhow::Result<Option<LifeProfile>> {
    Ok(load_data(&path)?.life)
}

/// 设置（或传 `None` 清除）人生进度参数。
pub fn countdown_set_life(path: String, life: Option<LifeProfile>) -> anyhow::Result<Option<LifeProfile>> {
    // 生日明显不合理时直接拒绝，免得进度算出负数或 200%。
    if let Some(p) = life.as_ref() {
        anyhow::ensure!(parse_date(&p.birthday).is_some(), "出生日期格式应为 YYYY-MM-DD");
        anyhow::ensure!(p.lifespan > 0, "预期寿命必须大于 0");
        let born = parse_date(&p.birthday).expect("上面已校验");
        anyhow::ensure!(born <= today(), "出生日期不能晚于今天");
    }

    let mut data = load_data(&path)?;
    data.life = life;
    let life = data.life.clone();
    finish(&path, &mut data)?;
    Ok(life)
}

/// 计算人生进度；没设置过参数时返回 `None`。
pub fn countdown_life_progress(path: String) -> anyhow::Result<Option<LifeProgress>> {
    let data = load_data(&path)?;
    Ok(data.life.as_ref().and_then(|p| life_progress(p, today())))
}

// ---------------------------------------------------------------------------
// 内部实现
// ---------------------------------------------------------------------------

fn today() -> NaiveDate {
    Local::now().date_naive()
}

fn parse_date(s: &str) -> Option<NaiveDate> {
    NaiveDate::parse_from_str(s.trim(), "%Y-%m-%d").ok()
}

fn new_id() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    format!("{ts}-{:08x}", rand::random::<u32>())
}

/// 算好天数并排序，然后落盘。所有写路径都走这里，保证文件里存的
/// 永远是「UI 此刻看到的那一份」。
fn finish(path: &str, data: &mut CountdownData) -> anyhow::Result<()> {
    for ev in &mut data.events {
        with_days(ev, today());
    }
    sort_events(&mut data.events);
    save_data(path, data)
}

/// 填好 `days_left`。
///
/// 三种模式统一成「目标日减今天」：倒数日的未来目标得正数，
/// 正数模式的历史目标得负数，UI 按模式决定念成「还剩」还是「已过」。
fn with_days(ev: &mut CountdownEvent, today: NaiveDate) {
    ev.days_left = match parse_date(&ev.date) {
        Some(target) => {
            let target = if ev.mode == CountMode::Yearly {
                // 每年重复只认月日，永远指向不早于今天的那个周年。
                next_anniversary(today, target)
            } else {
                target
            };
            (target - today).num_days()
        }
        // 日期解析不了就当 0，别让一条脏数据毁掉整个列表。
        None => 0,
    };
}

/// 置顶优先，其次按「离今天多远」升序——最近的（无论将来还是已过）排最前。
fn sort_events(events: &mut [CountdownEvent]) {
    events.sort_by(|a, b| {
        b.pinned
            .cmp(&a.pinned)
            .then(a.days_left.abs().cmp(&b.days_left.abs()))
    });
}

/// 下一个周年日期：不早于 `today`。
fn next_anniversary(today: NaiveDate, target: NaiveDate) -> NaiveDate {
    let (month, day) = (target.month(), target.day());
    let this_year = anniversary_in(today.year(), month, day);
    if this_year >= today {
        this_year
    } else {
        anniversary_in(today.year() + 1, month, day)
    }
}

/// 指定年份的周年日期。
///
/// 2 月 29 日出生的人在平年无此日期，退回 2 月 28 日，
/// 与主流日历应用的处理一致。
fn anniversary_in(year: i32, month: u32, day: u32) -> NaiveDate {
    NaiveDate::from_ymd_opt(year, month, day).unwrap_or_else(|| {
        NaiveDate::from_ymd_opt(year, 2, 28).expect("2 月 28 日必然合法")
    })
}

fn life_progress(p: &LifeProfile, today: NaiveDate) -> Option<LifeProgress> {
    let born = parse_date(&p.birthday)?;
    if born > today || p.lifespan == 0 {
        return None;
    }
    let lived = (today - born).num_days();
    let total = f64::from(p.lifespan) * 365.2425;
    let lived_f = lived as f64;
    Some(LifeProgress {
        lived_days: lived,
        total_days: total,
        // 超过预期寿命时允许大于 100，那本身是有意义的信息。
        percent: (lived_f / total * 100.0).clamp(0.0, 999.0),
        days_left: (total - lived_f).max(0.0) as i64,
    })
}

/// 读数据；文件不存在返回空，损坏时留档 `.bak` 后返回空。
///
/// 与 `config.rs` 同一套约定：这里绝不抛错，倒数日页不该因为一个坏文件打不开。
fn load_data(path: &str) -> anyhow::Result<CountdownData> {
    let p = Path::new(path);
    if !p.exists() {
        return Ok(CountdownData::default());
    }

    let text = std::fs::read_to_string(p)?;
    match serde_json::from_str::<CountdownData>(&text) {
        Ok(mut data) => {
            // 文件里可能躺着上一次运行时的天数，按今天的日期重算一遍。
            for ev in &mut data.events {
                with_days(ev, today());
            }
            sort_events(&mut data.events);
            Ok(data)
        }
        Err(e) => {
            let bak = format!("{path}.bak");
            let _ = std::fs::rename(p, &bak);
            eprintln!("[countdown] 倒数日数据已损坏（{e}），原文件留档为 {bak}");
            Ok(CountdownData::default())
        }
    }
}

/// 落盘。先写 `.part` 再改名，中途被杀也不会留下半截 JSON——
/// 否则下次加载会把它当成损坏数据，用户攒的倒数日就没了。
fn save_data(path: &str, data: &CountdownData) -> anyhow::Result<()> {
    let p = Path::new(path);
    if let Some(dir) = p.parent() {
        std::fs::create_dir_all(dir)?;
    }

    let tmp = format!("{path}.part");
    std::fs::write(&tmp, serde_json::to_string_pretty(data)?)?;
    // Windows 上 rename 到已存在的目标会失败，先删掉旧文件。
    if p.exists() {
        let _ = std::fs::remove_file(p);
    }
    std::fs::rename(&tmp, p)?;
    Ok(())
}

// ---------------------------------------------------------------------------
// 测试
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_path(tag: &str) -> String {
        std::env::temp_dir()
            .join(format!("l78z-cd-{tag}-{}.json", std::process::id()))
            .to_string_lossy()
            .into_owned()
    }

    fn d(y: i32, m: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(y, m, day).unwrap()
    }

    #[test]
    fn missing_file_yields_empty_list() {
        let path = temp_path("missing");
        let _ = std::fs::remove_file(&path);

        assert!(countdown_events(path.clone()).unwrap().is_empty());
        assert!(countdown_life(path.clone()).unwrap().is_none());
        assert!(countdown_life_progress(path).unwrap().is_none());
    }

    #[test]
    fn save_then_load_roundtrip() {
        let path = temp_path("roundtrip");
        let _ = std::fs::remove_file(&path);

        let ev = CountdownEvent {
            id: String::new(),
            title: "  考研初试  ".into(),
            date: "2099-12-20".into(),
            mode: CountMode::Countdown,
            color: "#E91E63".into(),
            pinned: false,
            note: "带身份证".into(),
            days_left: 0,
        };
        let list = countdown_save(path.clone(), ev).unwrap();

        assert_eq!(list.len(), 1);
        // id 由 Rust 补，标题去掉首尾空白。
        assert!(!list[0].id.is_empty());
        assert_eq!(list[0].title, "考研初试");
        assert_eq!(list[0].days_left, (d(2099, 12, 20) - today()).num_days());

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn save_replaces_same_id_and_delete_removes() {
        let path = temp_path("replace");
        let _ = std::fs::remove_file(&path);

        let mut ev = CountdownEvent {
            id: String::new(),
            title: "旧标题".into(),
            date: "2099-01-01".into(),
            ..Default::default()
        };
        let list = countdown_save(path.clone(), ev.clone()).unwrap();
        let id = list[0].id.clone();

        ev.id = id.clone();
        ev.title = "新标题".into();
        let list = countdown_save(path.clone(), ev).unwrap();
        assert_eq!(list.len(), 1, "同 id 应覆盖而不是新增");
        assert_eq!(list[0].title, "新标题");

        let list = countdown_delete(path.clone(), id).unwrap();
        assert!(list.is_empty());

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn days_left_counts_calendar_days() {
        let today = d(2026, 10, 12);
        let mut ev = CountdownEvent {
            date: "2026-10-15".into(),
            ..Default::default()
        };

        with_days(&mut ev, today);
        assert_eq!(ev.days_left, 3, "未来日期为正数");

        ev.date = "2026-10-12".into();
        with_days(&mut ev, today);
        assert_eq!(ev.days_left, 0, "当天为 0");

        ev.date = "2026-10-09".into();
        with_days(&mut ev, today);
        assert_eq!(ev.days_left, -3, "已过日期为负数");
    }

    #[test]
    fn days_left_crosses_year_boundary() {
        let today = d(2026, 12, 31);
        let mut ev = CountdownEvent {
            date: "2027-01-01".into(),
            ..Default::default()
        };
        with_days(&mut ev, today);
        assert_eq!(ev.days_left, 1, "跨年只按日历天数算，不看年份差");
    }

    #[test]
    fn yearly_points_to_next_anniversary() {
        let today = d(2026, 10, 12);

        // 周年在今年、还没到 → 指向今年
        assert_eq!(next_anniversary(today, d(2000, 12, 25)), d(2026, 12, 25));
        // 周年在今年、已经过了 → 指向明年
        assert_eq!(next_anniversary(today, d(2000, 3, 8)), d(2027, 3, 8));
        // 周年正好是今天 → 就是今天
        assert_eq!(next_anniversary(today, d(2000, 10, 12)), today);
    }

    #[test]
    fn yearly_leap_day_falls_back_to_feb28() {
        // 2 月 29 日在平年不存在，2027、2028 都要退回 2 月 28 日或直接命中。
        assert_eq!(next_anniversary(d(2027, 1, 1), d(2000, 2, 29)), d(2027, 2, 28));
        assert_eq!(next_anniversary(d(2028, 1, 1), d(2000, 2, 29)), d(2028, 2, 29));
        // 2028 年 2 月 29 日当天
        assert_eq!(next_anniversary(d(2028, 2, 29), d(2000, 2, 29)), d(2028, 2, 29));
    }

    #[test]
    fn yearly_mode_ignores_stored_year() {
        let today = d(2026, 10, 12);
        let mut ev = CountdownEvent {
            date: "2000-12-25".into(),
            mode: CountMode::Yearly,
            ..Default::default()
        };
        with_days(&mut ev, today);
        assert_eq!(ev.days_left, (d(2026, 12, 25) - today).num_days());
    }

    #[test]
    fn sort_puts_pinned_first_then_nearest() {
        let mk = |id: &str, date: &str, pinned: bool| CountdownEvent {
            id: id.into(),
            date: date.into(),
            pinned,
            ..Default::default()
        };
        let today = today();
        // near / far 指「离今天多远」，不是年份大小。
        let mut events = vec![
            mk("far", "2099-06-01", false),
            mk("pinned-far", "2099-07-01", true),
            mk("near", "2099-01-03", false),
            mk("pinned-near", "2099-01-05", true),
        ];
        for ev in &mut events {
            with_days(ev, today);
        }

        sort_events(&mut events);
        let order: Vec<&str> = events.iter().map(|e| e.id.as_str()).collect();
        assert_eq!(order, ["pinned-near", "pinned-far", "near", "far"]);
    }

    #[test]
    fn toggle_pin_flips_and_persists() {
        let path = temp_path("pin");
        let _ = std::fs::remove_file(&path);

        let ev = CountdownEvent {
            id: String::new(),
            title: "生日".into(),
            date: "2099-03-08".into(),
            ..Default::default()
        };
        let id = countdown_save(path.clone(), ev).unwrap()[0].id.clone();

        assert!(countdown_toggle_pin(path.clone(), id.clone()).unwrap()[0].pinned);
        assert!(!countdown_toggle_pin(path.clone(), id).unwrap()[0].pinned);

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn empty_title_and_bad_date_are_rejected() {
        let path = temp_path("reject");
        let _ = std::fs::remove_file(&path);

        let no_title = CountdownEvent {
            title: "   ".into(),
            date: "2099-01-01".into(),
            ..Default::default()
        };
        assert!(countdown_save(path.clone(), no_title).is_err());

        let bad_date = CountdownEvent {
            title: "标题".into(),
            date: "2026/01/01".into(),
            ..Default::default()
        };
        assert!(countdown_save(path.clone(), bad_date).is_err());

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn corrupt_file_falls_back_to_empty_and_keeps_backup() {
        let path = temp_path("corrupt");
        std::fs::write(&path, "{ this is not json").unwrap();

        let list = countdown_events(path.clone()).unwrap();
        assert!(list.is_empty());
        assert!(Path::new(&format!("{path}.bak")).exists(), "坏文件应留档");

        let _ = std::fs::remove_file(&path);
        let _ = std::fs::remove_file(format!("{path}.bak"));
    }

    #[test]
    fn days_left_is_recomputed_not_trusted_from_file() {
        let path = temp_path("recompute");
        std::fs::write(
            &path,
            r#"{"events":[{"id":"x","title":"t","date":"2000-01-01","days_left":9999}]}"#,
        )
        .unwrap();

        let list = countdown_events(path.clone()).unwrap();
        // 文件里塞的 9999 必须被丢弃，按今天重算成负数（已过）。
        assert_eq!(list[0].days_left, (d(2000, 1, 1) - today()).num_days());
        assert_ne!(list[0].days_left, 9999);

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn life_progress_uses_tropical_year_length() {
        let p = LifeProfile {
            birthday: "2000-01-01".into(),
            lifespan: 80,
            quote: default_quote(),
        };
        let prog = life_progress(&p, d(2026, 1, 1)).unwrap();

        assert_eq!(prog.lived_days, 26 * 365 + 7, "2000~2026 含 7 个闰日");
        assert_eq!(prog.total_days, 80.0 * 365.2425);
        assert!((prog.percent - prog.lived_days as f64 / prog.total_days * 100.0).abs() < 1e-9);
        assert_eq!(prog.days_left, (prog.total_days - prog.lived_days as f64) as i64);
    }

    #[test]
    fn life_progress_allows_exceeding_lifespan() {
        let p = LifeProfile {
            birthday: "1930-01-01".into(),
            lifespan: 40,
            quote: default_quote(),
        };
        let prog = life_progress(&p, d(2026, 1, 1)).unwrap();
        assert!(prog.percent > 100.0, "超龄是有意义的信息，不该被截断");
        assert_eq!(prog.days_left, 0, "但剩余天数不能是负数");
    }

    #[test]
    fn life_profile_validation_rejects_future_birthday() {
        let path = temp_path("life");
        let _ = std::fs::remove_file(&path);

        let bad = LifeProfile {
            birthday: "2099-01-01".into(),
            lifespan: 80,
            quote: default_quote(),
        };
        assert!(countdown_set_life(path.clone(), Some(bad)).is_err());

        let ok = LifeProfile {
            birthday: "2000-06-01".into(),
            lifespan: 80,
            quote: default_quote(),
        };
        assert_eq!(countdown_set_life(path.clone(), Some(ok.clone())).unwrap(), Some(ok));
        assert!(countdown_life_progress(path.clone()).unwrap().is_some());

        // 清除
        assert!(countdown_set_life(path.clone(), None).unwrap().is_none());
        assert!(countdown_life_progress(path).unwrap().is_none());
    }

    #[test]
    fn old_data_without_quote_falls_back_to_default() {
        // 3.0.0 之前的数据没有 quote 字段，读进来必须拿到默认那句，
        // 而不是空串——空串会让部件顶部塌掉。
        let json = r#"{"birthday":"2000-01-01","lifespan":80}"#;
        let p: LifeProfile = serde_json::from_str(json).unwrap();
        assert_eq!(p.quote, default_quote());

        // 空字符串是用户明确清空，不能被 default 覆盖。
        let json = r#"{"birthday":"2000-01-01","lifespan":80,"quote":""}"#;
        let p: LifeProfile = serde_json::from_str(json).unwrap();
        assert_eq!(p.quote, "");
    }
}
