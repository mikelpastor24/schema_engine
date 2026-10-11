import 'package:schema_engine/schema_engine.dart' as schema;

/// Builds a schema and validates JSON with each diagnostic mode.
void main() {
  final document = schema.object({
    'name': schema.string().min(1),
    'age': schema.integer().nonnegative().optional(),
  }).toJsonSchema();
  print(document.toJsonString(indent: '  '));

  final validator = document.compile();
  final instance = schema.decodeJson('{"name":"Example","age":30}');
  print('Valid instance: ${validator.isValid(instance)}');

  final invalid = schema.decodeJson('{"name":"","age":-1}');
  final firstError = validator.validate(invalid);
  print('First error: ${firstError?.message}');
  for (final error in validator.errors(invalid)) {
    print('${error.instancePath}: ${error.message}');
  }
}
