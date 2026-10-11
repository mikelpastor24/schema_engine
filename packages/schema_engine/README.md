# schema_engine

Parse, build, serialize, and validate JSON Schemas and their instances in Dart.
Create a schema in code or load an existing document, then reuse its validator
for your JSON data. The package has no runtime dependencies or Flutter
requirement.

## Features

- Load schemas from JSON text or decoded values, and serialize them back to JSON.
- Build schemas with typed constructors for objects, arrays, and scalar values.
- Select 2020-12, 2019-09, or Draft 00, 01, 02, 03, 04, 06, or 07 semantics.
- Validate with a boolean result, the first error, or all errors.
- Resolve references and report errors with schema and instance locations.
- Customize validation messages and generate Dart validators for known schemas.

## Installation

Requires Dart 3.13 or later.

```sh
dart pub add schema_engine
```

## Example

```dart
import 'package:schema_engine/schema_engine.dart' as schema;

void main() {
  final document = schema.object({
    'name': schema.string().min(1),
    'age': schema.integer().nonnegative().optional(),
  }).toJsonSchema();
  final validator = document.compile();

  print(validator.isValid({'name': 'Example', 'age': 30})); // true
  print(validator.isValid({})); // false: name is required.
  print(validator.validate({'name': ''})?.message);
}
```

## Requirements and limitations

Schemas without a declared dialect default to 2020-12. Draft-specific features
and supported coverage are described in the
[draft and feature matrix](doc/conformance.md).

The object constructor makes properties required and rejects additional
properties by default. Use modifiers to allow optional fields or extra keys.
Validation does not transform data or insert default values.

Formats such as email and URI are annotations by default in standard dialects.
Enable format assertions when you want those values to be checked. External
references require resources or a resolver supplied by your application.

For exact large integers and decimals, use the package's JSON decoder and
encoder. Precision lost before validation cannot be recovered.

See the [usage guide](doc/usage.md) for parsing, construction, references,
formats, and exact numbers, and the [diagnostic guide](doc/diagnostics.md) for
custom messages. The [complete example](example/schema_engine_example.dart)
shows each validation mode.

Original implementation, licensed under [MIT](LICENSE).
