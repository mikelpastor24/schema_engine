import 'package:schema_engine/schema_engine.dart' as schema;

/// Builds reusable declarations and generates schemas for published drafts.
void main() {
  final address = schema.object({
    'street': schema.string().nonempty(),
    'city': schema.string().nonempty(),
  });
  final user = schema
      .object({
        'name': schema.string().min(1).max(100),
        'age': schema.integer().nonnegative().optional(),
        'email': schema.string().email().optional(),
        'address': address.nullable(),
        'roles': schema
            .array(schema.enumValues(['reader', 'editor']))
            .nonempty(),
      })
      .describe('A user record.');

  final document = user.toJsonSchema(draft: schema.SchemaDraft.draft202012);
  print(document.toJsonString(indent: '  '));
  final validator = document.compile(
    options: schema.SchemaOptions(assertFormats: true),
  );
  print(
    validator.isValid({
      'name': 'Example',
      'address': null,
      'roles': ['reader'],
    }),
  );
  print(
    validator.validate({'name': '', 'address': null, 'roles': <Object?>[]}),
  );

  // The declaration is independent of its generated dialect.
  for (final draft in schema.SchemaDraft.values) {
    print('${draft.name}: ${user.toJsonSchema(draft: draft).draft.name}');
  }

  // Shape operations return new declarations and preserve the source shape.
  final profile = schema.object({
    'name': schema.string(),
    'active': schema.boolean(),
  });
  final patch = profile.partial();
  final extended = profile.extend({'tags': schema.string().array().optional()});
  print(patch.compile().isValid({}));
  print(extended.compile().isValid({'name': 'Example', 'active': true}));
}
