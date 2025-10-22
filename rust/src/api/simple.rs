#[derive(Debug, Clone)]
pub struct WebtoonResult {
    pub title: String,
    pub author: String,
    pub views: String,
    pub url: String,
    pub cover_url: String,
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

    let link_selector = scraper::Selector::parse("a.link._card_item")
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
}
