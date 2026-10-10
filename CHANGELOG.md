## Unreleased

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
