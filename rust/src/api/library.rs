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
