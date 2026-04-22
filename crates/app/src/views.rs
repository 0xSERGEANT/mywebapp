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
    </ul>".to_string()
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
    
    format!("<h1>Inventory</h1><table border='1'><tr><th>ID</th><th>Name</th></tr>{}</table>", rows)
}

pub fn item_detail(item: &models::Item) -> String {
    format!(
        "<h1>Item Details</h1>
        <p><b>ID:</b> {}</p>
        <p><b>Name:</b> {}</p>
        <p><b>Quantity:</b> {}</p>
        <p><b>Created At:</b> {}</p>
        <a href='/items'>Back to Items</a>",
        item.id, escape_html(&item.name), item.quantity, item.created_at
    )
}

pub fn item_created(item: &models::Item) -> String {
    format!(
        "<h1>Item Created</h1><p>Item created: {} (ID: {})</p><a href='/items'>Back to Items</a>", 
        escape_html(&item.name), 
        item.id
    )
}
