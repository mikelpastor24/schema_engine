import 'package:schema_engine/schema_engine.dart';

/// Builds and parses a small schema in every published dialect.
void main() {
  for (final draft in SchemaDraft.values) {
    final schema = JsonSchema.build(
      draft: draft,
      type: SchemaType.object,
      properties: {
        'name': JsonSchema.build(
          draft: draft,
          type: SchemaType.string,
          minLength: 1,
        ),
        'age': JsonSchema.build(
          draft: draft,
          type: SchemaType.integer,
          minimum: 0,
        ),
      },
      required: ['name'],
    );
    final parsed = JsonSchema.parse(schema.toJsonString());
    final validator = parsed.compile();
    final valid = validator.isValid({'name': 'Example', 'age': 36});
    final invalid = validator.validate({'name': '', 'age': -1});
    print('${draft.name}: valid=$valid, invalid=$invalid');
  }
}
