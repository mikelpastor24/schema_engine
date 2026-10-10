# Schema packages

A Dart/Flutter monorepository for working with JSON Schema documents and their
instances. Original implementation, licensed under MIT.

| Package | Purpose | Runtime requirements |
| --- | --- | --- |
| [schema_engine](packages/schema_engine) | Parse, build, serialize, compile, and validate JSON Schema | Dart; no runtime dependencies |
| [schema_ui](packages/schema_ui) | Generate customizable form fields for editing JSON instances | Flutter and schema_engine |

The engine's public import remains `package:schema_engine/schema_engine.dart`.
Flutter is isolated in `schema_ui`; Dart applications can depend on the engine
without depending on Flutter.

## Development

The repository uses a [Pub workspace](https://dart.dev/tools/pub/workspaces) with
one dependency resolution. Developing the complete workspace requires Flutter
3.47 or later and Dart 3.13 or later. Package versions remain independent.

From the repository root:

```sh
flutter pub get
dart format packages tool
flutter analyze --no-pub
dart run tool/check.dart
```

`tool/check.dart` resolves dependencies, checks formatting, analyzes both
packages, runs engine and widget tests, and runs the engine's all-drafts example.
It also runs the example application's widget tests and exits as soon as a
check fails.

To run individual tests:

```sh
cd packages/schema_engine
dart test
dart run example/all_drafts.dart
```

```sh
cd packages/schema_ui
flutter test --no-pub
```

Run engine generators, benchmarks, and conformance adapters from
`packages/schema_engine`. Their relative paths remain package-local. Existing
conformance evidence and measurements are preserved in its
[conformance report](packages/schema_engine/docs/conformance.md) and
[performance report](packages/schema_engine/docs/performance.md).

## Flutter forms

```dart
import 'package:flutter/material.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

final document = schema.object({
  'name': schema.string().min(1),
  'age': schema.integer().nonnegative().optional(),
}).toJsonSchema();
final formKey = GlobalKey<FormState>();

final editor = Form(
  key: formKey,
  child: SchemaForm(
    schema: document,
    initialValue: {'name': 'Example'},
    onSaved: (instance) => print(instance),
  ),
);

void save() {
  if (formKey.currentState!.validate()) {
    formKey.currentState!.save();
  }
}
```

See the [schema_ui API and rendering matrix](packages/schema_ui/README.md) for
widget overrides, theming, instance presence, and rendering limitations. The
[example app](packages/schema_ui/example) demonstrates default fields and a
custom multiline string editor.

To open it in Chrome after resolving workspace dependencies:

```sh
cd packages/schema_ui/example
flutter run -d chrome
```

The application also includes a Windows runner. See its
[run instructions](packages/schema_ui/example/README.md) for other devices.
