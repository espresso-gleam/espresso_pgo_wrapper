//// A query builder for Postgres, it's not fully built out yet and 
//// currently only performs the most basic queries.

import gleam/int
import gleam/list
import gleam/pgo
import gleam/string_builder.{StringBuilder}
import database/schema.{Schema}

/// A where clause is a list of tuples where the first element is the field
/// name and the second is the value to bind to that field. It will
/// automatically generate the correct number of placeholders for the values
/// and append them to the bindings list for PGO.
pub type Where =
  List(#(String, List(pgo.Value)))

/// A query is a struct that contains the schema to query from, the fields to
/// select, the where clause, and the bindings for the query.
/// 
/// Normally you won't interact with this struct directly, instead you'll use
/// the functions below to build up a query and then pass it to the associated
/// functions to get the SQL string. These are already wrapped in the top level
/// `database` module.
pub type Query(a) {
  Query(
    from: Schema(a),
    select: List(String),
    where: List(String),
    bindings: List(pgo.Value),
  )
}

/// Create a new query from a schema. This is the starting point for building
/// a query and the schema's decoder is also used as the returned value.
pub fn from(schema: Schema(a)) -> Query(a) {
  Query(from: schema, where: [], select: [], bindings: [])
}

/// Adds fields to the select clause of the query. This is the same as
/// `SELECT field1, field2, ...` in SQL.
pub fn select(query: Query(a), fields: List(String)) -> Query(a) {
  Query(..query, select: list.append(fields, query.select))
}

/// Adds a where clause to the query. This is the same as `WHERE field = value`
/// in SQL. The values will be appended to the bindings list for PGO.
pub fn where(query: Query(a), bindings: Where) -> Query(a) {
  let where =
    bindings
    |> list.map(fn(where) {
      let #(field, _value) = where
      field
    })
    |> list.append(query.where)
  let bindings =
    bindings
    |> list.flat_map(fn(where) {
      let #(_field, value) = where
      value
    })
    |> list.append(query.bindings)
  Query(..query, where: list.append(query.where, where), bindings: bindings)
}

/// Builds the SQL string for the query. This is the same as `SELECT ... FROM
/// ... WHERE ...` in SQL.
pub fn build(query: Query(a)) -> String {
  let select_fields =
    query.select
    |> list.map(fn(field) { string_builder.from_string(field) })
    |> string_builder.join(", ")

  string_builder.new()
  |> string_builder.append("SELECT ")
  |> string_builder.append_builder(select_fields)
  |> string_builder.append(" FROM ")
  |> string_builder.append(query.from.table)
  |> build_where(query.where)
  |> string_builder.to_string()
}

/// Builds the SQL string for the where clause in a query. This
/// only works for "AND" queries, it doesn't support "OR" or other
/// operators, yet.
fn build_where(query: StringBuilder, where: List(String)) -> StringBuilder {
  case where {
    [] -> query
    where -> {
      let where_fields =
        where
        |> list.map(fn(field) { string_builder.from_string(field) })
        |> string_builder.join(" AND ")

      query
      |> string_builder.append(" WHERE ")
      |> string_builder.append_builder(where_fields)
    }
  }
}

/// Builds the SQL string for an insert query. This is the same as `INSERT INTO
/// ... (field1, field2, ...) VALUES (value1, value2, ...)` in SQL. It will ignore
/// the primary key field in the schema but may supporrt that in the future.
pub fn insert(schema: Schema(a)) -> String {
  let fields =
    list.filter_map(
      schema.fields,
      fn(field) {
        case field.name == schema.primary_key {
          True -> Error(Nil)
          False -> Ok(string_builder.from_string(field.name))
        }
      },
    )

  let replacements =
    list.index_map(
      fields,
      fn(i, _field) { string_builder.from_string("$" <> int.to_string(i + 1)) },
    )

  string_builder.new()
  |> string_builder.append("INSERT INTO ")
  |> string_builder.append(schema.table)
  |> string_builder.append("(")
  |> string_builder.append_builder(string_builder.join(fields, ", "))
  |> string_builder.append(") VALUES (")
  |> string_builder.append_builder(string_builder.join(replacements, ", "))
  |> string_builder.append(") RETURNING *")
  |> string_builder.to_string()
}

/// Builds the SQL string for an update query. This is the same as `UPDATE ...
/// SET field1 = value1, field2 = value2, ...` in SQL. It will return
/// the updated rows.
pub fn update(query: Query(a), fields: List(#(String, pgo.Value))) -> String {
  let offset = list.length(query.bindings)
  let updates =
    list.index_map(
      fields,
      fn(i, field) {
        let #(field, _value) = field
        string_builder.from_string(
          field <> " = $" <> int.to_string(i + offset + 1),
        )
      },
    )

  string_builder.new()
  |> string_builder.append("UPDATE ")
  |> string_builder.append(query.from.table)
  |> string_builder.append(" SET ")
  |> string_builder.append_builder(string_builder.join(updates, ", "))
  |> build_where(query.where)
  |> string_builder.append(" RETURNING *")
  |> string_builder.to_string()
}

/// Builds the SQL string for a delete query. This is the same as `DELETE FROM
/// ... WHERE ...` in SQL. It will return the deleted rows.
pub fn delete(query: Query(a)) -> String {
  string_builder.new()
  |> string_builder.append("DELETE FROM ")
  |> string_builder.append(query.from.table)
  |> build_where(query.where)
  |> string_builder.append(" RETURNING *")
  |> string_builder.to_string()
}
