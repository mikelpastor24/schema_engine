# schema_ui example

A Flutter application demonstrating JSON Schema authoring and instance forms
with `schema_engine` and `schema_ui`.

## Features

- Edit a contact record with optional fields, arrays, and a custom text editor.
- Validate values, display JSON submissions, and reset the form.
- Create or import a Draft 2020-12 schema with synchronized visual and JSON
  editors.
- Follow Material light and dark themes, with customizable messages.

## Requirements

Requires Flutter 3.47 and Dart 3.13 or later. Browser and Windows runners are
included. The visual schema builder currently accepts Draft 2020-12.

See the [example guide](../doc/example.md) for running the application, using the
screens, and working from a downloaded package. The entry point is
[lib/main.dart](lib/main.dart).

Original implementation, licensed under [MIT](LICENSE).
