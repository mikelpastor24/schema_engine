## 0.0.1

* Show compiled schema diagnostics for unparseable numeric input while keeping
  the last decoded instance value; use decoder diagnostics when no assertion
  applies.

* Separate text, numeric, and JSON editors; select format-aware text keyboards
  and signed integer/decimal keyboards automatically.
* Add numeric formatters that preserve partial edits and IME composition,
  reject malformed pastes, and support decimal commas and scientific notation.

* Make the example a runnable workspace application with Web and Windows
  runners, local package dependencies, and a dedicated widget test.

* Generate Material form fields for strings, exact numbers, booleans, enums,
  nullable values, object properties, arrays, and tuples.
* Validate complete instances with a reusable schema_engine validator and
  integrate with an ancestor Form's validate, save, and reset operations.
* Support custom editors by JSON type and escaped instance JSON Pointer.
* Inherit Material themes and expose SchemaUiTheme for configurable spacing.
* Preserve optional property presence and immutable JSON snapshots.
* Provide validated JSON editing for references, combinators, boolean schemas,
  and otherwise unsupported automatic layouts.
