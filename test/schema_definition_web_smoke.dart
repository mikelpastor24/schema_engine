import 'package:schema_engine/schema_engine.dart' as schema;

/// Exercises declarative generation and validation after JavaScript compilation.
void main() {
  var checks = 0;
  void check(bool condition) {
    if (!condition) {
      throw StateError('Declarative web check $checks failed.');
    }
    checks++;
  }

  final user = schema.object({
    'name': schema.string().length(1),
    'age': schema.integer().min(0).optional(),
    'note': schema.string().nullable(),
  });
  for (final draft in schema.SchemaDraft.values) {
    final validator = schema.JsonSchema.parse(user.toJsonString(draft: draft))
        .compile();
    check(validator.isValid({'name': '😀', 'note': null}));
    check(!validator.isValid({'name': '😀', 'note': null, 'age': null}));
    check(!validator.isValid({'name': '😀'}));
    check(!validator.isValid({'name': '😀', 'note': null, 'extra': 1}));
    check(!validator.isValid({'name': '😀😀', 'note': null}));
    check(
      schema.record(schema.boolean()).compile(draft: draft).isValid({
        'x': true,
      }),
    );
    check(
      schema
          .tuple([schema.string(), schema.number()])
          .compile(draft: draft)
          .isValid(['x', 1]),
    );
    check(schema.object({}).partial().compile(draft: draft).isValid({}));
    check(schema.string().nullable().compile(draft: draft).isValid(null));
    final integer = schema.integer().compile(draft: draft);
    check(integer.isValid(schema.decodeJson('999999999999999999999')));
    check(
      integer.isValid(schema.decodeJson('1.0')) == draft.supportsBooleanSchemas,
    );
  }
  check(user.partial().compile().isValid({}));
  check(
    user.passthrough().compile().isValid({
      'name': 'x',
      'note': null,
      'extra': 1,
    }),
  );
  check(
    !schema
        .string()
        .email()
        .compile(options: schema.SchemaOptions(assertFormats: true))
        .isValid('invalid'),
  );
  print('$checks declarative JavaScript checks passed.');
}
