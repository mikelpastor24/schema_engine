import 'dart:convert';
import 'dart:io';

import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

void main() {
  for (final draft in SchemaDraft.values) {
    group('${draft.name} semantics', () {
      test('builds universal and rejecting schemas', () {
        final universal = JsonSchema.any(draft: draft).compile();
        final rejecting = JsonSchema.never(draft: draft).compile();
        for (final instance in <Object?>[
          null,
          1,
          'value',
          true,
          <Object?>[],
          <String, Object?>{},
        ]) {
          expect(universal.isValid(instance), isTrue);
          expect(rejecting.isValid(instance), isFalse);
          expect(rejecting.validate(instance), isNotNull);
        }
      });
      test('merges inclusive and exclusive builder bounds correctly', () {
        final lower = JsonSchema.build(
          draft: draft,
          minimum: 3,
          exclusiveMinimum: 2,
        ).compile();
        expect(lower.isValid(2.5), isFalse);
        expect(lower.isValid(3), isTrue);
        final upper = JsonSchema.build(
          draft: draft,
          maximum: 2,
          exclusiveMaximum: 3,
        ).compile();
        expect(upper.isValid(2.5), isFalse);
        expect(upper.isValid(2), isTrue);
        final equal = JsonSchema.build(
          draft: draft,
          minimum: 2,
          exclusiveMinimum: 2,
        ).compile();
        expect(equal.isValid(2), isFalse);
        expect(equal.isValid(2.5), isTrue);
      });
      void check(Object schema, Object? instance, bool expected) {
        final validator = JsonSchema.fromJson(schema, draft: draft).compile();
        expect(validator.isValid(instance), expected);
        expect(validator.validate(instance) == null, expected);
        expect(validator.errors(instance).isEmpty, expected);
      }

      test('distinguishes integral doubles at the Draft 06 boundary', () {
        check({'type': 'integer'}, 1.0, draft.supportsBooleanSchemas);
        check({'type': 'integer'}, 1, true);
      });
      test('applies reference siblings only in vocabulary dialects', () {
        check(
          {
            r'$ref': '#/definitions/value',
            'type': 'string',
            'definitions': {
              'value': {'type': 'integer'},
            },
          },
          7,
          !draft.supportsVocabularies,
        );
      });
      test('ignores keywords introduced in a later draft', () {
        if (draft.isLegacy) {
          check({'maxProperties': 0, 'minProperties': 9}, {'x': 1}, true);
        }
        if (draft.index < SchemaDraft.draft2.index) {
          check({'uniqueItems': 'annotation'}, [1, 1], true);
        }
        if (draft.index < SchemaDraft.draft7.index) {
          check(
            {
              'if': {'type': 'invalid'},
              'then': {'minLength': -1},
              'else': {'maximum': 'invalid'},
            },
            null,
            true,
          );
        }
        if (!draft.supportsVocabularies) {
          check(
            {
              'dependentSchemas': {
                'x': {'type': 'invalid'},
              },
              'unevaluatedProperties': {'type': 'invalid'},
            },
            {},
            true,
          );
        }
        if (draft != SchemaDraft.draft202012) {
          check(
            {
              'prefixItems': [
                {'type': 'invalid'},
              ],
            },
            [7],
            true,
          );
        }
      });
      test('honors explicit dialect selection', () {
        final schema = JsonSchema.fromJson({
          r'$schema': SchemaDraft.draft202012.metaSchemaUri,
          'type': 'integer',
        }, draft: draft);
        expect(schema.compile().isValid(1.0), draft.supportsBooleanSchemas);
      });
      test('loads the original example document', () {
        final file = File('example/schemas/${draft.name}.schema.json');
        final schema = JsonSchema.parse(file.readAsStringSync());
        expect(schema.draft, draft);
        expect(
          schema.compile().isValid({'name': 'Example', 'age': 37}),
          isTrue,
        );
        expect(schema.compile().isValid({'age': 37}), isFalse);
      });
      if (draft.isLegacy) {
        test(
          'accepts empty legacy schema arrays and custom primitive types',
          () {
            check({'type': <Object?>[]}, null, false);
            check({'extends': <Object?>[]}, null, true);
            check({'disallow': <Object?>[]}, null, true);
            check({'type': 'application-defined-type'}, null, true);
            check(
              {
                'items': <Object?>[],
                'additionalProperties': false,
                'additionalItems': false,
              },
              <Object?>[],
              true,
            );
            check(
              {
                'items': <Object?>[],
                'additionalProperties': false,
                'additionalItems': false,
              },
              [1],
              false,
            );
          },
        );
        test('supports schema alternatives in type and disallow', () {
          check(
            {
              'type': [
                'string',
                {'type': 'integer', 'minimum': 5},
              ],
            },
            7,
            true,
          );
          check(
            {
              'type': [
                'string',
                {'type': 'integer', 'minimum': 5},
              ],
            },
            3,
            false,
          );
          check(
            {
              'disallow': [
                'string',
                {'minimum': 5, 'type': 'number'},
              ],
            },
            3,
            true,
          );
          check(
            {
              'disallow': [
                'string',
                {'minimum': 5, 'type': 'number'},
              ],
            },
            7,
            false,
          );
        });
        test('supports extends and legacy property presence', () {
          check(
            {
              'extends': [
                {'type': 'integer'},
                {'minimum': 5},
              ],
            },
            7,
            true,
          );
          check(
            {
              'extends': [
                {'type': 'integer'},
                {'minimum': 5},
              ],
            },
            3,
            false,
          );
          final keyword = draft == SchemaDraft.draft3 ? 'required' : 'optional';
          check(
            {
              'properties': {
                'x': {keyword: draft == SchemaDraft.draft3},
              },
            },
            {},
            false,
          );
          check(
            {
              'properties': {
                'x': {keyword: draft != SchemaDraft.draft3},
              },
            },
            {},
            true,
          );
        });
      }
      if (draft.index < SchemaDraft.draft3.index) {
        test('supports requires and equality flags', () {
          check(
            {
              'properties': {
                'x': {'optional': true, 'requires': 'y'},
              },
            },
            {'x': 1},
            false,
          );
          check(
            {
              'properties': {
                'x': {'optional': true, 'requires': 'y'},
              },
            },
            {'x': 1, 'y': 2},
            true,
          );
          check({'minimum': 4, 'minimumCanEqual': false}, 4, false);
          check({'maximum': 4, 'maximumCanEqual': false}, 4, false);
        });
      }
      if (draft.index < SchemaDraft.draft2.index) {
        test('supports maxDecimal', () {
          check({'maxDecimal': 2}, 1.25, true);
          check({'maxDecimal': 2}, 1.251, false);
          check({'maxDecimal': 0}, 1, true);
        });
      }
      if (draft.index >= SchemaDraft.draft2.index) {
        test('supports rational multiples and uniqueness', () {
          check(
            {draft.isLegacy ? 'divisibleBy' : 'multipleOf': 0.1},
            0.3,
            true,
          );
          check(
            {draft.isLegacy ? 'divisibleBy' : 'multipleOf': 0.1},
            0.30000000000000004,
            false,
          );
          check({'uniqueItems': true}, [true, 1, '1'], true);
          check({'uniqueItems': true}, [1, 1.0], false);
        });
      }
      if (draft.index >= SchemaDraft.draft3.index &&
          !draft.supportsVocabularies) {
        test('supports property and schema dependencies', () {
          check(
            {
              'dependencies': {
                'x': ['y'],
              },
            },
            {'x': 1},
            false,
          );
          check(
            {
              'dependencies': {
                'x': ['y'],
              },
            },
            {'x': 1, 'y': 2},
            true,
          );
          check(
            {
              'dependencies': {
                'x': {
                  'properties': {
                    'y': {'type': 'string'},
                  },
                },
              },
            },
            {'x': 1, 'y': 2},
            false,
          );
        });
      }
      if (draft == SchemaDraft.draft3) {
        test('accepts string property dependencies', () {
          check(
            {
              'dependencies': {'x': 'y'},
            },
            {'x': 1},
            false,
          );
          check(
            {
              'dependencies': {'x': 'y'},
            },
            {'x': 1, 'y': 2},
            true,
          );
        });
      }
      if (draft.supportsBooleanSchemas) {
        test('supports boolean schemas and null constants', () {
          check(true, null, true);
          check(false, null, false);
          check({'const': null}, null, true);
          check({'const': null}, 0, false);
        });
      }
    });
  }
  test('cross-checks exact multiples over a bounded decimal grid', () {
    for (var divisor = 1; divisor <= 20; divisor++) {
      final validator = JsonSchema.fromJson({'multipleOf': divisor / 100})
          .compile();
      for (var numerator = -200; numerator <= 200; numerator++) {
        // Encoding the grid as decimal strings avoids doing the oracle's
        // divisibility calculation with floating-point arithmetic.
        final text =
            '${numerator < 0 ? '-' : ''}${numerator.abs() ~/ 100}.'
            '${(numerator.abs() % 100).toString().padLeft(2, '0')}';
        final instance = jsonDecode(text);
        expect(
          validator.isValid(instance),
          numerator % divisor == 0,
          reason: '$text / ${divisor / 100}',
        );
      }
    }
  });
  test('handles encoded pointer fragments without decoding twice', () {
    final validator = JsonSchema.fromJson({
      'definitions': {
        '%field': {'type': 'integer'},
      },
      r'$ref': '#/definitions/%25field',
    }).compile();
    expect(validator.isValid(1), isTrue);
    expect(validator.isValid('1'), isFalse);
  });
  test('keeps nested unevaluated annotations local', () {
    final validator = JsonSchema.fromJson({
      'properties': {'x': true},
      'allOf': [
        {'unevaluatedProperties': false},
      ],
      'unevaluatedProperties': true,
    }).compile();
    expect(validator.isValid({'x': 1}), isFalse);
  });
}
