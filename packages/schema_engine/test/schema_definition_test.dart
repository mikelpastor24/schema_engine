import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:test/test.dart';

import 'generated_validators.dart';

void main() {
  void check(
    schema.CompiledSchema validator,
    Object? instance, {
    required bool valid,
  }) {
    expect(validator.isValid(instance), valid, reason: '$instance');
    expect(validator.validate(instance) == null, valid, reason: '$instance');
    expect(validator.errors(instance).isEmpty, valid, reason: '$instance');
  }

  test(
    'nullable constraints retain raw assertions and required child shapes',
    () {
      for (final draft in schema.SchemaDraft.values) {
        final value = schema
            .string()
            .withKeywords({
              'enum': ['ready'],
            })
            .nullable()
            .compile(draft: draft);
        check(value, 'ready', valid: true);
        check(value, 'other', valid: false);
        check(value, null, valid: true);
        check(
          schema.literal('ready').nullable().compile(draft: draft),
          null,
          valid: true,
        );
        check(
          schema.never().nullable().compile(draft: draft),
          null,
          valid: true,
        );
        check(
          schema.never().nullable().compile(draft: draft),
          'ready',
          valid: false,
        );
        check(
          schema.nullValue().nullable().compile(draft: draft),
          null,
          valid: true,
        );
        final object = schema
            .object({'name': schema.string()})
            .nullable()
            .compile(draft: draft);
        check(object, null, valid: true);
        check(object, {}, valid: false);
        check(object, {'name': 'ready'}, valid: true);
        final pattern = schema
            .string()
            .pattern('^a')
            .pattern(r'z$')
            .nullable()
            .nullable()
            .compile(draft: draft);
        check(pattern, null, valid: true);
        check(pattern, 'az', valid: true);
        check(pattern, 'ab', valid: false);
      }
    },
  );
  test(
    'array uniqueness and object cardinality preserve composed constraints',
    () {
      final list = schema.array(schema.any()).unique().length(2).compile();
      check(list, [1, 2], valid: true);
      check(list, [1, 1], valid: false);
      check(list, [1], valid: false);
      final shape = schema.object({}).passthrough().min(1).max(2).compile();
      check(shape, {'first': 1}, valid: true);
      check(shape, {}, valid: false);
      check(shape, {'first': 1, 'second': 2, 'third': 3}, valid: false);
    },
  );
  for (final draft in schema.SchemaDraft.values) {
    group('declarative ${draft.name}', () {
      test('generates a required object and round-trips through JSON', () {
        final definition = schema.object({
          'name': schema.string().min(1),
          'age': schema.integer().min(0).optional(),
        });
        final document = definition.toJsonSchema(draft: draft);
        final json = document.toJson() as Map<String, Object?>;
        expect(json[r'$schema'], draft.metaSchemaUri);
        expect(json['additionalProperties'], isFalse);
        final parsed = schema.JsonSchema.parse(
          definition.toJsonString(draft: draft, indent: '  '),
        );
        expect(parsed.draft, draft);
        expect(parsed.toJson(), definition.toJson(draft: draft));
        final validator = parsed.compile();
        check(validator, {'name': 'Record'}, valid: true);
        check(validator, {'name': 'Record', 'age': 2}, valid: true);
        check(validator, {}, valid: false);
        check(validator, {'name': ''}, valid: false);
        check(validator, {'name': 'Record', 'age': -1}, valid: false);
        check(validator, {'name': 'Record', 'age': null}, valid: false);
        check(validator, {'name': 'Record', 'extra': true}, valid: false);
        final properties = json['properties']! as Map<String, Object?>;
        if (draft.index < schema.SchemaDraft.draft3.index) {
          expect(
            (properties['name']! as Map<String, Object?>)['optional'],
            isFalse,
          );
          expect(
            (properties['age']! as Map<String, Object?>)['optional'],
            isTrue,
          );
        } else if (draft == schema.SchemaDraft.draft3) {
          expect(
            (properties['name']! as Map<String, Object?>)['required'],
            isTrue,
          );
          expect(
            (properties['age']! as Map<String, Object?>)['required'],
            isFalse,
          );
        } else {
          expect(json['required'], ['name']);
        }
      });
      test(
        'preserves required, optional, nullable, and nullish distinctions',
        () {
          final validator = schema
              .object({
                'required': schema.string().nullable(),
                'optional': schema.string().optional().describe(
                  'An optional string.',
                ),
                'nullish': schema.number().nullish(),
              })
              .compile(draft: draft);
          check(validator, {'required': null}, valid: true);
          check(validator, {'required': 'x', 'nullish': null}, valid: true);
          check(validator, {
            'required': 'x',
            'optional': 'y',
            'nullish': 2,
          }, valid: true);
          check(validator, {}, valid: false);
          check(validator, {'required': null, 'optional': null}, valid: false);
          check(validator, {'required': 1}, valid: false);
        },
      );
      test('translates inclusive and exclusive numeric bounds', () {
        final validator = schema
            .number()
            .gte(1)
            .gt(2)
            .lt(5)
            .lte(4)
            .compile(draft: draft);
        for (final value in [2.1, 3, 4]) {
          check(validator, value, valid: true);
        }
        for (final value in [1, 2, 4.1, 5, null, '3', double.infinity]) {
          check(validator, value, valid: false);
        }
        final integer = schema.number().int().positive().compile(draft: draft);
        check(integer, 2, valid: true);
        check(integer, 0, valid: false);
        check(integer, 1.5, valid: false);
        check(integer, 2.0, valid: draft.supportsBooleanSchemas);
      });
      test('generates literals, enums, unions, and intersections', () {
        final literal = schema
            .literal({
              'code': [1, null],
            })
            .compile(draft: draft);
        check(literal, {
          'code': [1, null],
        }, valid: true);
        check(literal, {
          'code': [1],
        }, valid: false);
        final choices = schema
            .enumValues(['pending', 'ready'])
            .compile(draft: draft);
        check(choices, 'ready', valid: true);
        check(choices, 'unknown', valid: false);
        final union = schema
            .string()
            .min(2)
            .or(schema.integer().min(3))
            .compile(draft: draft);
        check(union, 'ab', valid: true);
        check(union, 3, valid: true);
        check(union, 'a', valid: false);
        check(union, 2, valid: false);
        check(union, true, valid: false);
        final intersection = schema
            .number()
            .min(2)
            .and(schema.number().max(4))
            .compile(draft: draft);
        check(intersection, 3, valid: true);
        check(intersection, 1, valid: false);
        check(intersection, 5, valid: false);
      });
      test(
        'generates nested arrays, fixed tuples, rest tuples, and records',
        () {
          final list = schema
              .array(schema.object({'name': schema.string()}))
              .nonempty()
              .max(2)
              .compile(draft: draft);
          check(list, [
            {'name': 'Record'},
          ], valid: true);
          check(list, [], valid: false);
          check(list, [<String, Object?>{}], valid: false);
          final tuple = schema.tuple([schema.string(), schema.boolean()]);
          check(tuple.compile(draft: draft), ['x', true], valid: true);
          check(tuple.compile(draft: draft), ['x'], valid: false);
          check(tuple.compile(draft: draft), ['x', true, 1], valid: false);
          final rest = tuple.rest(schema.integer()).compile(draft: draft);
          check(rest, ['x', true, 1, 2], valid: true);
          check(rest, ['x', true, null], valid: false);
          check(rest, ['x'], valid: false);
          final empty = schema.tuple([]).compile(draft: draft);
          check(empty, [], valid: true);
          check(empty, [1], valid: false);
          final values = schema.record(schema.number()).compile(draft: draft);
          check(values, {'first': 1, 'second': 2.5}, valid: true);
          check(values, {'first': '1'}, valid: false);
          check(values, {}, valid: true);
        },
      );
      test('handles empty shapes and required arbitrary JSON values', () {
        final empty = schema.object({}).compile(draft: draft);
        check(empty, {}, valid: true);
        check(empty, {'extra': 1}, valid: false);
        final arbitrary = schema
            .object({'value': schema.any()})
            .compile(draft: draft);
        check(arbitrary, {'value': null}, valid: true);
        check(arbitrary, {}, valid: false);
        final impossible = schema
            .object({'value': schema.never().optional()})
            .compile(draft: draft);
        check(impossible, {}, valid: true);
        check(impossible, {'value': null}, valid: false);
        check(
          schema.any().describe('Any JSON value.').compile(draft: draft),
          null,
          valid: true,
        );
        check(
          schema.never().describe('No JSON values.').compile(draft: draft),
          1,
          valid: false,
        );
      });
    });
  }
  test(
    'modifiers create reusable declarations without changing earlier values',
    () {
      final base = schema.string();
      final short = base.min(1).max(2);
      expect(base.compile().isValid(''), isTrue);
      expect(short.compile().isValid(''), isFalse);
      expect(short.compile().isValid('ab'), isTrue);
      expect(short.compile().isValid('abc'), isFalse);
      final shape = {'name': schema.string()};
      final object = schema.object(shape);
      shape['name'] = schema.string().min(10);
      expect(object.compile().isValid({'name': 'a'}), isTrue);
      expect(
        () => object.shape['extra'] = schema.string(),
        throwsUnsupportedError,
      );
      final list = <schema.SchemaDefinition>[schema.string()];
      final tuple = schema.tuple(list);
      list.add(schema.number());
      expect(tuple.compile().isValid(['x']), isTrue);
      expect(() => tuple.elements.add(schema.number()), throwsUnsupportedError);
    },
  );
  test('partial, required, pick, omit, and extend preserve shape policies', () {
    final base = schema.object({
      'name': schema.string(),
      'age': schema.integer().optional(),
    }).passthrough();
    final partial = base.partial();
    expect(partial.compile().isValid({}), isTrue);
    expect(base.compile().isValid({}), isFalse);
    expect(partial.compile().isValid({'age': null}), isFalse);
    final required = partial.required();
    expect(required.compile().isValid({'name': 'x'}), isFalse);
    expect(
      required.compile().isValid({'name': 'x', 'age': 1, 'extra': true}),
      isTrue,
    );
    expect(base.partial(keys: ['name']).compile().isValid({}), isTrue);
    expect(
      base.required(keys: ['age']).compile().isValid({'name': 'x'}),
      isFalse,
    );
    expect(base.pick(['age']).compile().isValid({}), isTrue);
    expect(base.omit(['name']).shape.keys, ['age']);
    final extended = base.extend({
      'name': schema.string().min(2),
      'active': schema.boolean(),
    });
    expect(extended.compile().isValid({'name': 'ab', 'active': true}), isTrue);
    expect(extended.compile().isValid({'name': 'a', 'active': true}), isFalse);
    for (final operation in [
      () => base.pick(['missing']),
      () => base.omit(['missing']),
      () => base.partial(keys: ['missing']),
      () => base.required(keys: ['missing']),
    ]) {
      expect(operation, throwsArgumentError);
    }
  });
  test('partial is shallow and required retains nullable types', () {
    final nested = schema.object({
      'child': schema.object({'name': schema.string()}),
    }).partial();
    expect(nested.compile().isValid({}), isTrue);
    expect(nested.compile().isValid({'child': <String, Object?>{}}), isFalse);
    final nullable = schema.object({
      'name': schema.string().nullish(),
    }).required();
    expect(nullable.compile().isValid({}), isFalse);
    expect(nullable.compile().isValid({'name': null}), isTrue);
    expect(schema.string().optional().nonOptional().isOptional, isFalse);
  });
  test('strict, passthrough, and catchall do not transform instances', () {
    final base = schema.object({'name': schema.string()});
    final input = <String, Object?>{'name': 'Record', 'extra': 1};
    expect(base.compile().isValid(input), isFalse);
    expect(base.passthrough().compile().isValid(input), isTrue);
    expect(input, {'name': 'Record', 'extra': 1});
    expect(base.catchall(schema.integer()).compile().isValid(input), isTrue);
    expect(base.catchall(schema.string()).compile().isValid(input), isFalse);
    expect(base.passthrough().strict().compile().isValid(input), isFalse);
    expect(schema.looseObject({}).compile().isValid(input), isTrue);
    expect(schema.strictObject({}).compile().isValid(input), isFalse);
  });
  test(
    'optional unions and intersections compute presence independently of null',
    () {
      expect(
        schema.union([schema.string(), schema.number().optional()]).isOptional,
        isTrue,
      );
      expect(
        schema.string().optional().and(schema.number()).isOptional,
        isFalse,
      );
      expect(
        schema.string().optional().and(schema.number().optional()).isOptional,
        isTrue,
      );
      expect(schema.nullValue().isOptional, isFalse);
      final validator = schema.object({
        'value': schema.union([schema.string(), schema.number().optional()]),
      }).compile();
      expect(validator.isValid({}), isTrue);
      expect(validator.isValid({'value': null}), isFalse);
    },
  );
  test(
    'repeated constraints retain all checks, including incompatible bounds',
    () {
      expect(schema.string().min(3).min(1).compile().isValid('ab'), isFalse);
      expect(schema.string().max(2).max(4).compile().isValid('abc'), isFalse);
      expect(
        schema.array(schema.any()).min(2).min(1).compile().isValid([1]),
        isFalse,
      );
      expect(schema.number().min(3).min(1).compile().isValid(2), isFalse);
      expect(schema.number().max(2).max(4).compile().isValid(3), isFalse);
      expect(schema.number().gt(3).gt(1).compile().isValid(3), isFalse);
      expect(schema.number().lt(2).lt(4).compile().isValid(2), isFalse);
      expect(schema.string().min(4).length(2).compile().isValid('ab'), isFalse);
      for (final draft in schema.SchemaDraft.values) {
        final regex = schema
            .string()
            .pattern('^a')
            .pattern(r'z$')
            .compile(draft: draft);
        expect(regex.isValid('az'), isTrue);
        expect(regex.isValid('ab'), isFalse);
        expect(regex.isValid('bz'), isFalse);
        if (draft.index >= schema.SchemaDraft.draft2.index) {
          final multiple = schema
              .number()
              .multipleOf(2)
              .multipleOf(3)
              .compile(draft: draft);
          expect(multiple.isValid(6), isTrue);
          expect(multiple.isValid(2), isFalse);
          expect(multiple.isValid(3), isFalse);
        }
      }
    },
  );
  test(
    'length counts Unicode code points and accepts exact numeric values',
    () {
      final single = schema.string().length(1).compile();
      expect(single.isValid('😀'), isTrue);
      expect(single.isValid('😀😀'), isFalse);
      expect(
        schema.integer().compile().isValid(
          BigInt.parse('999999999999999999999'),
        ),
        isTrue,
      );
      expect(schema.number().negative().compile().isValid(-0.1), isTrue);
      expect(schema.number().nonpositive().compile().isValid(0), isTrue);
      expect(schema.number().nonnegative().compile().isValid(-1), isFalse);
    },
  );
  test('formats keep the engine options and custom formats', () {
    final email = schema.string().email();
    expect(email.compile().isValid('invalid'), isTrue);
    expect(
      email
          .compile(options: schema.SchemaOptions(assertFormats: true))
          .isValid('invalid'),
      isFalse,
    );
    expect(
      schema
          .string()
          .url()
          .compile(options: schema.SchemaOptions(assertFormats: true))
          .isValid('https://example.test'),
      isTrue,
    );
    expect(
      schema
          .string()
          .uuid()
          .compile(options: schema.SchemaOptions(assertFormats: true))
          .isValid('invalid'),
      isFalse,
    );
    expect(
      schema
          .string()
          .datetime()
          .compile(options: schema.SchemaOptions(assertFormats: true))
          .isValid('2026-10-10T12:30:00Z'),
      isTrue,
    );
    final both = schema
        .string()
        .format('starts-a')
        .format('ends-z')
        .compile(
          options: schema.SchemaOptions(
            assertFormats: true,
            formats: {
              'starts-a': (value) => value.startsWith('a'),
              'ends-z': (value) => value.endsWith('z'),
            },
          ),
        );
    expect(both.isValid('az'), isTrue);
    expect(both.isValid('ab'), isFalse);
  });
  test(
    'metadata, defaults, raw keywords, and literal inputs are snapshotted',
    () {
      final keywords = <String, Object?>{
        'examples': [1],
        'x-note': {'enabled': true},
      };
      final definition = schema
          .integer()
          .optional()
          .defaultValue(1)
          .describe('An integer.')
          .withKeywords(keywords);
      (keywords['examples']! as List<int>).add(2);
      final json = definition.toJson() as Map<String, Object?>;
      expect(json['description'], 'An integer.');
      expect(json['default'], 1);
      expect(json['examples'], [1]);
      expect(definition.isOptional, isTrue);
      final required = schema.object({
        'name': schema.string().defaultValue('Record'),
      });
      expect(required.compile().isValid({}), isFalse);
      final value = <String, Object?>{
        'code': [1],
      };
      final literal = schema.literal(value);
      (value['code']! as List<int>).add(2);
      expect(
        literal.compile().isValid({
          'code': [1],
        }),
        isTrue,
      );
      expect(literal.compile().isValid(value), isFalse);
      expect(
        schema.string().withKeywords({'type': 'number'}).compile().isValid(1),
        isTrue,
      );
    },
  );
  test(
    'rejects invalid construction arguments and incompatible dialect features',
    () {
      for (final operation in [
        () => schema.string().min(-1),
        () => schema.array(schema.any()).max(-1),
        () => schema.object({}).min(-1),
        () => schema.number().min(double.nan),
        () => schema.number().max(double.infinity),
        () => schema.number().multipleOf(0),
        () => schema.number().multipleOf(-1),
        () => schema.enumValues([]),
        () => schema.enumValues(['x', 'x']),
        () => schema.union([]),
        () => schema.string().regex(RegExp('a', caseSensitive: false)),
        () => schema.string().regex(RegExp('a', multiLine: true)),
        () => schema.string().regex(RegExp('a', dotAll: true)),
      ]) {
        expect(operation, throwsArgumentError);
      }
      expect(() => schema.string().pattern('['), throwsFormatException);
      expect(
        schema.string().regex(RegExp(r'^a$')).compile().isValid('a'),
        isTrue,
      );
      expect(
        () => schema
            .number()
            .multipleOf(2)
            .toJsonSchema(draft: schema.SchemaDraft.draft0),
        throwsA(isA<schema.SchemaException>()),
      );
      expect(
        () => schema
            .array(schema.any())
            .unique()
            .toJsonSchema(draft: schema.SchemaDraft.draft1),
        throwsA(isA<schema.SchemaException>()),
      );
      expect(
        () => schema
            .object({})
            .min(1)
            .toJsonSchema(draft: schema.SchemaDraft.draft3),
        throwsA(isA<schema.SchemaException>()),
      );
    },
  );
  test('dialect overrides apply during declaration generation', () {
    final validator = schema
        .number()
        .gt(1)
        .compile(
          options: schema.SchemaOptions(draft: schema.SchemaDraft.draft4),
        );
    expect(validator.draft, schema.SchemaDraft.draft4);
    expect(validator.isValid(1), isFalse);
    expect(validator.isValid(1.5), isTrue);
    final source = schema.JsonSchema.build(
      draft: schema.SchemaDraft.draft7,
      type: schema.SchemaType.string,
    );
    expect(
      schema.fromSchema(source).toJsonSchema(draft: schema.SchemaDraft.draft7),
      same(source),
    );
    expect(
      () => schema.fromSchema(source).toJsonSchema(),
      throwsA(isA<schema.SchemaException>()),
    );
  });
  test(
    'embedded references retain offline and async preparation options',
    () async {
      final declaration = schema.object({
        'value': schema.fromSchema(
          schema.JsonSchema.fromJson({r'$ref': 'child'}),
        ),
      });
      final base = Uri.parse('https://example.test/root');
      final offline = declaration.compile(
        baseUri: base,
        options: schema.SchemaOptions(
          resources: {
            Uri.parse('https://example.test/child'): {'type': 'integer'},
          },
        ),
      );
      expect(offline.isValid({'value': 1}), isTrue);
      expect(offline.isValid({'value': 'x'}), isFalse);
      var calls = 0;
      final asynchronous = await declaration.compileAsync(
        baseUri: base,
        options: schema.SchemaOptions(
          resolver: (uri) async {
            calls++;
            expect(uri, Uri.parse('https://example.test/child'));
            return {'type': 'integer'};
          },
        ),
      );
      expect(calls, 1);
      expect(asynchronous.isValid({'value': 1}), isTrue);
      expect(asynchronous.isValid({'value': null}), isFalse);
      expect(calls, 1);
    },
  );
  test(
    'generated code consumes the same ordinary JsonSchema representation',
    () {
      final document = schema.object({
        'name': schema.string().min(1),
        'age': schema.integer().nonnegative().optional(),
        'note': schema.string().min(1).nullable(),
      }).toJsonSchema();
      final native = schema.JsonSchema.build(
        type: schema.SchemaType.object,
        properties: {
          'name': schema.JsonSchema.build(
            type: schema.SchemaType.string,
            minLength: 1,
          ),
          'age': schema.JsonSchema.build(
            type: schema.SchemaType.integer,
            minimum: 0,
          ),
          'note': schema.JsonSchema.build(
            types: [schema.SchemaType.string, schema.SchemaType.nullValue],
            minLength: 1,
          ),
        },
        required: ['name', 'note'],
        additionalProperties: schema.JsonSchema.fromJson(false),
      );
      expect(document.value, native.value);
      final runtime = document.compile();
      final generated = GeneratedDeclarative();
      expect(generated.isSpecialized, isTrue);
      for (final value in <Object?>[
        {'name': 'Record', 'note': null},
        {'name': 'Record', 'age': 2, 'note': 'Message'},
        {'name': 'Record', 'age': BigInt.one, 'note': null},
        {},
        {'name': 'Record'},
        {'name': '', 'note': null},
        {'name': 'Record', 'age': null, 'note': null},
        {'name': 'Record', 'age': -1, 'note': null},
        {'name': 'Record', 'note': ''},
        {'name': 'Record', 'note': 1},
        {'name': 'Record', 'note': null, 'extra': true},
      ]) {
        final valid = runtime.isValid(value);
        expect(generated.isValid(value), valid);
        expect(generated.validate(value) == null, valid);
        expect(generated.errors(value).isEmpty, valid);
      }
      final source = schema.SchemaCodeGenerator(document)
          .generate(className: 'UserValidator');
      expect(source, contains('final class UserValidator'));
      expect(source, contains('isSpecialized'));
      expect(source, isNot(contains('SchemaDefinition')));
    },
  );
}
