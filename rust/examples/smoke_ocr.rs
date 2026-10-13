use rust_lib_l78z::api::ocr::ocr_image;

fn main() {
    let dir = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "../assets/ocr".to_string());
    // 一张空白灰度图，用于验证模型加载 + 推理管线
    let (w, h) = (320u32, 80u32);
    let mut buf = vec![255u8; (w * h * 4) as usize];
    // 画几条黑色横线，模拟文字区域
    for y in 30..50 {
        for x in 20..300 {
            let i = ((y * w + x) * 4) as usize;
            buf[i] = 0;
            buf[i + 1] = 0;
            buf[i + 2] = 0;
        }
    }
    let blocks = ocr_image(buf, w, h, dir).expect("ocr failed");
    println!("blocks: {}", blocks.len());
    for b in &blocks {
        println!("  score={:.3} text={:?}", b.score, b.text);
    }
}
