# Create schema
`schema=Schema(documents=Text())`

# Create table based on Schema
`table=db.create(schema)`

# Insert data into table
`table[documents].insert(["record"])`

# Get count vectors of each record
`table[documents.count_vector()].get()`
