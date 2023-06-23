//// The schema module defines the schema of a table.
//// It is used to generate SQL queries and to decode
//// the results of a query into a Gleam value.

import gleam/dynamic

/// The schema of a table. The table name, primary key,
/// and fields are used to generate SQL queries.
/// The decoder is used to decode the results of a query
/// into a Gleam value.
/// 
/// ## Examples
/// 
/// ```gleam
/// pub type Note {
///  Note(id: Int, title: String, content: String)
/// }
///
/// pub fn schema() {
///  Schema(
///    table: "notes",
///    primary_key: "id",
///    fields: [
///      Field("id", schema.Integer),
///      Field("title", schema.String),
///      Field("content", schema.String),
///    ],
///    decoder: dynamic.decode3(
///      Note,
///      dynamic.element(0, dynamic.int),
///      dynamic.element(1, dynamic.string),
///      dynamic.element(2, dynamic.string),
///    ),
///  )
/// }
/// ```
/// 
pub type Schema(a) {
  Schema(
    table: String,
    primary_key: String,
    fields: List(Field),
    decoder: dynamic.Decoder(a),
  )
}

/// A field in a table. The name is used to
/// generate SQL queries. Eventually would like to figure
/// out a way to autogenerate the decoder based on these.
/// 
/// Right now only integer and string fields are supported but these
/// could really be anything that can be represented in PGO.
pub type Field {
  Field(name: String, type_: FieldType)
}

/// The type of a field in a table. Not really used for anything yet.
pub type FieldType {
  Integer
  String
}
