use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode, header::ACCEPT},
    response::{Html, IntoResponse, Json, Response},
};

use super::{models, repository, views};

pub enum AppError {
    Database(sqlx::Error),
    NotFound,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::Database(err) => {
                eprintln!("Database error: {:?}", err);
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal Server Error")
            }
            AppError::NotFound => (StatusCode::NOT_FOUND, "Item not found"),
        };
        (status, error_message).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        AppError::Database(err)
    }
}

fn prefers_html(headers: &HeaderMap) -> bool {
    headers
        .get(ACCEPT)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.contains("text/html"))
        .unwrap_or(false)
}

pub async fn root(headers: HeaderMap) -> impl IntoResponse {
    if !prefers_html(&headers) {
        return StatusCode::NOT_ACCEPTABLE.into_response();
    }
    Html(views::root_page()).into_response()
}

pub async fn health_alive() -> impl IntoResponse {
    (StatusCode::OK, "OK")
}

pub async fn health_ready(State(pool): State<sqlx::PgPool>) -> Response {
    match repository::ping(&pool).await {
        Ok(_) => (StatusCode::OK, "OK").into_response(),
        Err(err) => {
            eprintln!("Health check failed: {:?}", err);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Database connection unavailable: {}", err),
            )
                .into_response()
        }
    }
}

pub async fn get_items(
    State(pool): State<sqlx::PgPool>,
    headers: HeaderMap,
) -> Result<Response, AppError> {
    let items = repository::get_all_items(&pool).await?;

    if prefers_html(&headers) {
        Ok(Html(views::items_list(&items)).into_response())
    } else {
        Ok(Json(items).into_response())
    }
}

pub async fn get_item(
    State(pool): State<sqlx::PgPool>,
    Path(id): Path<i32>,
    headers: HeaderMap,
) -> Result<Response, AppError> {
    let item = repository::get_item_by_id(&pool, id)
        .await?
        .ok_or(AppError::NotFound)?;

    if prefers_html(&headers) {
        Ok(Html(views::item_detail(&item)).into_response())
    } else {
        Ok(Json(item).into_response())
    }
}

pub async fn create_item(
    State(pool): State<sqlx::PgPool>,
    headers: HeaderMap,
    Json(payload): Json<models::CreateItemPayload>,
) -> Result<Response, AppError> {
    let item = repository::create_item_payload(&pool, &payload).await?;

    if prefers_html(&headers) {
        Ok(Html(views::item_created(&item)).into_response())
    } else {
        Ok((StatusCode::CREATED, Json(item)).into_response())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::response::IntoResponse;

    #[test]
    fn app_error_not_found_returns_404() {
        let response = AppError::NotFound.into_response();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[test]
    fn app_error_database_returns_500() {
        let response = AppError::Database(sqlx::Error::RowNotFound).into_response();
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    #[test]
    fn prefers_html_with_text_html() {
        let mut h = HeaderMap::new();
        h.insert(ACCEPT, "text/html".parse().unwrap());
        assert!(prefers_html(&h));
    }

    #[test]
    fn no_html_with_json_accept() {
        let mut h = HeaderMap::new();
        h.insert(ACCEPT, "application/json".parse().unwrap());
        assert!(!prefers_html(&h));
    }

    #[test]
    fn no_html_with_empty_headers() {
        assert!(!prefers_html(&HeaderMap::new()));
    }

    #[test]
    fn no_html_with_wildcard() {
        let mut h = HeaderMap::new();
        h.insert(ACCEPT, "*/*".parse().unwrap());
        assert!(!prefers_html(&h));
    }

    #[tokio::test]
    async fn health_alive_returns_200() {
        let response = health_alive().await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn root_not_acceptable_without_html() {
        let response = root(HeaderMap::new()).await.into_response();
        assert_eq!(response.status(), StatusCode::NOT_ACCEPTABLE);
    }

    #[tokio::test]
    async fn root_ok_with_html_accept() {
        let mut h = HeaderMap::new();
        h.insert(ACCEPT, "text/html".parse().unwrap());
        let response = root(h).await.into_response();
        assert_eq!(response.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn health_ready_database_error() {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .connect_lazy("postgres://postgres:password@localhost:5432/nonexistent")
            .unwrap();
        let response = health_ready(State(pool)).await;
        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    #[tokio::test]
    async fn get_items_database_error() {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .connect_lazy("postgres://postgres:password@localhost:5432/nonexistent")
            .unwrap();
        let result = get_items(State(pool), HeaderMap::new()).await;
        assert!(matches!(result, Err(AppError::Database(_))));
    }

    #[tokio::test]
    async fn get_item_database_error() {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .connect_lazy("postgres://postgres:password@localhost:5432/nonexistent")
            .unwrap();
        let result = get_item(State(pool), Path(1), HeaderMap::new()).await;
        assert!(matches!(result, Err(AppError::Database(_))));
    }

    #[tokio::test]
    async fn create_item_database_error() {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .connect_lazy("postgres://postgres:password@localhost:5432/nonexistent")
            .unwrap();
        let payload = Json(models::CreateItemPayload {
            name: "test".to_string(),
            quantity: 1,
        });
        let result = create_item(State(pool), HeaderMap::new(), payload).await;
        assert!(matches!(result, Err(AppError::Database(_))));
    }
}
