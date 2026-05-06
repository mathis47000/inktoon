use std::fs;

use crate::api::downloads::download_image;
use crate::api::models::{LibraryInfo, StoragePaths, WebtoonLibraryItem};

pub fn get_library(base_path: String) -> Result<LibraryInfo, String> {
    let paths = StoragePaths::new(base_path)?;

    if !paths.library_index.exists() {
        return Ok(LibraryInfo { webtoons: vec![] });
    }

    let content = fs::read_to_string(&paths.library_index)
        .map_err(|e| format!("Erreur lecture index: {}", e))?;

    serde_json::from_str::<LibraryInfo>(&content)
        .map_err(|e| format!("Erreur parsing JSON: {}", e))
}

pub fn get_webtoon_library(
    base_path: String,
    webtoon_id: String,
) -> Result<WebtoonLibraryItem, String> {
    get_library(base_path)?
        .webtoons
        .into_iter()
        .find(|w| w.webtoon_id == webtoon_id)
        .ok_or_else(|| format!("Webtoon {} non trouvé", webtoon_id))
}

pub fn delete_chapter(
    base_path: String,
    webtoon_id: String,
    chapter_number: i32,
) -> Result<(), String> {
    let paths = StoragePaths::new(base_path)?;
    let cbz_path = paths.cbz_path(&webtoon_id, chapter_number);
    if cbz_path.exists() {
        fs::remove_file(&cbz_path)
            .map_err(|e| format!("Erreur suppression fichier: {}", e))?;
    }
    let mut library = read_library(&paths)?;
    if let Some(webtoon) = library.webtoons.iter_mut().find(|w| w.webtoon_id == webtoon_id) {
        webtoon.chapters.retain(|c| c.chapter_number != chapter_number);
        webtoon.total_size = webtoon.chapters.iter().map(|c| c.file_size).sum();
    }
    // Remove webtoon entry entirely if no chapters remain.
    library.webtoons.retain(|w| !w.chapters.is_empty());
    write_library(&paths, &library)
}

pub fn delete_webtoon(base_path: String, webtoon_id: String) -> Result<(), String> {
    let paths = StoragePaths::new(base_path)?;
    let webtoon_dir = paths.webtoon_dir(&webtoon_id);
    if webtoon_dir.exists() {
        fs::remove_dir_all(&webtoon_dir)
            .map_err(|e| format!("Erreur suppression dossier: {}", e))?;
    }
    let mut library = read_library(&paths)?;
    library.webtoons.retain(|w| w.webtoon_id != webtoon_id);
    write_library(&paths, &library)
}

fn read_library(paths: &StoragePaths) -> Result<LibraryInfo, String> {
    if !paths.library_index.exists() {
        return Ok(LibraryInfo { webtoons: vec![] });
    }
    let content = fs::read_to_string(&paths.library_index)
        .map_err(|e| format!("Erreur lecture index: {}", e))?;
    Ok(serde_json::from_str::<LibraryInfo>(&content)
        .unwrap_or(LibraryInfo { webtoons: vec![] }))
}

fn write_library(paths: &StoragePaths, library: &LibraryInfo) -> Result<(), String> {
    let json = serde_json::to_string_pretty(library)
        .map_err(|e| format!("Erreur sérialisation: {}", e))?;
    fs::write(&paths.library_index, json)
        .map_err(|e| format!("Erreur écriture index: {}", e))
}

pub fn save_webtoon_cover(
    base_path: String,
    webtoon_id: String,
    cover_url: String,
) -> Result<String, String> {
    let paths = StoragePaths::new(base_path)?;
    let webtoon_dir = paths.webtoon_dir(&webtoon_id);
    fs::create_dir_all(&webtoon_dir)
        .map_err(|e| format!("Erreur création dossier: {}", e))?;

    let image_data = download_image(cover_url)?;
    let cover_path = paths.cover_path(&webtoon_id);
    fs::write(&cover_path, image_data)
        .map_err(|e| format!("Erreur sauvegarde couverture: {}", e))?;

    Ok(cover_path.to_string_lossy().to_string())
}
