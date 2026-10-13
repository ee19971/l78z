use rapidocr_core::model::{ModelCache, ModelDownloadMode, PPOCRV6_MEDIUM};

fn main() {
    let dir = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "../assets/ocr".to_string());
    println!("downloading ppocrv6-medium models into {dir}");
    std::fs::create_dir_all(&dir).expect("create model dir");
    let cache = ModelCache::new(&dir);
    cache
        .ensure_model_set(&PPOCRV6_MEDIUM, ModelDownloadMode::Missing)
        .expect("model download failed");
    println!("done: {}", cache.root().display());
}
