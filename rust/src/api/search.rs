use crate::api::models::WebtoonResult;

pub fn search_webtoons(keyword: String, langage: String) -> Result<Vec<WebtoonResult>, String> {
    let url = format!(
        "https://www.webtoons.com/{}/search?keyword={}",
        langage,
        urlencoding::encode(&keyword)
    );

    let response =
        reqwest::blocking::get(&url).map_err(|e| format!("Erreur réseau: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Erreur HTTP: {}", response.status()));
    }

    let html = response
        .text()
        .map_err(|e| format!("Erreur lecture HTML: {}", e))?;

    let document = scraper::Html::parse_document(&html);

    let li_selector =
        scraper::Selector::parse("li").map_err(|_| "Erreur sélecteur li")?;
    let link_selector =
        scraper::Selector::parse("a.link._card_item[data-webtoon-type='WEBTOON']")
            .map_err(|_| "Erreur sélecteur link")?;
    let title_selector =
        scraper::Selector::parse("strong.title").map_err(|_| "Erreur sélecteur title")?;
    let author_selector =
        scraper::Selector::parse("div.author").map_err(|_| "Erreur sélecteur author")?;
    let views_selector =
        scraper::Selector::parse("div.view_count").map_err(|_| "Erreur sélecteur views")?;
    let img_selector =
        scraper::Selector::parse("img").map_err(|_| "Erreur sélecteur img")?;

    let mut results = Vec::new();

    for li in document.select(&li_selector) {
        if let Some(link) = li.select(&link_selector).next() {
            let url = link.value().attr("href").unwrap_or("").to_string();
            let title_no = link
                .value()
                .attr("data-title-no")
                .unwrap_or("")
                .to_string();
            let title = link
                .select(&title_selector)
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();

            if title.is_empty() {
                continue;
            }

            let author = link
                .select(&author_selector)
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();
            let views = link
                .select(&views_selector)
                .next()
                .map(|el| el.text().collect::<String>())
                .unwrap_or_default();
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
