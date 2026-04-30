// Façade de compatibilité bridge — les implémentations sont dans les sous-modules.
pub use crate::api::models::{
    ApiEpisodeItem, BgChapterTask, BgDownloadProgress, CbzMetadata, ChapterPage, LibraryInfo,
    WebtoonLibraryItem, WebtoonResult,
};

pub fn search_webtoons(keyword: String, langage: String) -> Result<Vec<WebtoonResult>, String> {
    crate::api::search::search_webtoons(keyword, langage)
}

pub fn get_webtoon_episodes(title_no: String) -> Result<Vec<ApiEpisodeItem>, String> {
    crate::api::episodes::get_webtoon_episodes(title_no)
}

pub fn get_chapter_pages(chap_url: String) -> Result<Vec<ChapterPage>, String> {
    crate::api::chapters::get_chapter_pages(chap_url)
}

pub fn download_image(image_url: String) -> Result<Vec<u8>, String> {
    crate::api::downloads::download_image(image_url)
}

pub fn download_chapter_images(url: String) -> Result<Vec<Vec<u8>>, String> {
    crate::api::downloads::download_chapter_images(url)
}

pub fn download_chapter_as_cbz(
    base_path: String,
    webtoon_id: String,
    webtoon_title: String,
    chapter_url: String,
    chapter_number: i32,
    chapter_title: String,
) -> Result<CbzMetadata, String> {
    crate::api::downloads::download_chapter_as_cbz(
        base_path,
        webtoon_id,
        webtoon_title,
        chapter_url,
        chapter_number,
        chapter_title,
    )
}

pub fn get_library(base_path: String) -> Result<LibraryInfo, String> {
    crate::api::library::get_library(base_path)
}

pub fn get_webtoon_library(
    base_path: String,
    webtoon_id: String,
) -> Result<WebtoonLibraryItem, String> {
    crate::api::library::get_webtoon_library(base_path, webtoon_id)
}

pub fn save_webtoon_cover(
    base_path: String,
    webtoon_id: String,
    cover_url: String,
) -> Result<String, String> {
    crate::api::library::save_webtoon_cover(base_path, webtoon_id, cover_url)
}

pub fn start_background_download(
    base_path: String,
    webtoon_id: String,
    webtoon_title: String,
    chapters: Vec<BgChapterTask>,
) -> Result<(), String> {
    crate::api::downloads::start_background_download(
        base_path,
        webtoon_id,
        webtoon_title,
        chapters,
    )
}

pub fn poll_download_progress() -> BgDownloadProgress {
    crate::api::downloads::poll_download_progress()
}

pub fn cancel_background_download() {
    crate::api::downloads::cancel_background_download()
}

pub fn merge_cbz_files(
    base_path: String,
    webtoon_id: String,
    webtoon_title: String,
    chapter_numbers: Vec<i32>,
    output_name: String,
) -> Result<String, String> {
    crate::api::downloads::merge_cbz_files(
        base_path,
        webtoon_id,
        webtoon_title,
        chapter_numbers,
        output_name,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_webtoons() {
        let results = search_webtoons("solo leveling".to_string(), "en".to_string());
        assert!(results.is_ok());
        let results = results.unwrap();
        assert!(!results.is_empty());
        for result in results.iter().take(3) {
            println!("  - {} par {}", result.title, result.cover_url);
        }
    }

    #[test]
    fn test_get_webtoon_episodes() {
        let episodes = get_webtoon_episodes("3596".to_string());
        assert!(episodes.is_ok());
        let episodes = episodes.unwrap();
        assert!(!episodes.is_empty());
        for ep in episodes.iter().take(3) {
            println!("  - {}", ep.episode_title);
        }
    }

    #[test]
    fn test_get_chapter_pages() {
        let pages = get_chapter_pages(
            "/en/fantasy/the-greatest-estate-developer/episode-1/viewer?title_no=3596&episode_no=1"
                .to_string(),
        );
        assert!(pages.is_ok());
        let pages = pages.unwrap();
        assert!(!pages.is_empty());
        for page in pages.iter().take(3) {
            println!("  - {}", page.image_url);
        }
    }
}
