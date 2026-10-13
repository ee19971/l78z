use std::io::Cursor;
use std::str::FromStr;

use image::Luma;
use rxing::{BarcodeFormat, EncodeHints, MultiFormatWriter, Writer};
use serde::Serialize;

/// 解码结果：二维码或条形码。
#[derive(Debug, Clone, Serialize)]
pub struct DecodedCode {
    /// 码格式，如 "QR_CODE"、"CODE_128"、"EAN_13"
    pub format: String,
    /// 码内容（UTF-8 文本）
    pub payload: String,
}

/// 生成二维码 PNG 字节（灰度图，安静区默认）。
pub fn generate_qr_png(text: String, size: u32) -> anyhow::Result<Vec<u8>> {
    let code = qrcode::QrCode::new(text.as_bytes())
        .map_err(|e| anyhow::anyhow!("二维码生成失败: {e}"))?;
    let img = code
        .render::<Luma<u8>>()
        .min_dimensions(size.max(64), size.max(64))
        .build();
    let mut buf = Vec::new();
    img.write_to(&mut Cursor::new(&mut buf), image::ImageFormat::Png)
        .map_err(|e| anyhow::anyhow!("PNG 编码失败: {e}"))?;
    Ok(buf)
}

/// 生成条形码 / 二维码 PNG（灰度图）。
///
/// `format` 取 rxing 的格式名，与解码结果里的 `format` 字段完全一致
/// （如 "QR_CODE"、"CODE_128"、"EAN_13"）。不做成枚举是因为 Dart 侧传字符串
/// 就够，而 rxing 自带 FromStr，能直接给出"不支持该格式"的明确错误。
///
/// `width`/`height` 是期望尺寸，zxing 会按模块数把它调整到能整除的值，
/// 因此实际像素与请求值略有出入属正常行为，不是误差。
pub fn generate_barcode_png(
    format: String,
    text: String,
    width: u32,
    height: u32,
) -> anyhow::Result<Vec<u8>> {
    anyhow::ensure!(!text.is_empty(), "内容不能为空");

    // 尺寸太小会被 zxing 直接拒绝（模块挤不下），先自己拦一道，
    // 报错信息也比它抛的 "too small" 更好懂。
    let w = width.max(64);
    let h = height.max(64);

    let fmt = BarcodeFormat::from_str(&format)
        .map_err(|_| anyhow::anyhow!("不支持的条码格式: {format}"))?;

    let mut hints = EncodeHints::default();
    // 矩阵码按标准留 4 模块静默区；一维条码不设，让 zxing 用它自己的
    // 更大默认值（10 模块）——一维码的空白区过窄最难扫。
    if is_matrix_format(fmt) {
        hints.Margin = Some("4".into());
    }

    let matrix = MultiFormatWriter
        .encode_with_hints(&text, &fmt, w as i32, h as i32, &hints)
        .map_err(|e| {
            anyhow::anyhow!(
                "{fmt:?} 生成失败: {e}\n请确认内容符合该格式的字符集与长度要求"
            )
        })?;

    // BitMatrix 自带 Luma8 的转换：模块为黑、留白为白。
    let img = image::DynamicImage::from(&matrix);
    let mut buf = Vec::new();
    img.write_to(&mut Cursor::new(&mut buf), image::ImageFormat::Png)
        .map_err(|e| anyhow::anyhow!("PNG 编码失败: {e}"))?;
    Ok(buf)
}

/// 是否为二维矩阵码（含堆叠式的 PDF_417）。
///
/// 这几类的静默区由规范定为 4 模块，而一维条码需要更宽的空白才能可靠扫描。
fn is_matrix_format(fmt: BarcodeFormat) -> bool {
    matches!(
        fmt,
        BarcodeFormat::QR_CODE
            | BarcodeFormat::DATA_MATRIX
            | BarcodeFormat::AZTEC
            | BarcodeFormat::PDF_417
    )
}

/// 自适应二值化：像素低于所在窗口的局部均值判黑。
///
/// 用来对付**大范围亮度梯度**：拍屏幕时的眩光会把画面一侧整体抬亮，
/// zxing 的 `HybridBinarizer` 分块阈值跟着偏，黑模块被判成白，
/// finder pattern 就凑不齐了。局部窗口均值各处各自为政，
/// 不受整幅图亮度基准的牵引。
///
/// `block` 是窗口边长，按码的模块尺度选：太小会被单个模块自己带偏
/// （窗口内全是黑块时均值≈黑，判不出边界），太大则退化成全局阈值。
/// 取两档分别试，总有一档对得上码的尺度。
fn adaptive_binarize(src: &image::GrayImage, block: u32) -> image::GrayImage {
    let (w, h) = (src.width() as usize, src.height() as usize);
    let r = block as usize / 2;
    // 积分图把「任意矩形求和」压到 O(1)；否则逐像素开窗是 O(w*h*block²)，慢到没法用。
    let stride = w + 1;
    let mut integral = vec![0u64; stride * (h + 1)];
    for y in 0..h {
        let mut row = 0u64;
        for x in 0..w {
            row += u64::from(src.get_pixel(x as u32, y as u32).0[0]);
            integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + row;
        }
    }
    let rect_sum = |x0: usize, y0: usize, x1: usize, y1: usize| -> u64 {
        // 必须先加后减：按 `A-B-C+D` 的自然顺序求值时，`(A-B)-C` 这一步
        // 中间量会为负（C 含有 A-B 没有的行），u64 直接溢出 panic。
        // 而矩形和恒 >= 0 意味着 A+D >= B+C，所以 `A+D-B-C` 全程不为负。
        let a = integral[y1 * stride + x1];
        let b = integral[y0 * stride + x1];
        let c = integral[y1 * stride + x0];
        let d = integral[y0 * stride + x0];
        a + d - b - c
    };

    image::GrayImage::from_fn(src.width(), src.height(), |x, y| {
        let (x, y) = (x as usize, y as usize);
        let (x0, y0) = (x.saturating_sub(r), y.saturating_sub(r));
        let (x1, y1) = ((x + r + 1).min(w), (y + r + 1).min(h));
        let n = ((x1 - x0) * (y1 - y0)).max(1) as u64;
        let mean = rect_sum(x0, y0, x1, y1) / n;
        let v = u64::from(src.get_pixel(x as u32, y as u32).0[0]);
        image::Luma([if v < mean { 0u8 } else { 255 }])
    })
}

/// 解一遍并转成 [`DecodedCode`]；没解出任何码时返回 `None`。
fn try_detect(luma_raw: Vec<u8>, width: u32, height: u32) -> Option<Vec<DecodedCode>> {
    let results = rxing::helpers::detect_multiple_in_luma(luma_raw, width, height).ok()?;
    if results.is_empty() {
        return None;
    }
    Some(
        results
            .into_iter()
            .map(|r| DecodedCode {
                format: format!("{:?}", r.getBarcodeFormat()),
                payload: r.getText().to_string(),
            })
            .collect(),
    )
}

/// 从 RGBA8 像素 buffer 解码图中所有二维码/条形码。
///
/// 解不出来时返回错误，错误文案只说「没识别出码」——具体的形态
/// （是真没码，还是有码但拍糊了）调用方无从分辨，一并给出建议比分类更有用。
pub fn decode_image(buf: Vec<u8>, width: u32, height: u32) -> anyhow::Result<Vec<DecodedCode>> {
    anyhow::ensure!(width > 0 && height > 0, "图像尺寸无效");
    anyhow::ensure!(
        buf.len() as u64 == width as u64 * height as u64 * 4,
        "buffer 长度与尺寸不匹配: expected {}, got {}",
        width as u64 * height as u64 * 4,
        buf.len()
    );
    let rgba = image::RgbaImage::from_raw(width, height, buf)
        .ok_or_else(|| anyhow::anyhow!("无法构造图像"))?;
    let luma = image::DynamicImage::ImageRgba8(rgba).into_luma8();

    // 第一遍走原图：干净图（截图、生成的条码）一次就中，也是一维条形码
    // 最稳的路径——先做一遍二值化对它们只有风险没有收益。
    if let Some(codes) = try_detect(luma.clone().into_raw(), width, height) {
        return Ok(codes);
    }

    // 空手而归才上预处理，代价只落在本来就解不出的图上。
    for &block in &[64u32, 192] {
        let binary = adaptive_binarize(&luma, block);
        if let Some(codes) = try_detect(binary.into_raw(), width, height) {
            return Ok(codes);
        }
    }

    Err(anyhow::anyhow!("未识别到二维码或条形码"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qr_generate_decode_roundtrip() {
        let payload = "l78z://test?x=1";
        let png = generate_qr_png(payload.to_string(), 300).unwrap();
        let img = image::load_from_memory(&png).unwrap().into_rgba8();
        let codes = decode_image(img.clone().into_raw(), img.width(), img.height()).unwrap();
        assert!(!codes.is_empty());
        assert_eq!(codes[0].payload, payload);
        assert_eq!(codes[0].format, "QR_CODE");
    }

    /// 每种格式配一个符合其字符集与长度约束的样例。
    ///
    /// 商品码最后一位是校验位：zxing 会自行计算并覆盖，这里给的都是
    /// 校验位正确的值，否则解出的末位会与输入不同。
    const BARCODE_CASES: &[(&str, &str)] = &[
        ("QR_CODE", "https://example.com/l78z"),
        ("DATA_MATRIX", "L78Z-DM-0001"),
        ("AZTEC", "L78Z-AZ-0001"),
        ("PDF_417", "L78Z-PDF417-payload"),
        ("EAN_13", "9780201379624"),
        ("EAN_8", "96385074"),
        ("UPC_A", "036000291452"),
        ("UPC_E", "01234565"),
        ("CODE_128", "L78Z-CODE128"),
        ("CODE_39", "L78Z-39"),
        ("CODE_93", "L78Z-93"),
        ("ITF", "123456"),
        ("CODABAR", "A123456A"),
        ("TELEPEN", "L78Z-TELEPEN"),
    ];

    /// 只能生成、扫不回来的格式。
    ///
    /// - TELEPEN：rxing 的解码端由 full_barcode_format_support 覆盖
    ///   aztec/maxicode/qrcode/datamatrix/oned/pdf417，其中没有 telepen 的 reader。
    /// - UPC_E：rxing 0.9.3 自身的缺陷。生成端会校验末位（"01234567" 会被拒为
    ///   "Contents do not pass checksum"），说明码本身是正确的；但解码端无论用
    ///   默认策略、TryHarder、限定 UPC-E reader 还是 PureBarcode，一律返回
    ///   NotFoundException。用别的扫码工具可以正常识别。
    const ENCODE_ONLY: &[&str] = &["TELEPEN", "UPC_E"];

    #[test]
    fn barcode_roundtrip_all_formats() {
        for (format, payload) in BARCODE_CASES {
            // 报错必须带上格式名：14 种混在一次测试里失败，否则无从定位。
            let png = generate_barcode_png(
                (*format).to_string(),
                (*payload).to_string(),
                500,
                300,
            )
            .unwrap_or_else(|e| panic!("{format} 生成失败: {e}"));

            let img = image::load_from_memory(&png)
                .unwrap_or_else(|e| panic!("{format} 不是合法 PNG: {e}"))
                .into_rgba8();

            if ENCODE_ONLY.contains(format) {
                // 退而求其次：只要图上有墨就行，免得拿到一张全白的空图
                // 还当成生成成功了。
                assert!(
                    img.pixels().any(|p| p.0[0] < 128),
                    "{format} 生成的图全是空白"
                );
                continue;
            }

            let codes = decode_image(img.clone().into_raw(), img.width(), img.height())
                .unwrap_or_else(|e| panic!("{format} 解码失败: {e}"));
            assert!(!codes.is_empty(), "{format} 没解出任何码");
            assert_eq!(codes[0].format, *format, "{format} 解出的格式不符");

            // CODABAR 的首尾 A/B/C/D 是码结构的一部分，但 zxing 的 reader
            // 返回内容时会把它们剥掉，所以解出的必然比输入短两个字符。
            let expected = if *format == "CODABAR" {
                payload[1..payload.len() - 1].to_string()
            } else {
                (*payload).to_string()
            };
            assert_eq!(codes[0].payload, expected, "{format} 内容不符");
        }
    }

    #[test]
    fn barcode_unknown_format_is_rejected() {
        let err = generate_barcode_png(
            "NOT_A_FORMAT".into(),
            "whatever".into(),
            200,
            100,
        )
        .unwrap_err()
        .to_string();
        assert!(err.contains("不支持的条码格式"), "报错应说明格式不认识: {err}");
    }

    #[test]
    fn barcode_rejects_empty_content() {
        let err = generate_barcode_png("QR_CODE".into(), String::new(), 200, 100)
            .unwrap_err()
            .to_string();
        assert!(err.contains("不能为空"), "报错应说明内容为空: {err}");
    }

    #[test]
    fn barcode_invalid_content_names_the_format() {
        // EAN_13 只收数字，塞字母必须失败，且报错要带上格式名方便排查。
        let err = generate_barcode_png(
            "EAN_13".into(),
            "not-a-number".into(),
            400,
            200,
        )
        .unwrap_err()
        .to_string();
        assert!(err.contains("EAN_13"), "报错应带上格式名: {err}");
    }

    /// 拍屏幕的照片：眩光把画面一侧整体抬亮，zxing 的分块阈值跟着偏，
    /// 黑模块被判成白、finder pattern 凑不齐——必须靠自适应二值化重试救回来。
    ///
    /// 样本取自真机扫码失败时的应用内截屏（预览区裁出），是这次修复的
    /// 原始证据；`decode_image` 改回单遍解码的话这张图立刻会挂。
    #[test]
    fn decode_screen_photo_with_glare() {
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/photo_full.png");
        let img = image::open(path).expect("拍照样本缺失，回归测试无法进行");
        let rgba = img.to_rgba8();
        let (width, height) = (rgba.width(), rgba.height());
        let codes = decode_image(rgba.into_raw(), width, height)
            .expect("眩光样本应能经自适应二值化重试解出");
        assert_eq!(codes[0].format, "QR_CODE");
        assert!(
            codes[0].payload.contains("\"token\""),
            "payload 应是配对 JSON: {}",
            codes[0].payload
        );
    }

    /// 线性对比度拉伸：把 P2~P98 灰度区间拉到 0~255。
    ///
    /// 拍屏幕的照片被眩光抬高了整体亮度，黑色模块不黑；这一步把亮度基准压回去。
    #[cfg(test)]
    fn stretch_contrast(src: &image::GrayImage) -> image::GrayImage {
        let mut hist = [0u32; 256];
        for p in src.pixels() {
            hist[p.0[0] as usize] += 1;
        }
        let total = u64::from(src.width()) * u64::from(src.height());

        let mut lo = 0u8;
        let mut acc = 0u64;
        for (i, &c) in hist.iter().enumerate() {
            acc += u64::from(c);
            if acc * 100 >= total * 2 {
                lo = i as u8;
                break;
            }
        }
        let mut hi = 255u8;
        acc = 0;
        for (i, &c) in hist.iter().enumerate().rev() {
            acc += u64::from(c);
            if acc * 100 >= total * 2 {
                hi = i as u8;
                break;
            }
        }

        let span = u32::from(hi.saturating_sub(lo)).max(1);
        image::GrayImage::from_fn(src.width(), src.height(), |x, y| {
            let v = u32::from(src.get_pixel(x, y).0[0]);
            let (lo, hi) = (u32::from(lo), u32::from(hi));
            let v = if v <= lo {
                0
            } else if v >= hi {
                255
            } else {
                ((v - lo) * 255 / span) as u8
            };
            image::Luma([v])
        })
    }

    /// 对拍照样本跑多策略解码，找出哪条路真的能解开。
    ///
    /// 手动跑：`cargo test scan_photo -- --ignored --nocapture`
    ///
    /// 标 `ignore` 是因为要读真实照片、跑二十遍解码，比单元测试慢一个量级，
    /// 没理由让每次 `cargo test` 都背这份开销。
    #[test]
    #[ignore = "需要真实拍照样本，手动跑"]
    fn scan_photo_strategies() {
        let dir = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures");

        for name in ["photo_full.png", "photo_qr.png"] {
            let img = image::open(format!("{dir}/{name}"))
                .unwrap_or_else(|e| panic!("样本 {name} 读取失败: {e}"));
            let gray = img.to_luma8();
            println!("\n=== {name} {}x{} ===", gray.width(), gray.height());

            // 候选预处理，逐个喂给解码器对比。
            let mut cases: Vec<(&str, image::GrayImage)> = vec![("原图", gray.clone())];
            if gray.width().max(gray.height()) > 1024 {
                cases.push((
                    "降采样1024",
                    img.resize(1024, 1024, image::imageops::FilterType::Lanczos3)
                        .to_luma8(),
                ));
            }
            cases.push(("对比度拉伸", stretch_contrast(&gray)));
            cases.push(("自适应64", adaptive_binarize(&gray, 64)));
            cases.push(("自适应192", adaptive_binarize(&gray, 192)));

            for (label, luma) in &cases {
                let strategies = [
                    // TryHarder 是 helpers 默认就开的，这里显式列出做对照基线。
                    (
                        "TryHarder",
                        rxing::DecodeHints {
                            TryHarder: Some(true),
                            ..Default::default()
                        },
                    ),
                    // PureBarcode 跳过 finder pattern 搜索，把整图当码来采样，
                    // 读错的模块只能靠纠错兜住——它同时是纠错的上场通道。
                    (
                        "PureBarcode",
                        rxing::DecodeHints {
                            PureBarcode: Some(true),
                            ..Default::default()
                        },
                    ),
                ];
                for (hint_label, mut hints) in strategies {
                    let outcome = rxing::helpers::detect_multiple_in_luma_with_hints(
                        luma.clone().into_raw(),
                        luma.width(),
                        luma.height(),
                        &mut hints,
                    );
                    match outcome {
                        Ok(v) if !v.is_empty() => {
                            let text = v[0].getText();
                            println!("  {label:8} / {hint_label:11} ✅ {text}");
                        }
                        Ok(_) => println!("  {label:8} / {hint_label:11} ❌ 空结果"),
                        Err(e) => println!("  {label:8} / {hint_label:11} ❌ {e}"),
                    }
                }
            }
        }
    }
}
