use serde::Deserialize;

#[derive(Debug, Clone)]
pub struct WebtoonResult {
    pub title_no: String,
    pub title: String,
    pub author: String,
    pub views: String,
    pub url: String,
    pub cover_url: String,
}

#[derive(Debug, Deserialize)]
pub struct ApiEpisodesResponse {
    result: ApiEpisodesResult,
}

#[derive(Debug, Deserialize)]
pub struct ApiEpisodesResult {
    #[serde(rename = "episodeList")]
    episode_list: Vec<ApiEpisodeItem>,
}

#[derive(Debug, Deserialize)]
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

/// Recherche des webtoons sur Webtoons.com par scraping HTML
pub fn search_webtoons(keyword: String) -> Result<Vec<WebtoonResult>, String> {
    // Construire l'URL de recherche
    let url = format!(
        "https://www.webtoons.com/en/search?keyword={}",
        urlencoding::encode(&keyword)
    );

    // Faire la requête HTTP
    let response = reqwest::blocking::get(&url).map_err(|e| format!("Erreur réseau: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Erreur HTTP: {}", response.status()));
    }

    // Récupérer le HTML
    let html = response
        .text()
        .map_err(|e| format!("Erreur lecture HTML: {}", e))?;

    // Parser le HTML
    let document = scraper::Html::parse_document(&html);

    // Sélecteur pour les éléments li contenant les webtoons
    let li_selector = scraper::Selector::parse("li").map_err(|_| "Erreur création sélecteur li")?;

    let link_selector = scraper::Selector::parse("a.link._card_item[data-webtoon-type='WEBTOON']")
        .map_err(|_| "Erreur création sélecteur link")?;

    let title_selector =
        scraper::Selector::parse("strong.title").map_err(|_| "Erreur création sélecteur title")?;

    let author_selector =
        scraper::Selector::parse("div.author").map_err(|_| "Erreur création sélecteur author")?;

    let views_selector = scraper::Selector::parse("div.view_count")
        .map_err(|_| "Erreur création sélecteur views")?;

    let img_selector =
        scraper::Selector::parse("img").map_err(|_| "Erreur création sélecteur img")?;

    let mut results = Vec::new();

    // Parcourir tous les éléments li
    for li_element in document.select(&li_selector) {
        // Chercher le lien dans ce li
        if let Some(link) = li_element.select(&link_selector).next() {
            // Extraire l'URL
            let url = link.value().attr("href").unwrap_or("").to_string();

            // Extraitre le title_no depuis l'attribut data-title-no
            let title_no = link.value().attr("data-title-no").unwrap_or("").to_string();

            // Extraire le titre
            let title = link
                .select(&title_selector)
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();

            // Si pas de titre, on skip
            if title.is_empty() {
                continue;
            }

            // Extraire l'auteur
            let author = link
                .select(&author_selector)
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();

            // Extraire les vues
            let views = link
                .select(&views_selector)
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();

            // Extraire l'URL de la cover
            let cover_url = link
                .select(&img_selector)
                .next()
                .and_then(|img| img.value().attr("src"))
                .unwrap_or("")
                .to_string();

            results.push(WebtoonResult {
                title_no,
                title,
                author,
                views,
                url,
                cover_url,
            });
        }
    }

    Ok(results)
}

/// Récupère la liste des chapitres d'un webtoon via l'API moderne
pub fn get_webtoon_episodes(title_no: String) -> Result<Vec<ApiEpisodeItem>, String> {
    // API moderne avec tous les épisodes
    let api_url = format!(
        "https://m.webtoons.com/api/v1/webtoon/{}/episodes?pageSize=99999",
        title_no
    );

    let client = reqwest::blocking::Client::builder()
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        .build()
        .map_err(|e| format!("Erreur client: {}", e))?;

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

    let mut chapters = Vec::new();

    for episode in api_response.result.episode_list {
        // Convertir le timestamp en date lisible
        let date = format_timestamp(episode.exposure_date_millis);

        chapters.push(ApiEpisodeItem {
            episode_no: episode.episode_no,
            episode_title: episode.episode_title,
            thumbnail: format!("https://webtoon-phinf.pstatic.net{}", episode.thumbnail),
            viewer_link: episode.viewer_link,
            exposure_date_millis: episode.exposure_date_millis,
            display_up: episode.display_up,
            has_bgm: episode.has_bgm,
        });
    }

    // Inverser pour avoir le chapitre 1 en premier
    chapters.reverse();

    Ok(chapters)
}

/// Convertit un timestamp en millisecondes en date lisible
fn format_timestamp(millis: i64) -> String {
    // Convertir en secondes
    let seconds = millis / 1000;

    // Calculer les composants de date (approximation simple)
    let days = seconds / 86400;

    // Calcul approximatif de la date
    let year = 1970 + (days / 365) as i32;
    let remaining_days = days % 365;
    let month = (remaining_days / 30).min(11) + 1;
    let day = (remaining_days % 30).max(1);

    format!("{:04}-{:02}-{:02}", year, month, day)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_search_webtoons() {
        let results = search_webtoons("solo leveling".to_string());
        assert!(results.is_ok());

        let results = results.unwrap();
        assert!(!results.is_empty());

        println!("Trouvé {} résultats:", results.len());
        for result in results.iter().take(3) {
            println!("  - {} par {}", result.title, result.cover_url);
        }
    }

    #[test]
    fn test_get_webtoon_episodes() {
        let title_no = "3596".to_string();
        let episodes = get_webtoon_episodes(title_no);
        assert!(episodes.is_ok());
        let episodes = episodes.unwrap();
        assert!(!episodes.is_empty());
        println!("Trouvé {} épisodes:", episodes.len());
        for episode in episodes.iter().take(3) {
            println!("  - {}", episode.episode_title);
        }
    }
}
