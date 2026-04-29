use serde::Deserialize;

use crate::api::models::ApiEpisodeItem;
use crate::http;

#[derive(Debug, Deserialize)]
struct ApiEpisodesResponse {
    result: ApiEpisodesResult,
}

#[derive(Debug, Deserialize)]
struct ApiEpisodesResult {
    #[serde(rename = "episodeList")]
    episode_list: Vec<RawEpisode>,
}

#[derive(Debug, Deserialize)]
struct RawEpisode {
    #[serde(rename = "episodeNo")]
    episode_no: i32,
    #[serde(rename = "episodeTitle")]
    episode_title: String,
    thumbnail: String,
    #[serde(rename = "viewerLink")]
    viewer_link: String,
    #[serde(rename = "exposureDateMillis")]
    exposure_date_millis: i64,
    #[serde(rename = "displayUp")]
    display_up: bool,
    #[serde(rename = "hasBgm")]
    has_bgm: bool,
}

pub fn get_webtoon_episodes(title_no: String) -> Result<Vec<ApiEpisodeItem>, String> {
    let api_url = format!(
        "https://m.webtoons.com/api/v1/webtoon/{}/episodes?pageSize=99999",
        title_no
    );

    let client = http::build_client()?;
    let response = client
        .get(&api_url)
        .send()
        .map_err(|e| format!("Erreur réseau: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Erreur HTTP: {}", response.status()));
    }

    let api_response: ApiEpisodesResponse = response
        .json()
        .map_err(|e| format!("Erreur parsing JSON: {}", e))?;

    let mut chapters: Vec<ApiEpisodeItem> = api_response
        .result
        .episode_list
        .into_iter()
        .map(|ep| ApiEpisodeItem {
            episode_no: ep.episode_no,
            episode_title: ep.episode_title,
            thumbnail: format!("https://webtoon-phinf.pstatic.net{}", ep.thumbnail),
            viewer_link: ep.viewer_link,
            exposure_date_millis: ep.exposure_date_millis,
            display_up: ep.display_up,
            has_bgm: ep.has_bgm,
        })
        .collect();

    chapters.reverse();
    Ok(chapters)
}
