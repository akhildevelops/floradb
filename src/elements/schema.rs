use crate::elements::Column;
use std::collections::HashMap;
pub struct Schema<'q> {
    columns: HashMap<&'q str, Box<dyn Column>>,
}
