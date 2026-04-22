pub mod views;
pub mod models;
pub mod repository;
pub mod controllers;

use axum::{routing::{get, Router}};

#[derive(serde::Deserialize)]
struct DatabaseConfig {
    host: String,
    user: String,
    password: String,
    database: String,
}

#[derive(serde::Deserialize)]
struct ServerConfig {
    host: String,
    port: u16,
}

#[derive(serde::Deserialize)]
struct AppConfig {
    database: DatabaseConfig,
    server: ServerConfig,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config_content = std::fs::read_to_string("/etc/mywebapp/config.yml")
        .or_else(|_| std::fs::read_to_string("config.yml"))?;

    let config: AppConfig = serde_yaml::from_str(&config_content)?;
    
    let database_url = format!(
        "postgres://{}:{}@{}/{}",
        config.database.user,
        config.database.password,
        config.database.host,
        config.database.database
    );

    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    let app = Router::new()
        .route("/", get(controllers::root))
        .route("/items", get(controllers::get_items).post(controllers::create_item))
        .route("/items/:id", get(controllers::get_item))
        .route("/health/alive", get(controllers::health_alive))
        .route("/health/ready", get(controllers::health_ready))
        .with_state(pool);

    let addr = format!("{}:{}", config.server.host, config.server.port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    
    println!("Server running on http://{}", addr);
    axum::serve(listener, app).await?;

    Ok(())
}
