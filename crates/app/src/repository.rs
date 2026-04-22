use super::models;

pub async fn get_all_items(pool: &sqlx::PgPool) -> Result<Vec<models::ItemListEntry>, sqlx::Error> {
    sqlx::query_as::<_, models::ItemListEntry>("SELECT id, name FROM items ORDER BY id ASC")
        .fetch_all(pool)
        .await
}

pub async fn get_item_by_id(pool: &sqlx::PgPool, id: i32) -> Result<Option<models::Item>, sqlx::Error> {
    sqlx::query_as::<_, models::Item>("SELECT id, name, quantity, created_at FROM items WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
}

pub async fn create_item_payload(pool: &sqlx::PgPool, payload: &models::CreateItemPayload) -> Result<models::Item, sqlx::Error> {
    sqlx::query_as::<_, models::Item>(
        "INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING id, name, quantity, created_at"
    )
    .bind(&payload.name)
    .bind(payload.quantity)
    .fetch_one(pool)
    .await
}

pub async fn ping(pool: &sqlx::PgPool) -> Result<(), sqlx::Error> {
    sqlx::query("SELECT 1").execute(pool).await.map(|_| ())
}
