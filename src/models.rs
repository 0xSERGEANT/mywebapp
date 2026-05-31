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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_item_payload_deserializes() {
        let json = r#"{"name":"bolt","quantity":42}"#;
        let p: CreateItemPayload = serde_json::from_str(json).unwrap();
        assert_eq!(p.name, "bolt");
        assert_eq!(p.quantity, 42);
    }

    #[test]
    fn item_list_entry_serializes() {
        let entry = ItemListEntry {
            id: 1,
            name: "nut".to_string(),
        };
        let json = serde_json::to_string(&entry).unwrap();
        assert!(json.contains("\"id\":1"));
        assert!(json.contains("\"name\":\"nut\""));
    }

    #[test]
    fn item_serializes_with_all_fields() {
        let item = Item {
            id: 2,
            name: "screw".to_string(),
            quantity: 10,
            created_at: chrono::Utc::now(),
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"quantity\":10"));
    }

    #[test]
    fn item_deserializes() {
        let json = r#"{"id":1,"name":"bolt","quantity":42,"created_at":"2023-01-01T12:00:00Z"}"#;
        let i: Item = serde_json::from_str(json).unwrap();
        assert_eq!(i.id, 1);
        assert_eq!(i.name, "bolt");
    }

    #[test]
    fn item_list_entry_deserializes() {
        let json = r#"{"id":1,"name":"bolt"}"#;
        let i: ItemListEntry = serde_json::from_str(json).unwrap();
        assert_eq!(i.name, "bolt");
    }
}
