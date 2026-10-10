import 'dart:convert';

import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

import 'generated_validators.dart';

void main() {
  test('lossless decoding agrees with ordinary JSON for ordinary values', () {
    for (final source in [
      'null',
      'true',
      'false',
      '0',
      '-42',
      '0.125',
      '1.5e-2',
      r'"escaped \" quote, \\ slash, \uD83D\uDE00"',
      '[null,true,{"first":1,"first":2},"text",[]]',
      '{"line":"a\\nb","space":" ","value":-0.5}',
    ]) {
      expect(decodeJson(source), jsonDecode(source));
    }
  });
  test(
    'lossless decoding rejects malformed JSON without accepting prefixes',
    () {
      for (final source in [
        '',
        '01',
        '+1',
        '1.',
        '.5',
        '1e',
        '1e+',
        '--1',
        'NaN',
        'true false',
        '[1,]',
        '{"a":1,}',
        '{a:1}',
        '[1 2]',
        '"unfinished',
        r'"bad\x"',
        '"control\n"',
        'null\u00a0',
      ]) {
        expect(() => decodeJson(source), throwsFormatException, reason: source);
      }
    },
  );
  test('large integers remain exact in every published draft', () {
    final value = decodeJson('987654321012345678909876543210123456789');
    expect(value, isA<BigInt>());
    expect(
      decodeJson('-9223372036854775808'),
      BigInt.parse('-9223372036854775808'),
    );
    for (final draft in SchemaDraft.values) {
      for (final type in [SchemaType.integer, SchemaType.number]) {
        final validator = JsonSchema.build(draft: draft, type: type).compile();
        expect(validator.isValid(value), isTrue);
        expect(validator.validate(value), isNull);
        expect(validator.errors(value), isEmpty);
      }
    }
  });
  test('exact bounds distinguish adjacent large integers and decimals', () {
    final integer = JsonSchema.parse(
      '{"minimum":9007199254740993,"maximum":9007199254740993}',
    ).compile();
    expect(integer.isValid(decodeJson('9007199254740993')), isTrue);
    expect(integer.isValid(decodeJson('9007199254740992')), isFalse);
    expect(integer.isValid(decodeJson('9007199254740994')), isFalse);
    final decimal = JsonSchema.parse(
      '{"exclusiveMinimum":12345678901234567890.0000000001, '
      '"maximum":12345678901234567890.0000000002}',
    ).compile();
    expect(
      decimal.isValid(decodeJson('12345678901234567890.0000000001')),
      isFalse,
    );
    expect(
      decimal.isValid(decodeJson('12345678901234567890.00000000015')),
      isTrue,
    );
    expect(
      decimal.isValid(decodeJson('12345678901234567890.0000000002')),
      isTrue,
    );
    expect(
      decimal.isValid(decodeJson('12345678901234567890.0000000003')),
      isFalse,
    );
  });
  test('exact multiples work with huge integers and precise fractions', () {
    final integer = JsonSchema.fromJson({'multipleOf': 3}).compile();
    expect(integer.isValid(BigInt.parse('999999999999999999999999')), isTrue);
    expect(integer.isValid(BigInt.parse('999999999999999999999998')), isFalse);
    final decimal = JsonSchema.parse('{"multipleOf":0.000000000000000000003}')
        .compile();
    expect(decimal.isValid(decodeJson('0.000000000000000000009')), isTrue);
    expect(decimal.isValid(decodeJson('0.000000000000000000010')), isFalse);
    expect(
      decimal.isValid(JsonNumber.parse('0.000000000000000000000')),
      isTrue,
    );
  });
  test('exact numbers participate in enum and deep uniqueness', () {
    final constant = JsonSchema.fromJson({'const': JsonNumber.parse('1.00')})
        .compile();
    expect(constant.isValid(1), isTrue);
    expect(constant.isValid(BigInt.one), isTrue);
    final unique = JsonSchema.fromJson({'uniqueItems': true}).compile();
    expect(unique.isValid([1, BigInt.one]), isFalse);
    expect(unique.isValid([0.1, JsonNumber.parse('0.10')]), isFalse);
    expect(
      unique.isValid([
        {'value': BigInt.parse('9007199254740993')},
        {'value': JsonNumber.parse('9007199254740993.0')},
      ]),
      isFalse,
    );
    expect(
      unique.isValid([
        BigInt.parse('9007199254740993'),
        BigInt.parse('9007199254740994'),
      ]),
      isTrue,
    );
  });
  test('huge cardinality bounds do not overflow native integers', () {
    final validator = JsonSchema.parse(
      '{"minItems":999999999999999999999,"maxLength":999999999999999999999}',
    ).compile();
    expect(validator.isValid([]), isFalse);
    expect(validator.isValid('a'), isTrue);
    final contains = JsonSchema.parse(
      '{"contains":true,"minContains":999999999999999999999}',
    ).compile();
    expect(contains.isValid([1, 2]), isFalse);
  });
  test(
    'serialization preserves exact values and historical integer syntax',
    () {
      final source = JsonSchema.parse(
        '{"enum":[999999999999999999999],"x-decimal":999999999999999999999.0,'
        '"x-value":0.12345678901234567890123456789}',
        draft: SchemaDraft.draft4,
      );
      final restored = JsonSchema.parse(
        source.toJsonString(indent: '  '),
        draft: source.draft,
      );
      expect(
        restored.compile().isValid(BigInt.parse('999999999999999999999')),
        isTrue,
      );
      final decimal = (restored.value as Map<String, Object?>)['x-value'];
      expect(decimal, isA<JsonNumber>());
      expect(
        (decimal! as JsonNumber).compareTo(
          JsonNumber.parse('0.12345678901234567890123456789'),
        ),
        0,
      );
      final old = JsonSchema.build(
        draft: SchemaDraft.draft4,
        type: SchemaType.integer,
      ).compile();
      expect(
        old.isValid(decodeJson(encodeJson(JsonNumber.parse('1.0')))),
        isFalse,
      );
      expect(old.isValid(decodeJson('1')), isTrue);
    },
  );
  test('very large decimal exponents compare without expanding zeros', () {
    final validator = JsonSchema.parse('{"maximum":1e100000}').compile();
    expect(validator.isValid(decodeJson('9e99999')), isTrue);
    expect(validator.isValid(decodeJson('2e100000')), isFalse);
    expect(
      JsonNumber.parse('-1e100000').compareTo(JsonNumber.parse('-9e99999')),
      lessThan(0),
    );
  });
  test('generated scalar and nested checks accept exact numeric instances', () {
    expect(GeneratedInteger().isValid(BigInt.from(12)), isTrue);
    expect(GeneratedInteger().isValid(BigInt.from(1001)), isFalse);
    expect(GeneratedInteger().isValid(JsonNumber.parse('12.0')), isTrue);
    expect(
      GeneratedObject().isValid({'id': BigInt.one, 'name': 'Record'}),
      isTrue,
    );
    expect(GeneratedArray().isValid([BigInt.one]), isTrue);
    expect(GeneratedArray().isValid([BigInt.from(-1)]), isFalse);
    expect(GeneratedAlternatives().isValid(BigInt.one), isTrue);
    expect(GeneratedBigNumber().isSpecialized, isFalse);
    expect(
      GeneratedBigNumber().isValid(decodeJson('9007199254740993')),
      isTrue,
    );
    expect(
      GeneratedBigNumber().isValid(decodeJson('9007199254740992')),
      isFalse,
    );
  });
  test('retired dependencies are an explicit modern compatibility option', () {
    for (final draft in [SchemaDraft.draft201909, SchemaDraft.draft202012]) {
      final schema = JsonSchema.fromJson({
        'dependencies': {
          'name': ['age'],
          'active': {
            'required': ['name'],
          },
        },
      }, draft: draft);
      expect(schema.compile().isValid({'name': 'Record'}), isTrue);
      final validator = schema.compile(
        options: SchemaOptions(legacyDependencies: true),
      );
      expect(validator.isValid({'name': 'Record'}), isFalse);
      expect(validator.isValid({'active': true}), isFalse);
      expect(
        validator.isValid({'name': 'Record', 'age': 2, 'active': true}),
        isTrue,
      );
      for (final dependencies in <Object?>[
        false,
        {
          'x': ['x', 'x'],
        },
        {
          'x': [1],
        },
        {'x': 'y'},
      ]) {
        final malformed = JsonSchema.fromJson({
          'dependencies': dependencies,
        }, draft: draft);
        expect(malformed.compile().isValid({}), isTrue);
        expect(
          () => malformed.compile(
            options: SchemaOptions(legacyDependencies: true),
          ),
          throwsA(isA<SchemaException>()),
        );
      }
    }
  });
  test('compatibility schema dependencies preserve evaluated properties', () {
    final validator = JsonSchema.fromJson({
      'properties': {'name': true},
      'dependencies': {
        'name': {
          'properties': {'age': true},
        },
      },
      'unevaluatedProperties': false,
    }).compile(options: SchemaOptions(legacyDependencies: true));
    expect(validator.isValid({'name': 'Record', 'age': 2}), isTrue);
    expect(validator.isValid({'name': 'Record', 'extra': 2}), isFalse);
  });
  test('optional content assertions are limited to Draft 07', () {
    for (final draft in [
      SchemaDraft.draft7,
      SchemaDraft.draft201909,
      SchemaDraft.draft202012,
    ]) {
      final schema = JsonSchema.fromJson({
        'contentEncoding': 'base64',
        'contentMediaType': 'application/json',
      }, draft: draft);
      expect(schema.compile().isValid('invalid'), isTrue);
      final validator = schema.compile(
        options: SchemaOptions(assertContent: true),
      );
      expect(validator.isValid('eyJ2YWx1ZSI6MX0='), isTrue);
      expect(validator.isValid('invalid'), draft != SchemaDraft.draft7);
      expect(validator.isValid('bm90IGpzb24='), draft != SchemaDraft.draft7);
      expect(validator.isValid(1), isTrue);
    }
  });
  test(
    'asynchronous compilation retains compatibility and content options',
    () async {
      final validator = await JsonSchema.fromJson({r'$ref': 'child'})
          .compileAsync(
            options: SchemaOptions(
              legacyDependencies: true,
              resolver: (_) async => {
                'dependencies': {
                  'x': ['y'],
                },
              },
            ),
          );
      expect(validator.isValid({'x': 1}), isFalse);
    },
  );
  test(
    'legacy formats use their specified hostname, time, and color rules',
    () {
      final options = SchemaOptions(assertFormats: true);
      expect(
        JsonSchema.build(
          draft: SchemaDraft.draft4,
          format: 'hostname',
        ).compile(options: options).isValid('xy--zz.example'),
        isTrue,
      );
      final time = JsonSchema.build(
        draft: SchemaDraft.draft3,
        format: 'time',
      ).compile(options: options);
      expect(time.isValid('12:34:56'), isTrue);
      expect(time.isValid('12:34 PM'), isFalse);
      final color = JsonSchema.build(
        draft: SchemaDraft.draft3,
        format: 'color',
      ).compile(options: options);
      for (final value in ['navy', '#1a2', '#1a2B3c', 'rgb(10%, 20%, 30%)']) {
        expect(color.isValid(value), isTrue, reason: value);
      }
      for (final value in ['#12345678', 'unknown-color']) {
        expect(color.isValid(value), isFalse);
      }
    },
  );
  test('URI formats accept IPvFuture literals with either version case', () {
    for (final format in ['uri', 'iri', 'uri-reference', 'iri-reference']) {
      final validator = JsonSchema.build(format: format)
          .compile(options: SchemaOptions(assertFormats: true));
      expect(validator.isValid('https://[VA.a:b]/record'), isTrue);
      expect(validator.isValid('https://[vA.a:b]/record'), isTrue);
      expect(validator.isValid('https://[v.a:b]/record'), isFalse);
    }
  });
  test('international hostnames apply ignored zero-width-space mapping', () {
    final validator = JsonSchema.build(format: 'idn-hostname')
        .compile(options: SchemaOptions(assertFormats: true));
    expect(validator.isValid('exa\u200bmple.test'), isTrue);
  });
  test(
    'legacy references ignore sibling identifiers and find local aliases',
    () {
      final validator = JsonSchema.fromJson({
        'id': 'https://example.test/nested/',
        'definitions': {
          'local': {'id': 'value', 'type': 'integer'},
          'other': {'id': 'https://example.test/value', 'type': 'string'},
        },
        'extends': {r'$ref': 'value', 'id': 'https://example.test/'},
      }, draft: SchemaDraft.draft3).compile();
      expect(validator.isValid(1), isTrue);
      expect(validator.isValid('text'), isFalse);
    },
  );
  test(
    'custom dialect metadata loads before interpreting inactive keywords',
    () async {
      final validator =
          await JsonSchema.fromJson({
            r'$schema': 'https://example.test/meta',
            'minimum': 'inactive',
          }, draft: SchemaDraft.draft202012).compileAsync(
            options: SchemaOptions(
              resolver: (_) async => {
                r'$schema': SchemaDraft.draft202012.metaSchemaUri,
                r'$vocabulary': {
                  'https://json-schema.org/draft/2020-12/vocab/core': true,
                  'https://json-schema.org/draft/2020-12/vocab/applicator':
                      true,
                },
              },
            ),
          );
      expect(validator.isValid(-1), isTrue);
    },
  );
}
