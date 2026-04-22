use sqlx::postgres::PgPoolOptions;
use serde::Deserialize;
use std::fs;

#[derive(Deserialize)]
struct DatabaseConfig {
    host: String,
    user: String,
    password: String,
    database: String,
}

#[derive(Deserialize)]
struct MigratorConfig {
    database: DatabaseConfig,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config_content = fs::read_to_string("/etc/mywebapp/config.yml")
        .or_else(|_| fs::read_to_string("config.yml"))?;

    let config: MigratorConfig = serde_yaml::from_str(&config_content)?;

    let database_url = format!(
        "postgres://{}:{}@{}/{}",
        config.database.user,
        config.database.password,
        config.database.host,
        config.database.database
    );

	let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&database_url)
        .await?;

    sqlx::query("
        CREATE TABLE IF NOT EXISTS items (
            id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            quantity INTEGER NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    ").execute(&pool).await?;

    sqlx::query("CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);")
        .execute(&pool)
        .await?;

    println!("Migrations completed successfully.");
    Ok(())
}
