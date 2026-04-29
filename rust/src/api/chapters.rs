use crate::api::models::ChapterPage;
use crate::http;

pub fn get_chapter_pages(chap_url: String) -> Result<Vec<ChapterPage>, String> {
    let url = format!("https://www.webtoons.com{}", chap_url);
    let client = http::build_client()?;

    let response = client
        .get(&url)
        .send()
        .map_err(|e| format!("Erreur réseau: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Erreur HTTP: {}", response.status()));
    }

    let html = response
        .text()
        .map_err(|e| format!("Erreur lecture HTML: {}", e))?;

    let document = scraper::Html::parse_document(&html);

    let img_selector = scraper::Selector::parse("div#_imageList img._images")
        .map_err(|_| "Erreur sélecteur images")?;

    let mut pages = Vec::new();

    for (index, img) in document.select(&img_selector).enumerate() {
        let image_url = img.value().attr("data-url").unwrap_or("").to_string();
        if image_url.is_empty() {
            continue;
        }

        let width = img
            .value()
            .attr("width")
            .and_then(|w| w.parse::<i32>().ok())
            .unwrap_or(800);

        let height = img
            .value()
            .attr("height")
            .and_then(|h| h.parse::<i32>().ok())
            .unwrap_or(1280);

        pages.push(ChapterPage {
            page_number: (index + 1) as i32,
            image_url,
            width,
            height,
        });
    }

    if pages.is_empty() {
        return Err("Aucune image trouvée dans ce chapitre".to_string());
    }

    Ok(pages)
}
