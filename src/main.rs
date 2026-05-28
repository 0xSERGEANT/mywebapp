pub mod controllers;
pub mod models;
pub mod repository;
pub mod views;

use figment::{Figment, providers::{Format, Yaml}};

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

fn load_config() -> Result<AppConfig, figment::Error> {
    let config_path = std::env::var("MYWEBAPP_CONFIG")
        .unwrap_or_else(|_| "/etc/mywebapp/config.yml".to_string());

    Figment::new()
        .merge(Yaml::file(config_path))
        .extract()
}

fn main() {
    println!("!");
}
