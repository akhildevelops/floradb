use datafusion::prelude::*;
use tokio::runtime;

async fn task() {
    let ctx = SessionContext::new();
    ctx.register_csv("example", "ideapad/test.csv", CsvReadOptions::new())
        .await
        .unwrap();
    let df = ctx
        .sql("SELECT MIN(b) FROM example WHERE a<=b;")
        .await
        .unwrap();
    df.show().await.unwrap();
}

pub fn main() {
    let rt = runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    rt.block_on(task());
}
