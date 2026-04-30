use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use zip::write::{FileOptions, ZipWriter};
use zip::CompressionMethod;

use crate::api::chapters::get_chapter_pages;
use crate::api::models::{
    BgChapterTask, BgDownloadProgress, CbzMetadata, ChapterPage, LibraryInfo, StoragePaths,
    WebtoonLibraryItem,
};
use crate::http;

// ── Background download state ──────────────────────────────────────────────────

struct BgState {
    progress: BgDownloadProgress,
    cancel: Arc<AtomicBool>,
}

static BG_STATE: OnceLock<Arc<Mutex<BgState>>> = OnceLock::new();

fn bg_state() -> Arc<Mutex<BgState>> {
    BG_STATE
        .get_or_init(|| {
            Arc::new(Mutex::new(BgState {
                progress: BgDownloadProgress::default(),
                cancel: Arc::new(AtomicBool::new(false)),
            }))
        })
        .clone()
}

pub fn start_background_download(
    base_path: String,
    webtoon_id: String,
    webtoon_title: String,
    chapters: Vec<BgChapterTask>,
) -> Result<(), String> {
    let global = bg_state();

    let cancel = {
        let mut s = global.lock().unwrap();
        if s.progress.is_running {
            return Err("Un téléchargement est déjà en cours".to_string());
        }
        let cancel = Arc::new(AtomicBool::new(false));
        s.cancel = cancel.clone();
        s.progress = BgDownloadProgress {
            is_running: true,
            total: chapters.len() as i32,
            status: "Démarrage…".to_string(),
            ..Default::default()
        };
        cancel
    };

    std::thread::spawn(move || {
        let total = chapters.len() as i32;

        for (i, task) in chapters.iter().enumerate() {
            if cancel.load(Ordering::Relaxed) {
                let mut s = global.lock().unwrap();
                s.progress.is_running = false;
                s.progress.is_done = true;
                s.progress.error = Some("Annulé".to_string());
                return;
            }

            {
                let mut s = global.lock().unwrap();
                s.progress.current = i as i32;
                s.progress.current_chapter = task.chapter_number;
                s.progress.current_page = 0;
                s.progress.total_pages = 0;
                s.progress.status = format!("Ch. {}", task.chapter_number);
            }

            match download_chapter_tracked(
                &base_path,
                &webtoon_id,
                &webtoon_title,
                task.chapter_url.clone(),
                task.chapter_number,
                task.chapter_title.clone(),
                &global,
                &cancel,
            ) {
                Ok(_) => {
                    let mut s = global.lock().unwrap();
                    s.progress.current = (i + 1) as i32;
                }
                Err(e) => {
                    let mut s = global.lock().unwrap();
                    s.progress.is_running = false;
                    s.progress.is_done = true;
                    s.progress.error = Some(e);
                    return;
                }
            }
        }

        let mut s = global.lock().unwrap();
        s.progress.is_running = false;
        s.progress.is_done = true;
        s.progress.current = total;
        s.progress.status = "Terminé".to_string();
    });

    Ok(())
}

pub fn poll_download_progress() -> BgDownloadProgress {
    bg_state().lock().unwrap().progress.clone()
}

pub fn cancel_background_download() {
    bg_state().lock().unwrap().cancel.store(true, Ordering::Relaxed);
}

// ── Single-chapter download ────────────────────────────────────────────────────

pub fn download_image(image_url: String) -> Result<Vec<u8>, String> {
    let client = http::build_client()?;
    let response = client
        .get(&image_url)
        .header("Referer", "https://www.webtoons.com/")
        .send()
        .map_err(|e| format!("Erreur téléchargement: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Erreur HTTP: {}", response.status()));
    }

    response
        .bytes()
        .map(|b| b.to_vec())
        .map_err(|e| format!("Erreur lecture bytes: {}", e))
}

pub fn download_chapter_images(url: String) -> Result<Vec<Vec<u8>>, String> {
    let pages = get_chapter_pages(url)?;
    let mut images = Vec::new();

    for (index, page) in pages.iter().enumerate() {
        println!("Téléchargement page {}/{}...", index + 1, pages.len());
        match download_image(page.image_url.clone()) {
            Ok(data) => images.push(data),
            Err(e) => eprintln!("Erreur page {}: {}", index + 1, e),
        }
        std::thread::sleep(std::time::Duration::from_millis(500));
    }

    if images.is_empty() {
        return Err("Aucune image téléchargée".to_string());
    }

    Ok(images)
}

pub fn download_chapter_as_cbz(
    base_path: String,
    webtoon_id: String,
    webtoon_title: String,
    chapter_url: String,
    chapter_number: i32,
    chapter_title: String,
) -> Result<CbzMetadata, String> {
    let paths = StoragePaths::new(base_path)?;
    let webtoon_dir = paths.webtoon_dir(&webtoon_id);
    fs::create_dir_all(&webtoon_dir)
        .map_err(|e| format!("Erreur création dossier: {}", e))?;

    let pages = get_chapter_pages(chapter_url)?;
    let cbz_path = paths.cbz_path(&webtoon_id, chapter_number);
    let tmp_path = tmp_path_for(&cbz_path);

    // Write to a temp file; rename atomically on success; delete on error.
    if let Err(e) = write_cbz(&tmp_path, &pages) {
        let _ = fs::remove_file(&tmp_path);
        return Err(e);
    }
    if let Err(e) = fs::rename(&tmp_path, &cbz_path) {
        let _ = fs::remove_file(&tmp_path);
        return Err(format!("Erreur finalisation: {}", e));
    }

    let file_size = fs::metadata(&cbz_path)
        .map_err(|e| format!("Erreur métadonnées: {}", e))?
        .len();

    let metadata = CbzMetadata {
        webtoon_id: webtoon_id.clone(),
        webtoon_title,
        chapter_number,
        chapter_title,
        page_count: pages.len() as i32,
        file_size,
        created_at: chrono::Utc::now().to_rfc3339(),
        file_path: cbz_path.to_string_lossy().to_string(),
    };

    update_library_index(&paths, &webtoon_id, metadata.clone())?;
    Ok(metadata)
}

// ── merge ──────────────────────────────────────────────────────────────────────

pub fn merge_cbz_files(
    base_path: String,
    webtoon_id: String,
    _webtoon_title: String,
    chapter_numbers: Vec<i32>,
    output_name: String,
) -> Result<String, String> {
    let paths = StoragePaths::new(base_path)?;
    let merged_path = paths
        .webtoon_dir(&webtoon_id)
        .join(format!("{}.cbz", output_name));

    let file = File::create(&merged_path)
        .map_err(|e| format!("Erreur création CBZ fusionné: {}", e))?;

    let mut zip = ZipWriter::new(file);
    let options = FileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .compression_level(Some(6));

    let mut global_page_num = 1u32;

    for chapter_num in chapter_numbers {
        let cbz_path = paths.cbz_path(&webtoon_id, chapter_num);
        if !cbz_path.exists() {
            eprintln!("Chapitre {} non trouvé, ignoré", chapter_num);
            continue;
        }

        let cbz_file =
            File::open(&cbz_path).map_err(|e| format!("Erreur ouverture CBZ: {}", e))?;
        let mut archive =
            zip::ZipArchive::new(cbz_file).map_err(|e| format!("Erreur lecture ZIP: {}", e))?;

        for i in 0..archive.len() {
            let mut entry = archive
                .by_index(i)
                .map_err(|e| format!("Erreur entrée ZIP: {}", e))?;

            if entry.is_dir() {
                continue;
            }

            let ext = Path::new(entry.name())
                .extension()
                .and_then(|s| s.to_str())
                .unwrap_or("jpg");

            let new_name = format!("page_{:04}.{}", global_page_num, ext);
            let mut buffer = Vec::new();
            std::io::copy(&mut entry, &mut buffer)
                .map_err(|e| format!("Erreur copie: {}", e))?;

            zip.start_file(&new_name, options)
                .map_err(|e| format!("Erreur ajout: {}", e))?;
            zip.write_all(&buffer)
                .map_err(|e| format!("Erreur écriture: {}", e))?;

            global_page_num += 1;
        }
    }

    zip.finish()
        .map_err(|e| format!("Erreur finalisation: {}", e))?;

    Ok(merged_path.to_string_lossy().to_string())
}

// ── tracked download (used by background thread) ─────────────────────────────

fn download_chapter_tracked(
    base_path: &str,
    webtoon_id: &str,
    webtoon_title: &str,
    chapter_url: String,
    chapter_number: i32,
    chapter_title: String,
    global: &Arc<Mutex<BgState>>,
    cancel: &Arc<AtomicBool>,
) -> Result<CbzMetadata, String> {
    let paths = StoragePaths::new(base_path.to_string())?;
    let webtoon_dir = paths.webtoon_dir(webtoon_id);
    fs::create_dir_all(&webtoon_dir)
        .map_err(|e| format!("Erreur création dossier: {}", e))?;

    let pages = get_chapter_pages(chapter_url)?;
    let total_pages = pages.len() as i32;
    { let mut s = global.lock().unwrap(); s.progress.total_pages = total_pages; }

    let cbz_path = paths.cbz_path(webtoon_id, chapter_number);
    let tmp_path = tmp_path_for(&cbz_path);

    let write_result = (|| -> Result<(), String> {
        let file = File::create(&tmp_path)
            .map_err(|e| format!("Erreur création CBZ: {}", e))?;
        let mut zip = ZipWriter::new(file);
        let options = FileOptions::default()
            .compression_method(CompressionMethod::Deflated)
            .compression_level(Some(6));

        for (i, page) in pages.iter().enumerate() {
            if cancel.load(Ordering::Relaxed) {
                return Err("Annulé".to_string());
            }
            { let mut s = global.lock().unwrap(); s.progress.current_page = i as i32 + 1; }

            let image_data = download_image(page.image_url.clone())?;
            let ext = detect_image_extension(&image_data);
            let filename = format!("page_{:03}.{}", i + 1, ext);
            zip.start_file(&filename, options)
                .map_err(|e| format!("Erreur ajout ZIP: {}", e))?;
            zip.write_all(&image_data)
                .map_err(|e| format!("Erreur écriture ZIP: {}", e))?;

            std::thread::sleep(std::time::Duration::from_millis(300));
        }

        zip.finish().map_err(|e| format!("Erreur finalisation ZIP: {}", e))?;
        Ok(())
    })();

    if let Err(e) = write_result {
        let _ = fs::remove_file(&tmp_path);
        return Err(e);
    }
    if let Err(e) = fs::rename(&tmp_path, &cbz_path) {
        let _ = fs::remove_file(&tmp_path);
        return Err(format!("Erreur finalisation: {}", e));
    }

    let file_size = fs::metadata(&cbz_path)
        .map_err(|e| format!("Erreur métadonnées: {}", e))?
        .len();

    let metadata = CbzMetadata {
        webtoon_id: webtoon_id.to_string(),
        webtoon_title: webtoon_title.to_string(),
        chapter_number,
        chapter_title,
        page_count: total_pages,
        file_size,
        created_at: chrono::Utc::now().to_rfc3339(),
        file_path: cbz_path.to_string_lossy().to_string(),
    };

    update_library_index(&paths, webtoon_id, metadata.clone())?;
    Ok(metadata)
}

// ── helpers ────────────────────────────────────────────────────────────────────

fn tmp_path_for(path: &Path) -> PathBuf {
    let name = path
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .into_owned();
    path.with_file_name(format!("{}.tmp", name))
}

fn write_cbz(tmp_path: &Path, pages: &[ChapterPage]) -> Result<(), String> {
    let file = File::create(tmp_path).map_err(|e| format!("Erreur création CBZ: {}", e))?;
    let mut zip = ZipWriter::new(file);
    let options = FileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .compression_level(Some(6));

    for (index, page) in pages.iter().enumerate() {
        let image_data = download_image(page.image_url.clone())?;
        let ext = detect_image_extension(&image_data);
        let filename = format!("page_{:03}.{}", index + 1, ext);

        zip.start_file(&filename, options)
            .map_err(|e| format!("Erreur ajout ZIP: {}", e))?;
        zip.write_all(&image_data)
            .map_err(|e| format!("Erreur écriture ZIP: {}", e))?;

        std::thread::sleep(std::time::Duration::from_millis(300));
    }

    zip.finish()
        .map_err(|e| format!("Erreur finalisation ZIP: {}", e))?;
    Ok(())
}

fn update_library_index(
    paths: &StoragePaths,
    webtoon_id: &str,
    chapter_metadata: CbzMetadata,
) -> Result<(), String> {
    let mut library = if paths.library_index.exists() {
        let content = fs::read_to_string(&paths.library_index)
            .map_err(|e| format!("Erreur lecture index: {}", e))?;
        serde_json::from_str::<LibraryInfo>(&content).unwrap_or(LibraryInfo { webtoons: vec![] })
    } else {
        LibraryInfo { webtoons: vec![] }
    };

    if let Some(webtoon) = library
        .webtoons
        .iter_mut()
        .find(|w| w.webtoon_id == webtoon_id)
    {
        if let Some(ch) = webtoon
            .chapters
            .iter_mut()
            .find(|c| c.chapter_number == chapter_metadata.chapter_number)
        {
            *ch = chapter_metadata.clone();
        } else {
            webtoon.chapters.push(chapter_metadata.clone());
        }
        webtoon.chapters.sort_by_key(|c| c.chapter_number);
        webtoon.total_size = webtoon.chapters.iter().map(|c| c.file_size).sum();
    } else {
        library.webtoons.push(WebtoonLibraryItem {
            webtoon_id: webtoon_id.to_string(),
            title: chapter_metadata.webtoon_title.clone(),
            cover_path: paths.cover_path(webtoon_id).to_string_lossy().to_string(),
            chapters: vec![chapter_metadata.clone()],
            total_size: chapter_metadata.file_size,
        });
    }

    let json = serde_json::to_string_pretty(&library)
        .map_err(|e| format!("Erreur sérialisation JSON: {}", e))?;

    fs::write(&paths.library_index, json)
        .map_err(|e| format!("Erreur écriture index: {}", e))
}

fn detect_image_extension(data: &[u8]) -> &'static str {
    if data.starts_with(&[0xFF, 0xD8, 0xFF]) {
        "jpg"
    } else if data.starts_with(&[0x89, 0x50, 0x4E, 0x47]) {
        "png"
    } else {
        "jpg"
    }
}
