use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct WebtoonResult {
    pub title_no: String,
    pub title: String,
    pub author: String,
    pub views: String,
    pub url: String,
    pub cover_url: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ApiEpisodeItem {
    #[serde(rename = "episodeNo")]
    pub episode_no: i32,
    #[serde(rename = "episodeTitle")]
    pub episode_title: String,
    pub thumbnail: String,
    #[serde(rename = "viewerLink")]
    pub viewer_link: String,
    #[serde(rename = "exposureDateMillis")]
    pub exposure_date_millis: i64,
    #[serde(rename = "displayUp")]
    pub display_up: bool,
    #[serde(rename = "hasBgm")]
    pub has_bgm: bool,
}

#[derive(Debug, Clone)]
pub struct ChapterPage {
    pub page_number: i32,
    pub image_url: String,
    pub width: i32,
    pub height: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CbzMetadata {
    pub webtoon_id: String,
    pub webtoon_title: String,
    pub chapter_number: i32,
    pub chapter_title: String,
    pub page_count: i32,
    pub file_size: u64,
    pub created_at: String,
    pub file_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LibraryInfo {
    pub webtoons: Vec<WebtoonLibraryItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebtoonLibraryItem {
    pub webtoon_id: String,
    pub title: String,
    pub cover_path: String,
    pub chapters: Vec<CbzMetadata>,
    pub total_size: u64,
}

/// Input: one chapter to download in a background job.
#[derive(Debug, Clone)]
pub struct BgChapterTask {
    pub chapter_url: String,
    pub chapter_number: i32,
    pub chapter_title: String,
}

/// Snapshot polled by Dart to track a background download.
#[derive(Debug, Clone)]
pub struct BgDownloadProgress {
    pub is_running: bool,
    pub current: i32,
    pub total: i32,
    pub current_chapter: i32,
    pub current_page: i32,
    pub total_pages: i32,
    pub status: String,
    pub is_done: bool,
    pub error: Option<String>,
}

impl Default for BgDownloadProgress {
    fn default() -> Self {
        Self {
            is_running: false,
            current: 0,
            total: 0,
            current_chapter: 0,
            current_page: 0,
            total_pages: 0,
            status: String::new(),
            is_done: false,
            error: None,
        }
    }
}

pub(crate) struct StoragePaths {
    webtoons_dir: PathBuf,
    pub(crate) library_index: PathBuf,
}

impl StoragePaths {
    pub(crate) fn new(base_path: String) -> Result<Self, String> {
        let base_dir = PathBuf::from(base_path);
        let webtoons_dir = base_dir.join("webtoons");
        let library_index = base_dir.join("library.json");

        std::fs::create_dir_all(&webtoons_dir)
            .map_err(|e| format!("Erreur création dossier: {}", e))?;

        Ok(Self {
            webtoons_dir,
            library_index,
        })
    }

    pub(crate) fn webtoon_dir(&self, webtoon_id: &str) -> PathBuf {
        self.webtoons_dir.join(webtoon_id)
    }

    pub(crate) fn cbz_path(&self, webtoon_id: &str, chapter_number: i32) -> PathBuf {
        self.webtoon_dir(webtoon_id)
            .join(format!("chapter_{:04}.cbz", chapter_number))
    }

    pub(crate) fn cover_path(&self, webtoon_id: &str) -> PathBuf {
        self.webtoon_dir(webtoon_id).join("cover.jpg")
    }
}
