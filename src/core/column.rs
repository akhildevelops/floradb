pub trait Column {
    fn column_type(&self) -> &'static str;
}
