## Unreleased

* Add configurable schema_ui form messages for localization, including optional
  labels, actions, validation diagnostics, and custom editor integration.

* Remove duplicate labels from schema_ui boolean fields while retaining helper
  text and validation errors.

* Enable format assertions in the schema_ui example so invalid email and URI
  values show schema errors and cannot be saved.

* Replace optional-property inclusion checkboxes with visible optional fields,
  automatic omission for empty edits, and explicit clear controls.

* Replace fixed numeric input errors with schema_engine validation diagnostics.

* Separate schema_ui text and numeric editors with automatic keyboard selection
  and input formatters, preserving exact numbers and schema validation.

* Make the schema_ui example a runnable Flutter workspace application with
  browser and Windows support.

* Migrate the Dart engine into `packages/schema_engine` without changing its
  public import, runtime dependencies, or validation implementation.
* Add `packages/schema_ui`, a Flutter form generation package with ancestor
  Form integration, complete engine validation, and type/path widget overrides.
* Add a shared Pub workspace and repository verification command.
