//// This is the main entry point for interacting with pgo dbs.
//// It does things like selecting all rows, single records, inserting, updating, and deleting.

import gleam/pgo.{Connection}
import gleam/list
import gleam/io
import database/query.{Query}
import database/schema.{Schema}

/// Select all rows from a table.
/// 
/// ## Examples
/// 
/// ```gleam
/// schema
/// |> from()
/// |> select(["id", "name"])
/// |> database.all(db)
/// 
/// schema
/// |> from()
/// |> select(["*"])
/// |> database.all(db)
/// ```
pub fn all(q: Query(a), db: Connection) -> Result(List(a), Nil) {
  let sql = query.build(q)
  case pgo.execute(sql, db, q.bindings, q.from.decoder) {
    Ok(result) -> Ok(result.rows)

    Error(e) -> {
      io.debug(e)
      Error(Nil)
    }
  }
}

/// Select a single record from a table. If there's more 
/// than one row returned this will only return the first.
/// 
/// ## Examples
/// 
/// ```gleam
/// schema()
/// |> from()
/// |> select(["*"])
/// |> where([#("id = $1", [pgo.int(id)])])
/// |> database.one(db)
/// 
/// schema()
/// |> from()
/// |> select(["id"])
/// |> where([#("title ilike '%$1%'", [pgo.text(title)])])
/// |> database.one(db)
/// ```
pub fn one(q: Query(a), db: Connection) -> Result(a, Nil) {
  let sql = query.build(q)
  case pgo.execute(sql, db, q.bindings, q.from.decoder) {
    Ok(result) -> {
      result.rows
      |> list.first()
    }

    Error(e) -> {
      io.debug(e)
      Error(Nil)
    }
  }
}

/// Insert a record into a table.
/// 
/// ## Examples
/// 
/// ```gleam
/// database.insert(
///   schema(),
///   [pgo.text(note.title), pgo.text(note.content)],
///   db,
/// )
/// ```
pub fn insert(
  schema: Schema(a),
  data: List(pgo.Value),
  db: Connection,
) -> Result(a, Nil) {
  let sql = query.insert(schema)

  case pgo.execute(sql, db, data, schema.decoder) {
    Ok(result) -> {
      case list.first(result.rows) {
        Ok(result) -> Ok(result)
        Error(_e) -> Error(Nil)
      }
    }

    Error(e) -> {
      io.debug(e)
      Error(Nil)
    }
  }
}

/// Update one or more records in a table. Right now
/// it will only return the first updated record but
/// could be updated to return more than one.
/// 
/// ## Examples
/// 
/// ```gleam
/// schema()
/// |> from()
/// |> where([#("id = $1", [pgo.int(id)])])
/// |> database.update(
///   [
///     #("title", pgo.text(note.title)),
///     #("content", pgo.text(note.content)),
///   ],
///   db,
/// )
/// ```
pub fn update(
  query: Query(a),
  data: List(#(String, pgo.Value)),
  db: Connection,
) -> Result(a, Nil) {
  let sql = query.update(query, data)

  let bindings =
    list.append(
      query.bindings,
      list.map(
        data,
        fn(field) {
          let #(_field, value) = field
          value
        },
      ),
    )

  case pgo.execute(sql, db, bindings, query.from.decoder) {
    Ok(result) -> {
      case list.first(result.rows) {
        Ok(result) -> Ok(result)
        Error(_e) -> Error(Nil)
      }
    }

    Error(e) -> {
      io.debug(e)
      Error(Nil)
    }
  }
}

/// Delete a record from a table. Right now it will only
/// return the first deleted record but could be updated
/// to return more than one.
/// 
/// ## Examples
/// 
/// ```gleam
/// schema()
/// |> from()
/// |> where([#("id = $1", [pgo.int(id)])])
/// |> database.delete(db)
/// ```
pub fn delete(query: Query(a), db: Connection) -> Result(a, Nil) {
  let sql = query.delete(query)

  case pgo.execute(sql, db, query.bindings, query.from.decoder) {
    Ok(result) -> {
      case list.first(result.rows) {
        Ok(result) -> Ok(result)
        Error(_e) -> Error(Nil)
      }
    }

    Error(e) -> {
      io.debug(e)
      Error(Nil)
    }
  }
}
