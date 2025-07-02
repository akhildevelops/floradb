pub trait Column {
    fn column_name(&self) -> &'static str;
}
