use arrow::array::Array;

pub trait Transformer {
    fn transform(&mut self, array: &dyn Array) -> Result {}
}
