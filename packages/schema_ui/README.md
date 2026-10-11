# schema_ui

Create JSON Schemas visually and edit their JSON instances with Flutter forms.
The widgets use [schema_engine](https://pub.dev/packages/schema_engine) for
schema construction and validation, and follow your application's Material
theme.

## Features

- Author schemas with `SchemaEditor`, including properties, arrays, constraints,
  and reusable definitions.
- Generate instance forms with `SchemaForm` for text, numbers, booleans, choices,
  objects, and arrays.
- Validate, save, and reset through Flutter's `Form`.
- Customize field widgets, spacing, labels, and validation messages.
- Preserve schema keywords without visual controls and distinguish missing
  optional values from explicit values.

## Installation

Requires Flutter 3.47 and Dart 3.13 or later. Add both packages when your
application also imports the engine to create schemas:

```sh
flutter pub add schema_engine schema_ui
```

## Example

```dart
import 'package:flutter/material.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

void main() {
  final document = schema.object({
    'name': schema.string().min(1),
    'age': schema.integer().nonnegative().optional(),
  }).toJsonSchema();

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Form(
          child: SchemaForm(
            schema: document,
            initialValue: {'name': 'Example'},
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (value) => print(schema.encodeJson(value)),
          ),
        ),
      ),
    ),
  );
}
```

## Requirements and limitations

Visual schema authoring currently targets Draft 2020-12. Instance validation
uses the engine's draft support, but automatic form layouts cover a smaller set
of schema shapes. References, combinators, and other unsupported layouts use a
JSON editor or your custom field widget.

Formats such as email and URI need format assertions enabled to reject invalid
values. Keyboard hints alone do not enable those checks. External references
require resources prepared by your application.

Only English messages are bundled; applications can supply their own
translations. Validation does not insert default values or modify the supplied
instance.

See the [usage guide](doc/usage.md) for authoring controls, supported layouts,
custom widgets, themes, and localization. The
[example application](example/README.md) demonstrates instance editing and a
schema builder with synchronized visual and JSON views.

Original implementation, licensed under [MIT](LICENSE).
