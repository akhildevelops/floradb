use std::collections::HashMap;

use crate::core::{Column, Schema};
pub struct Table<'q> {
    pub schema: Schema<'q>,
    pub columns: HashMap<&'q str, Box<dyn Column>>,
}
