pub mod controllers;
pub mod models;
pub mod repository;
pub mod views;

use axum::routing::{Router, get};
use clap::Parser;
use figment::{
    Figment,
    providers::{Format, Yaml},
};

#[derive(serde::Deserialize, Debug)]
struct DatabaseConfig {
    host: String,
    port: u16,
    user: String,
    password: String,
    database: String,
}

#[derive(serde::Deserialize, Debug)]
struct ServerConfig {
    host: String,
    port: u16,
}

#[derive(serde::Deserialize, Debug)]
struct AppConfig {
    database: DatabaseConfig,
    server: ServerConfig,
}

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[arg(long)]
    print_db_url: bool,
}

fn load_config() -> Result<AppConfig, figment::Error> {
    let config_path =
        std::env::var("MYWEBAPP_CONFIG").unwrap_or_else(|_| "/etc/mywebapp/config.yml".to_string());

    Figment::new().merge(Yaml::file(config_path)).extract()
}

fn build_db_url(db: &DatabaseConfig) -> String {
    format!(
        "postgres://{}:{}@{}:{}/{}",
        urlencoding::encode(&db.user),
        urlencoding::encode(&db.password),
        db.host,
        db.port,
        db.database
    )
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let config = match load_config() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Configuration load failed: {}", e);
            std::process::exit(1);
        }
    };

    let db_url = build_db_url(&config.database);

    if cli.print_db_url {
        print!("{}", db_url);
        return;
    }

    let pool = match sqlx::postgres::PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
    {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Database connection failed: {}", e);
            std::process::exit(1);
        }
    };

    let app = Router::new()
        .route("/", get(controllers::root))
        .route(
            "/items",
            get(controllers::get_items).post(controllers::create_item),
        )
        .route("/items/{id}", get(controllers::get_item))
        .route("/health/alive", get(controllers::health_alive))
        .route("/health/ready", get(controllers::health_ready))
        .with_state(pool);

    let addr = format!("{}:{}", config.server.host, config.server.port);
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .unwrap_or_else(|e| {
            eprintln!("Failed to bind to {}: {}", addr, e);
            std::process::exit(1);
        });

    if let Err(e) = axum::serve(listener, app).await {
        eprintln!("Server error: {}", e);
        std::process::exit(1);
    }
}
