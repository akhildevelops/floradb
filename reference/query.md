
# Create schema
`schema=Schema(documents=Text())`

# Create table based on Schema
`table=db.create(schema)`

# Insert data into table
`table[documents].insert(["record"])`

# Get count vectors of each record
`table[documents.count_vector()].get()`

# Transformations
```shell
schema=Schema(id=Int(primary_key=true),documents=Text())
table=db.create(schema)
```
A:
```
model=EmbeddingModel("all-MiniLM-L6-v2")
table[id,documents,documents.embeddings(model).as(embeddings)]
```
B:
```
model=EmbeddingModel("all-MiniLM-L6-v2")
table[id,model.transform(documents).as(embeddings)]
```

# Inserts:
 ```shell
 db.insert(docs="Hello");
 ```
or
```shell
byte_buffer = TextBuffer();
db.insert(docs=byte_buffer);
byte_buffer.write(b"Hello");
byte_buffer.write(b" ");
byte_buffer.write(b"World");
```