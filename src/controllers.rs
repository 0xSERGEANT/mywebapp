use axum::{
    extract::State,
    http::{HeaderMap, StatusCode, header::ACCEPT},
    response::{Html, IntoResponse, Response},
};

use super::{repository, views};

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
