#[derive(serde::Serialize, serde::Deserialize, Clone, sqlx::FromRow)]
pub struct Item {
    pub id: i32,
    pub name: String,
    pub quantity: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(serde::Serialize, serde::Deserialize, Clone, sqlx::FromRow)]
pub struct ItemListEntry {
    pub id: i32,
    pub name: String,
}

#[derive(serde::Deserialize)]
pub struct CreateItemPayload {
    pub name: String,
    pub quantity: i32,
}
