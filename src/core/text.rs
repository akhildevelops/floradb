use crate::Column;

struct Text {}

impl Column for Text {
    //FIXME: Should be some enum
    fn column_type(&self) -> &'static str {
        "TEXT"
    }
}
