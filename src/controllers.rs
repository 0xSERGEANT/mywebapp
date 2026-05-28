use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};

use super::repository;

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
