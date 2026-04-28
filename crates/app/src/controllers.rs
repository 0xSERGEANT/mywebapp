use axum::{
    extract::{Path, State},
    http::{header::ACCEPT, HeaderMap, StatusCode},
    response::{Html, IntoResponse, Json, Response},
};

use super::{
    views, 
    models, 
    repository
};

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
    headers.get(ACCEPT)
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
