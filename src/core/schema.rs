use crate::core::Column;
use std::collections::HashMap;
pub struct Schema<'q> {
    columns: HashMap<&'q str, Box<dyn SchemaParams>>,
}

pub trait SchemaParams {}
