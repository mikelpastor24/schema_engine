## 0.0.1

* Re-export ValidationErrorCodes for constant-based form message catalogs.

* Display the engine's specific, localizable validation diagnostics, including
  property-specific required errors, and share application-owned engine catalogs.

* Add SchemaFormMessages for localized labels, actions, parsing errors, schema
  diagnostics, and root error summaries with English defaults.
* Expose SchemaField.label and SchemaField.messages to custom editors; preserve
  edits and pending errors when the message configuration changes.

* Show boolean field labels once in the switch tile, preserving themed input
  decoration, descriptions, and validation errors.

* Enable email and URI format assertions in the example, show schema diagnostics
  for invalid values, and clear previously submitted JSON when editing resumes.

* Always show optional properties with optional labels and omit untouched fields
  from JSON. Clear empty optional text/numeric fields and remove optional arrays
  when their final item is removed.
* Add SchemaField.clear and clear controls for explicit optional values, keeping
  zero, false, null, enum choices, and existing instance values intact.

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
