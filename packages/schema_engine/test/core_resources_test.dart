import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

void main() {
  for (final draft in SchemaDraft.values) {
    test('${draft.name} rejects malformed core URI values', () {
      final idKeyword = draft.index < SchemaDraft.draft6.index ? 'id' : r'$id';
      for (final identifier in ['bad schema.json', 'https://example.com/%GG']) {
        for (final keyword in [idKeyword, r'$ref']) {
          expect(
            () => JsonSchema.fromJson({
              keyword: identifier,
            }, draft: draft).compile(),
            throwsA(
              isA<SchemaException>().having(
                (error) => error.schemaPath,
                'schemaPath',
                '/$keyword',
              ),
            ),
          );
        }
      }
      expect(
        () => JsonSchema.fromJson({
          r'$schema': 'relative.json',
        }, draft: draft).compile(),
        throwsA(isA<SchemaException>()),
      );
      expect(
        JsonSchema.fromJson({
          idKeyword: 'relative.json#',
          'type': 'string',
        }, draft: draft).compile().isValid('value'),
        isTrue,
      );
    });
  }
  for (final draft in [SchemaDraft.draft201909, SchemaDraft.draft202012]) {
    test('${draft.name} forbids identifier fragments', () {
      expect(
        () => JsonSchema.fromJson({
          r'$id': 'schema.json#node',
        }, draft: draft).compile(),
        throwsA(isA<SchemaException>()),
      );
      expect(
        JsonSchema.fromJson(
          {r'$id': 'schema.json#node'},
          draft: draft,
        ).compile(options: SchemaOptions(validateSchema: false)).isValid(null),
        isTrue,
      );
    });
    test('${draft.name} dialect declarations require a resource boundary', () {
      final schema = {
        'properties': {
          'name': {r'$schema': draft.metaSchemaUri, 'type': 'string'},
        },
      };
      expect(
        () => JsonSchema.fromJson(schema, draft: draft).compile(),
        throwsA(
          isA<SchemaException>().having(
            (error) => error.schemaPath,
            'schemaPath',
            r'/properties/name/$schema',
          ),
        ),
      );
      final valid = JsonSchema.fromJson({
        'properties': {
          'name': {
            r'$id': 'name.json',
            r'$schema': draft.metaSchemaUri,
            'type': 'string',
          },
        },
      }, draft: draft).compile();
      expect(valid.isValid({'name': 'value'}), isTrue);
      expect(valid.isValid({'name': false}), isFalse);
    });
    test(
      '${draft.name} vocabulary requirements only apply to meta-schemas',
      () {
        final document = {
          r'$schema': draft.metaSchemaUri,
          r'$vocabulary': {'https://example.com/unknown-vocabulary': true},
          'type': 'string',
        };
        final validator = JsonSchema.fromJson(document).compile();
        expect(validator.isValid('value'), isTrue);
        expect(validator.isValid(1), isFalse);
        final meta = Uri.parse('https://example.com/meta');
        expect(
          () => JsonSchema.fromJson(
            {r'$schema': meta.toString()},
            draft: draft,
          ).compile(options: SchemaOptions(resources: {meta: document})),
          throwsA(isA<SchemaException>()),
        );
        expect(
          () => JsonSchema.fromJson({
            'properties': {
              'name': {r'$vocabulary': <String, Object?>{}},
            },
          }, draft: draft).compile(),
          throwsA(isA<SchemaException>()),
        );
      },
    );
  }
  test('older identifier fragments remain supported', () {
    final validator = JsonSchema.fromJson({
      r'$id': 'https://example.com/schema#node',
      'type': 'string',
    }, draft: SchemaDraft.draft7).compile();
    expect(validator.isValid('value'), isTrue);
  });
  test('custom meta-schemas must have valid keyword syntax', () {
    final uri = Uri.parse('https://example.com/invalid-meta');
    final document = JsonSchema.fromJson({
      r'$schema': uri.toString(),
    }, draft: SchemaDraft.draft202012);
    for (final metadata in [
      {r'$schema': SchemaDraft.draft202012.metaSchemaUri, 'required': false},
      {r'$schema': SchemaDraft.draft202012.metaSchemaUri, 'minLength': -1},
      {
        r'$schema': SchemaDraft.draft202012.metaSchemaUri,
        r'$vocabulary': {'https://example.com/optional': 'invalid'},
      },
    ]) {
      expect(
        () => document.compile(
          options: SchemaOptions(resources: {uri: metadata}),
        ),
        throwsA(isA<SchemaException>()),
      );
    }
  });
  test('vocabulary URIs may contain fragments', () {
    final meta = Uri.parse('https://example.com/meta');
    final vocabulary = Uri.parse('https://example.com/vocabulary#assertions');
    final validator =
        JsonSchema.fromJson({
          r'$schema': meta.toString(),
          'even': true,
        }, draft: SchemaDraft.draft202012).compile(
          options: SchemaOptions(
            resources: {
              meta: {
                r'$schema': SchemaDraft.draft202012.metaSchemaUri,
                r'$vocabulary': {
                  'https://json-schema.org/draft/2020-12/vocab/core': true,
                  vocabulary.toString(): true,
                },
              },
            },
            vocabularies: {vocabulary},
            keywords: {
              'even': (instance, value) =>
                  value != true || instance is! num || instance % 2 == 0,
            },
          ),
        );
    expect(validator.isValid(4), isTrue);
    expect(validator.isValid(3), isFalse);
    expect(validator.validate(3), isNotNull);
  });
  test('vocabulary selection uses normalized URI spellings', () {
    final meta = Uri.parse('https://example.com/meta');
    final validator =
        JsonSchema.fromJson({
          r'$schema': meta.toString(),
          'type': 'integer',
          'minimum': 5,
        }, draft: SchemaDraft.draft202012).compile(
          options: SchemaOptions(
            resources: {
              meta: {
                r'$schema': SchemaDraft.draft202012.metaSchemaUri,
                r'$vocabulary': {
                  'HTTPS://JSON-SCHEMA.ORG/draft/2020-12/vocab/core': true,
                  'HTTPS://JSON-SCHEMA.ORG/draft/2020-12/vocab/validation':
                      true,
                },
              },
            },
          ),
        );
    expect(validator.isValid(6), isTrue);
    expect(validator.isValid(4), isFalse);
    expect(validator.isValid('wrong'), isFalse);
  });
  test('an old reference ignores its sibling identifier URI', () {
    final uri = Uri.parse('https://example.com/integer');
    final validator =
        JsonSchema.fromJson({
          r'$ref': uri.toString(),
          r'$id': 'ignored invalid URI',
        }, draft: SchemaDraft.draft7).compile(
          options: SchemaOptions(
            resources: {
              uri: {'type': 'integer'},
            },
          ),
        );
    expect(validator.isValid(1), isTrue);
    expect(validator.isValid('wrong'), isFalse);
  });
  test('a builder needs an identifier to embed another modern dialect', () {
    expect(
      () => JsonSchema.build(
        properties: {
          'value': JsonSchema.build(
            draft: SchemaDraft.draft4,
            type: SchemaType.integer,
          ),
        },
      ),
      throwsA(isA<SchemaException>()),
    );
    final validator = JsonSchema.build(
      properties: {
        'value': JsonSchema.build(
          draft: SchemaDraft.draft4,
          id: 'https://example.com/value',
          type: SchemaType.integer,
        ),
      },
    ).compile();
    expect(validator.isValid({'value': 1}), isTrue);
    expect(validator.isValid({'value': 1.0}), isFalse);
    expect(validator.validate({'value': 1.0}), isNotNull);
    expect(validator.errors({'value': 1.0}), isNotEmpty);
  });
}
