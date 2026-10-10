import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

void main() {
  for (final draft in SchemaDraft.values) {
    group(draft.name, () {
      test('builds, serializes, parses, and validates an object', () {
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
          additionalProperties: JsonSchema.fromJson(
            draft.supportsBooleanSchemas ? false : {'disallow': 'any'},
            draft: draft,
          ),
        );
        // The historical drafts also allow booleans for additionalProperties.
        final json = schema.toJson() as Map<String, Object?>;
        final adjusted = {...json, 'additionalProperties': false};
        final parsed = JsonSchema.parse(
          JsonSchema.fromJson(
            adjusted,
            draft: draft,
          ).toJsonString(indent: '  '),
        );
        expect(parsed.draft, draft);
        expect(parsed.toJson(), adjusted);
        final validator = parsed.compile();
        for (final value in [
          <String, Object?>{'name': 'Example'},
          <String, Object?>{'name': 'Example', 'age': 36},
        ]) {
          expect(validator.isValid(value), isTrue);
          expect(validator.validate(value), isNull);
          expect(validator.errors(value), isEmpty);
        }
        for (final value in [
          <String, Object?>{},
          <String, Object?>{'name': ''},
          <String, Object?>{'name': 'Example', 'age': -1},
          <String, Object?>{'name': 'Example', 'extra': true},
          7,
        ]) {
          expect(validator.isValid(value), isFalse, reason: '$value');
          expect(validator.validate(value), isNotNull);
          expect(validator.errors(value), isNotEmpty);
        }
      });
      test('implements numeric bounds and Unicode length', () {
        final number = JsonSchema.build(
          draft: draft,
          type: SchemaType.number,
          exclusiveMinimum: 1,
          maximum: 3,
        ).compile();
        expect(number.isValid(1), isFalse);
        expect(number.isValid(1.5), isTrue);
        expect(number.isValid(3), isTrue);
        expect(number.isValid(3.1), isFalse);
        final string = JsonSchema.build(
          draft: draft,
          type: SchemaType.string,
          minLength: 1,
          maxLength: 1,
        ).compile();
        expect(string.isValid('😀'), isTrue);
        expect(string.isValid('ab'), isFalse);
      });
      test('implements tuple spelling for its dialect', () {
        final schema = JsonSchema.build(
          draft: draft,
          type: SchemaType.array,
          prefixItems: [
            JsonSchema.build(draft: draft, type: SchemaType.string),
          ],
          items: JsonSchema.build(draft: draft, type: SchemaType.integer),
        );
        final validator = schema.compile();
        expect(validator.isValid(['a', 2, 3]), isTrue);
        expect(validator.isValid(['a', 'b']), isFalse);
        expect(validator.isValid([1]), isFalse);
      });
    });
  }
  test('preserves extension keywords and freezes the original document', () {
    final original = <String, Object?>{
      'type': 'string',
      'x-note': {
        'nested': [1],
      },
    };
    final schema = JsonSchema.fromJson(original);
    final validator = schema.compile();
    original['type'] = 'integer';
    expect(validator.isValid('value'), isTrue);
    expect(schema.toJson(), {
      'type': 'string',
      'x-note': {
        'nested': [1],
      },
    });
    expect(
      () => (schema.toJson() as Map<String, Object?>)['type'] = 'number',
      throwsUnsupportedError,
    );
  });
  test('rejects invalid schemas and unsupported builder options', () {
    expect(() => JsonSchema.fromJson(1), throwsA(isA<SchemaException>()));
    expect(() => JsonSchema.parse('{'), throwsFormatException);
    expect(
      () => JsonSchema.fromJson({r'$schema': 'https://example.com/unknown'}),
      throwsFormatException,
    );
    expect(
      () => JsonSchema.fromJson({'minLength': -1}).compile(),
      throwsA(isA<SchemaException>()),
    );
    expect(
      () => JsonSchema.fromJson({'type': 'unknown'}).compile(),
      throwsA(isA<SchemaException>()),
    );
    expect(
      () => JsonSchema.build(draft: SchemaDraft.draft4, constValue: null),
      throwsA(isA<SchemaException>()),
    );
  });
  test('uses exact decimal multiples without a floating point epsilon', () {
    final validator = JsonSchema.fromJson({'multipleOf': 0.1}).compile();
    expect(validator.isValid(0.3), isTrue);
    expect(validator.isValid(0.30000000000000004), isFalse);
    expect(validator.isValid(0.31), isFalse);
  });
  test('compares arrays, objects, and numeric representations deeply', () {
    final validator = JsonSchema.fromJson({'uniqueItems': true}).compile();
    expect(
      validator.isValid([
        {
          'a': 1,
          'b': [2],
        },
        {
          'b': [2.0],
          'a': 1.0,
        },
      ]),
      isFalse,
    );
    expect(
      validator.isValid([
        {'a': 1},
        {'a': 2},
      ]),
      isTrue,
    );
  });
  test('escapes JSON Pointer diagnostics and reports multiple failures', () {
    final validator = JsonSchema.fromJson({
      'properties': {
        'a/b~': {'type': 'integer', 'minimum': 4},
        'b': {'type': 'boolean'},
      },
    }).compile();
    final errors = validator.errors({'a/b~': 2, 'b': 4});
    expect(errors, hasLength(2));
    expect(errors.first.instancePath, '/a~1b~0');
    expect(errors.first.schemaPath, '/properties/a~1b~0/minimum');
  });
  test('compiles recursive references once and can be reused', () {
    final validator = JsonSchema.fromJson({
      'type': 'object',
      'properties': {
        'value': {'type': 'integer'},
        'next': {r'$ref': '#'},
      },
    }).compile();
    expect(
      validator.isValid({
        'value': 1,
        'next': {'value': 2},
      }),
      isTrue,
    );
    expect(
      validator.isValid({
        'next': {'value': 'wrong'},
      }),
      isFalse,
    );
    expect(validator.isValid({'value': 1}), isTrue);
  });
  test('resolves registered resources and anchors offline', () {
    final schema = JsonSchema.fromJson({r'$ref': 'child#item'});
    final validator = schema.compile(
      baseUri: Uri.parse('https://example.com/root'),
      options: SchemaOptions(
        resources: {
          Uri.parse('https://example.com/child'): {
            r'$anchor': 'item',
            'type': 'string',
          },
        },
      ),
    );
    expect(validator.isValid('hello'), isTrue);
    expect(validator.isValid(1), isFalse);
    expect(() => schema.compile(), throwsA(isA<ReferenceException>()));
  });
  test('loads references only during asynchronous preparation', () async {
    var calls = 0;
    final validator = await JsonSchema.fromJson({r'$ref': 'child'})
        .compileAsync(
          options: SchemaOptions(
            resolver: (uri) async {
              calls++;
              return {'type': 'integer'};
            },
          ),
        );
    expect(calls, 1);
    expect(validator.isValid(1), isTrue);
    expect(validator.isValid('1'), isFalse);
    expect(calls, 1);
  });
  test('combines annotations from every successful anyOf branch', () {
    final validator = JsonSchema.fromJson({
      'anyOf': [
        {
          'properties': {'a': true},
        },
        {
          'properties': {'b': true},
        },
      ],
      'unevaluatedProperties': false,
    }).compile();
    expect(validator.isValid({'a': 1, 'b': 2}), isTrue);
    expect(validator.isValid({'a': 1, 'c': 2}), isFalse);
  });
  test('applies optional formats and application keywords', () {
    final schema = JsonSchema.fromJson({'format': 'email', 'x-even': true});
    expect(schema.compile().isValid('not an email'), isTrue);
    final validator = schema.compile(
      options: SchemaOptions(
        assertFormats: true,
        keywords: {
          'x-even': (instance, _) => instance is! int || instance.isEven,
        },
      ),
    );
    expect(validator.isValid('user@example.com'), isTrue);
    expect(validator.isValid('not an email'), isFalse);
    expect(validator.isValid(3), isFalse);
  });
}
