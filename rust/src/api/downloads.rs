use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use zip::write::{FileOptions, ZipWriter};
use zip::CompressionMethod;

use crate::api::chapters::get_chapter_pages;
use crate::api::models::{CbzMetadata, LibraryInfo, StoragePaths, WebtoonLibraryItem};
use crate::http;

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
    let file = File::create(&cbz_path).map_err(|e| format!("Erreur création CBZ: {}", e))?;

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
