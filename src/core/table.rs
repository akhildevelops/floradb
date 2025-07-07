use std::collections::HashMap;

use crate::{Column, Schema};
pub struct Table<'q> {
    pub schema: Schema<'q>,
    pub columns: HashMap<&'q str, Box<dyn Column>>,
}
