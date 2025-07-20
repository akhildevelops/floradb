use crate::Device;
use crate::core::Column;
struct Text<T: Device> {
    device: T,
}

impl<T: Device> Column for Text<T> {
    //FIXME: Should be some enum
    fn column_type(&self) -> &'static str {
        "TEXT"
    }
}
