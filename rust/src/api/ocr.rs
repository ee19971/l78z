use std::path::Path;
use std::sync::{Mutex, OnceLock};

use image::RgbImage;
use rapidocr_core::config::RapidOcrConfig;
use rapidocr_core::model::{ModelCache, ModelDownloadMode, PPOCRV6_MEDIUM};
use rapidocr_core::types::OcrOutput;
use rapidocr_core::RapidOcr;
use serde::Serialize;

/// OCR 一行文本。
#[derive(Debug, Clone, Serialize)]
pub struct OcrBlock {
    pub text: String,
    pub score: f32,
    /// 四点框 [x0,y0, x1,y1, x2,y2, x3,y3]
    pub points: Vec<f32>,
}

/// 模型就绪状态。
#[derive(Debug, Clone, Serialize)]
pub struct OcrStatus {
    pub ready: bool,
    pub missing: Vec<String>,
    pub message: String,
}

type Engine = (String, Mutex<RapidOcr>);

fn engine_cell() -> &'static Mutex<Option<Engine>> {
    static CELL: OnceLock<Mutex<Option<Engine>>> = OnceLock::new();
    CELL.get_or_init(|| Mutex::new(None))
}

fn model_dir_checked(model_dir: &str) -> anyhow::Result<std::path::PathBuf> {
    let dir = std::path::PathBuf::from(model_dir);
    anyhow::ensure!(dir.is_dir(), "模型目录不存在: {}", dir.display());
    Ok(dir)
}

/// 查询模型是否齐全（不加载推理引擎）。
pub fn ocr_status(model_dir: String) -> anyhow::Result<OcrStatus> {
    let dir = model_dir_checked(&model_dir)?;
    let cache = ModelCache::new(&dir);
    let missing = cache.missing_assets(&PPOCRV6_MEDIUM);
    if missing.is_empty() {
        Ok(OcrStatus {
            ready: true,
            missing: vec![],
            message: "模型就绪".to_string(),
        })
    } else {
        Ok(OcrStatus {
            ready: false,
            missing: missing.iter().map(|a| a.name.to_string()).collect(),
            message: format!("缺少 {} 个模型文件", missing.len()),
        })
    }
}

/// 下载缺失的模型文件（开发期/兜底用；走 HTTPS_PROXY 环境变量代理）。
pub fn ocr_download_models(model_dir: String) -> anyhow::Result<OcrStatus> {
    let dir = model_dir_checked_or_create(&model_dir)?;
    let cache = ModelCache::new(&dir);
    cache.ensure_model_set(&PPOCRV6_MEDIUM, ModelDownloadMode::Missing)?;
    ocr_status(model_dir)
}

fn model_dir_checked_or_create(model_dir: &str) -> anyhow::Result<std::path::PathBuf> {
    let dir = std::path::PathBuf::from(model_dir);
    if !dir.exists() {
        std::fs::create_dir_all(&dir)?;
    }
    Ok(dir)
}

fn load_engine(model_dir: &str) -> anyhow::Result<()> {
    let dir = model_dir_checked(model_dir)?;
    let mut cell = engine_cell().lock().unwrap();
    if let Some((cached_dir, _)) = cell.as_ref() {
        if cached_dir == model_dir {
            return Ok(());
        }
    }
    let cache = ModelCache::new(&dir);
    let missing = cache.missing_assets(&PPOCRV6_MEDIUM);
    anyhow::ensure!(
        missing.is_empty(),
        "模型文件缺失: {}",
        missing
            .iter()
            .map(|a| a.name)
            .collect::<Vec<_>>()
            .join(", ")
    );
    let cfg: RapidOcrConfig = cache.config_for(&PPOCRV6_MEDIUM);
    let ocr = RapidOcr::new(cfg).map_err(|e| anyhow::anyhow!("OCR 引擎初始化失败: {e}"))?;
    *cell = Some((model_dir.to_string(), Mutex::new(ocr)));
    Ok(())
}

/// 对 RGBA8 buffer 做 OCR。model_dir 为已解包的模型目录。
pub fn ocr_image(buf: Vec<u8>, width: u32, height: u32, model_dir: String) -> anyhow::Result<Vec<OcrBlock>> {
    anyhow::ensure!(width > 0 && height > 0, "图像尺寸无效");
    anyhow::ensure!(
        buf.len() as u64 == width as u64 * height as u64 * 4,
        "buffer 长度与尺寸不匹配"
    );
    load_engine(&model_dir)?;

    let rgba = image::RgbaImage::from_raw(width, height, buf)
        .ok_or_else(|| anyhow::anyhow!("无法构造图像"))?;
    let rgb = RgbImage::from_fn(width, height, |x, y| {
        let p = rgba.get_pixel(x, y);
        image::Rgb([p[0], p[1], p[2]])
    });

    let cell = engine_cell().lock().unwrap();
    let engine = cell
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("OCR 引擎未初始化"))?;
    let mut guard = engine.1.lock().map_err(|_| anyhow::anyhow!("OCR 引擎被占用"))?;
    let out: OcrOutput = guard
        .run_image(&rgb)
        .map_err(|e| anyhow::anyhow!("OCR 识别失败: {e}"))?;

    Ok(out
        .lines
        .into_iter()
        .map(|line| OcrBlock {
            text: line.text,
            score: line.score,
            points: line
                .bbox
                .points
                .iter()
                .flat_map(|p| [p[0], p[1]])
                .collect(),
        })
        .collect())
}

/// 将所有识别行按顺序拼成一段文本。
pub fn ocr_join_text(blocks: &[OcrBlock]) -> String {
    blocks
        .iter()
        .map(|b| b.text.as_str())
        .collect::<Vec<_>>()
        .join("\n")
}

/// 供 Dart 侧调用：识别图片并直接返回合并文本。
pub fn ocr_image_text(buf: Vec<u8>, width: u32, height: u32, model_dir: String) -> anyhow::Result<String> {
    let blocks = ocr_image(buf, width, height, model_dir)?;
    Ok(ocr_join_text(&blocks))
}

#[allow(dead_code)]
fn assert_path_used(p: &Path) -> &Path {
    p
}
