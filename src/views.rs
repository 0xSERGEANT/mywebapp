use super::models;

fn escape_html(input: &str) -> String {
    let mut escaped = String::with_capacity(input.len());
    for c in input.chars() {
        match c {
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '&' => escaped.push_str("&amp;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#x27;"),
            _ => escaped.push(c),
        }
    }

    escaped
}

pub fn root_page() -> String {
    "<h1>Simple Inventory API</h1>
    <ul>
        <li><a href='/items'>GET /items</a> - Items inventory</li>
        <li>POST /items - Create Item</li>
        <li>GET /items/&lt;id&gt; - Item Details</li>
        <li><a href='/health/alive'>GET /health/alive</a> - Liveness probe</li>
        <li><a href='/health/ready'>GET /health/ready</a> - Readiness probe</li>
    </ul>"
        .to_string()
}

pub fn items_list(items: &[models::ItemListEntry]) -> String {
    let mut rows = String::new();
    for item in items {
        rows.push_str(&format!(
            "<tr><td>{}</td><td><a href='/items/{}'>{}</a></td></tr>",
            item.id,
            item.id,
            escape_html(&item.name)
        ));
    }

    format!(
        "<h1>Inventory</h1><table border='1'><tr><th>ID</th><th>Name</th></tr>{}</table>",
        rows
    )
}

pub fn item_detail(item: &models::Item) -> String {
    format!(
        "<h1>Item Details</h1>
        <p><b>ID:</b> {}</p>
        <p><b>Name:</b> {}</p>
        <p><b>Quantity:</b> {}</p>
        <p><b>Created At:</b> {}</p>
        <a href='/items'>Back to Items</a>",
        item.id,
        escape_html(&item.name),
        item.quantity,
        item.created_at
    )
}

pub fn item_created(item: &models::Item) -> String {
    format!(
        "<h1>Item Created</h1><p>Item created: {} (ID: {})</p><a href='/items'>Back to Items</a>",
        escape_html(&item.name),
        item.id
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Item, ItemListEntry};
    use chrono::Utc;

    fn sample_item() -> Item {
        Item {
            id: 1,
            name: "bolt".to_string(),
            quantity: 42,
            created_at: Utc::now(),
        }
    }

    #[test]
    fn escape_lt_gt() {
        assert_eq!(escape_html("<b>"), "&lt;b&gt;");
    }

    #[test]
    fn escape_amp() {
        assert_eq!(escape_html("a&b"), "a&amp;b");
    }

    #[test]
    fn escape_quotes() {
        assert_eq!(escape_html("\"x\""), "&quot;x&quot;");
    }

    #[test]
    fn escape_single_quote() {
        assert_eq!(escape_html("it's"), "it&#x27;s");
    }

    #[test]
    fn root_page_has_items_link() {
        assert!(root_page().contains("/items"));
    }

    #[test]
    fn root_page_has_health_links() {
        let p = root_page();
        assert!(p.contains("/health/alive"));
        assert!(p.contains("/health/ready"));
    }

    #[test]
    fn items_list_empty_renders_table() {
        let html = items_list(&[]);
        assert!(html.contains("<table"));
        assert!(html.contains("Inventory"));
    }

    #[test]
    fn items_list_shows_item() {
        let html = items_list(&[ItemListEntry {
            id: 1,
            name: "bolt".to_string(),
        }]);
        assert!(html.contains("bolt"));
        assert!(html.contains("/items/1"));
    }

    #[test]
    fn items_list_escapes_xss() {
        let xss = ItemListEntry {
            id: 2,
            name: "<script>alert(1)</script>".to_string(),
        };
        let html = items_list(&[xss]);
        assert!(!html.contains("<script>"));
        assert!(html.contains("&lt;script&gt;"));
    }

    #[test]
    fn item_detail_shows_all_fields() {
        let html = item_detail(&sample_item());
        assert!(html.contains("bolt"));
        assert!(html.contains("42"));
    }

    #[test]
    fn item_detail_escapes_name() {
        let item = Item {
            id: 1,
            name: "<b>x</b>".to_string(),
            quantity: 1,
            created_at: Utc::now(),
        };

        let html = item_detail(&item);
        assert!(!html.contains("<b>x</b>"));
        assert!(html.contains("&lt;b&gt;x&lt;/b&gt;"));
    }

    #[test]
    fn item_created_shows_name() {
        let html = item_created(&sample_item());
        assert!(html.contains("bolt"));
        assert!(html.contains("Item Created"));
    }
}
