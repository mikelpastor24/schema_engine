import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

void main() {
  final cases = <String, (List<String>, List<String>)>{
    'date': (
      ['2024-02-29', '2000-02-29'],
      ['2023-02-29', '1900-02-29', '2024-13-01'],
    ),
    'time': (
      ['23:59:60Z', '12:00:00+01:30'],
      ['23:59:61Z', '24:00:00Z', '12:00:60Z'],
    ),
    'date-time': (['2024-02-29T23:59:59Z'], ['2023-02-29T00:00:00Z']),
    'duration': (
      ['P1Y2M3DT4H5M6S', 'P3W', 'PT0S'],
      ['P', 'PT', 'P1Y3D', 'PT1H3S'],
    ),
    'ipv4': (['192.0.2.1', '0.0.0.0'], ['256.0.0.1', '192.00.2.1', '1.2.3']),
    'ipv6': (
      ['::1', '2001:db8::1', '::ffff:192.0.2.1'],
      [':::', '1::2::3', 'fe80::1%zone'],
    ),
    'email': (
      ['user@example.com', '"a b"@example.com', 'a@[ipv6:::1]'],
      ['a..b@example.com', 'a@example.com.'],
    ),
    'hostname': (
      ['example.com', 'xn--mnchen-3ya.example'],
      ['example.com.', 'xn--x', 'bad_host', '-bad'],
    ),
    'idn-hostname': (
      ['münchen.example', '例子。测试', 'ａｂｃ．example'],
      ['bad_host', 'a\u200d.example'],
    ),
    'idn-email': (['用户@example.com'], ['用户@bad_host']),
    'uri': (
      ['https://example.com/a', 'urn:example:record'],
      ['/relative', 'https://example.com/[::1]'],
    ),
    'uri-reference': (
      ['/relative', '#fragment', ''],
      ['a b', 'a%GG', '/[::1]'],
    ),
    'iri': (['https://例子.example/路径'], ['relative', 'https://example.com/%GG']),
    'iri-reference': (['路径', '#片段'], ['a b']),
    'uuid': (
      ['550e8400-e29b-41d4-a716-446655440000'],
      ['{550e8400-e29b-41d4-a716-446655440000}'],
    ),
    'json-pointer': (['', '/a~1b/~0', '/'], ['#/', '/a~2']),
    'relative-json-pointer': (['0', '1#', '2/a~1b'], ['01', '-1', '0/~2']),
    'uri-template': (
      ['https://example.com/{name}', '/{+path}{?x,y}', 'a😀b'],
      ['{', '{name:0}', 'a b'],
    ),
    'regex': ([r'^a+$', '[a-z]'], ['[', '(']),
  };
  for (final entry in cases.entries) {
    test('${entry.key} format', () {
      final schema = JsonSchema.fromJson({'format': entry.key});
      final validator = schema.compile(
        options: SchemaOptions(assertFormats: true),
      );
      for (final valid in entry.value.$1) {
        expect(validator.isValid(valid), isTrue, reason: valid);
        expect(validator.validate(valid), isNull);
      }
      for (final invalid in entry.value.$2) {
        expect(validator.isValid(invalid), isFalse, reason: invalid);
        expect(validator.errors(invalid), isNotEmpty);
        expect(schema.compile().isValid(invalid), isTrue);
      }
      expect(validator.isValid(7), isTrue);
    });
  }
  for (final draft in [SchemaDraft.draft201909, SchemaDraft.draft202012]) {
    test('${draft.name} custom vocabularies', () {
      final metaUri = Uri.parse('https://example.com/custom-meta');
      final prefix = draft == SchemaDraft.draft202012 ? '2020-12' : '2019-09';
      final metadata = <String, Object?>{
        r'$schema': draft.metaSchemaUri,
        r'$vocabulary': {
          'https://json-schema.org/draft/$prefix/vocab/core': true,
          'https://json-schema.org/draft/$prefix/vocab/applicator': true,
          'https://example.com/optional-vocabulary': false,
        },
      };
      final schema = JsonSchema.fromJson({
        r'$schema': metaUri.toString(),
        'type': 'integer',
        'minimum': 'ignored',
        'properties': {'name': <String, Object?>{}},
      }, draft: draft);
      final validator = schema.compile(
        options: SchemaOptions(resources: {metaUri: metadata}),
      );
      expect(
        validator.isValid('type is an annotation in this dialect'),
        isTrue,
      );
      expect(validator.isValid({'name': 'value'}), isTrue);
      final unsupported = {
        ...metadata,
        r'$vocabulary': {'https://example.com/unsupported': true},
      };
      expect(
        () => schema.compile(
          options: SchemaOptions(resources: {metaUri: unsupported}),
        ),
        throwsA(isA<SchemaException>()),
      );
    });
  }
  test('IPv4 checks every octet boundary and rejects malformed components', () {
    final validator = JsonSchema.fromJson({'format': 'ipv4'})
        .compile(options: SchemaOptions(assertFormats: true));
    for (var position = 0; position < 4; position++) {
      for (var octet = 0; octet <= 255; octet++) {
        final parts = List.filled(4, '0')..[position] = '$octet';
        expect(validator.isValid(parts.join('.')), isTrue);
      }
      for (final octet in [-1, 256, 999, 1000]) {
        final parts = List.filled(4, '0')..[position] = '$octet';
        final value = parts.join('.');
        expect(validator.isValid(value), isFalse);
        expect(validator.validate(value), isNotNull);
        expect(validator.errors(value), isNotEmpty);
      }
    }
    for (final value in [
      '',
      '0',
      '0.0.0',
      '0.0.0.0.0',
      '0..0.0',
      '0.0.0.',
      '0.0.0.00',
      '0.0.0.01',
      '+1.2.3.4',
      '1.2.3.4 ',
      '\n1.2.3.4',
      '١.٢.٣.٤',
      '0000.0.0.0',
    ]) {
      expect(validator.isValid(value), isFalse, reason: value);
      expect(validator.validate(value), isNotNull);
      expect(validator.errors(value), isNotEmpty);
    }
  });
  test('a required assertion vocabulary enables format validation', () {
    final metaUri = Uri.parse('https://example.com/strict-format');
    final metadata = {
      r'$schema': SchemaDraft.draft202012.metaSchemaUri,
      r'$vocabulary': {
        'https://json-schema.org/draft/2020-12/vocab/core': true,
        'https://json-schema.org/draft/2020-12/vocab/format-assertion': true,
      },
    };
    final validator = JsonSchema.fromJson(
      {r'$schema': metaUri.toString(), 'format': 'email'},
      draft: SchemaDraft.draft202012,
    ).compile(options: SchemaOptions(resources: {metaUri: metadata}));
    expect(validator.isValid('invalid'), isFalse);
    expect(validator.isValid('user@example.com'), isTrue);
  });
  test('resource dialects inherit the selected root default', () {
    final uri = Uri.parse('https://example.com/integer');
    final validator =
        JsonSchema.fromJson({
          r'$ref': uri.toString(),
        }, draft: SchemaDraft.draft4).compile(
          options: SchemaOptions(
            resources: {
              uri: {'type': 'integer'},
            },
          ),
        );
    expect(validator.isValid(1), isTrue);
    expect(validator.isValid(1.0), isFalse);
  });
  test('rejects malformed dependency grammars during compilation', () {
    for (final schema in [
      {
        'dependencies': {'a': 4},
      },
      {
        'dependencies': {
          'a': [1],
        },
      },
      {
        'dependencies': {
          'a': ['b', 'b'],
        },
      },
    ]) {
      expect(
        () => JsonSchema.fromJson(schema, draft: SchemaDraft.draft7).compile(),
        throwsA(isA<SchemaException>()),
      );
    }
  });
  test('checks property counts on empty maps with inferred key types', () {
    final validator = JsonSchema.fromJson({'minProperties': 1}).compile();
    expect(validator.isValid({}), isFalse);
    expect(validator.validate({}), isNotNull);
  });
  for (final draft in SchemaDraft.values) {
    test('${draft.name} built-in meta-schema validates schemas offline', () {
      final validator = JsonSchema.fromJson({r'$ref': draft.metaSchemaUri})
          .compile();
      final valid = {'type': 'string', 'minLength': 1};
      final invalid = {'type': 'string', 'minLength': -1};
      expect(validator.isValid(valid), isTrue);
      expect(validator.validate(valid), isNull);
      expect(validator.errors(valid), isEmpty);
      expect(validator.isValid(invalid), isFalse);
      expect(validator.validate(invalid), isNotNull);
      expect(validator.errors(invalid), isNotEmpty);
      expect(validator.isValid(true), draft.supportsBooleanSchemas);
      expect(validator.isValid({'items': invalid}), isFalse);
    });
  }
  for (final draft in [SchemaDraft.draft201909, SchemaDraft.draft202012]) {
    final prefix = draft == SchemaDraft.draft202012 ? '2020-12' : '2019-09';
    test(
      '${draft.name} vocabulary meta-schemas describe separate grammars',
      () {
        CompiledSchema validator(String category) => JsonSchema.fromJson({
          r'$ref': 'https://json-schema.org/draft/$prefix/meta/$category',
        }).compile();
        final validation = validator('validation');
        expect(validation.isValid({'minimum': 'wrong'}), isFalse);
        expect(validation.isValid({'properties': 'extension'}), isTrue);
        final applicator = validator('applicator');
        expect(applicator.isValid({'properties': 'wrong'}), isFalse);
        expect(applicator.isValid({'minimum': 'extension'}), isTrue);
        expect(validator('core').isValid({r'$anchor': 'bad anchor'}), isFalse);
        expect(validator('meta-data').isValid({'title': false}), isFalse);
        expect(validator('content').isValid({'contentEncoding': 1}), isFalse);
        expect(
          validator(
            draft == SchemaDraft.draft202012 ? 'format-annotation' : 'format',
          ).isValid({'format': false}),
          isFalse,
        );
        if (draft == SchemaDraft.draft202012) {
          expect(
            validator('unevaluated').isValid({'unevaluatedItems': 1}),
            isFalse,
          );
          expect(
            validator('format-assertion').isValid({'format': 'email'}),
            isTrue,
          );
        }
      },
    );
    test('${draft.name} custom meta-schema restrictions reach subschemas', () {
      final uri = Uri.parse('https://example.com/extended-meta');
      final metadata = {
        r'$schema': draft.metaSchemaUri,
        if (draft == SchemaDraft.draft202012) r'$dynamicAnchor': 'meta',
        if (draft == SchemaDraft.draft201909) r'$recursiveAnchor': true,
        'allOf': [
          {r'$ref': draft.metaSchemaUri},
        ],
        'properties': {
          'x-note': {'type': 'string'},
        },
      };
      final schema = JsonSchema.fromJson({
        r'$schema': uri.toString(),
        'properties': {
          'name': {'type': 'string', 'x-note': false},
        },
      }, draft: draft);
      expect(
        () =>
            schema.compile(options: SchemaOptions(resources: {uri: metadata})),
        throwsA(
          isA<SchemaException>().having(
            (error) => error.schemaPath,
            'schemaPath',
            '/properties/name/x-note',
          ),
        ),
      );
      expect(
        schema
            .compile(
              options: SchemaOptions(
                validateSchema: false,
                resources: {uri: metadata},
              ),
            )
            .isValid({'name': 'value'}),
        isTrue,
      );
      expect(
        schema
            .compile(
              options: SchemaOptions(draft: draft, resources: {uri: metadata}),
            )
            .isValid({'name': 'value'}),
        isTrue,
      );
    });
  }
  test(
    'custom meta-schema constraints apply to separately loaded resources',
    () {
      final uri = Uri.parse('https://example.com/require-title');
      final child = Uri.parse('https://example.com/child');
      final options = SchemaOptions(
        resources: {
          uri: {
            r'$schema': SchemaDraft.draft202012.metaSchemaUri,
            'required': ['title'],
          },
          child: {r'$schema': uri.toString(), 'type': 'string'},
        },
      );
      expect(
        () =>
            JsonSchema.fromJson({r'$ref': child.toString()})
                .compile(options: options),
        throwsA(isA<SchemaException>()),
      );
    },
  );
  test('asynchronous compilation loads a custom meta-schema once', () async {
    final uri = Uri.parse('https://example.com/require-title');
    final fetched = <Uri>[];
    final validator =
        await JsonSchema.fromJson({
          r'$schema': uri.toString(),
          'title': 'A schema',
          'type': 'string',
        }, draft: SchemaDraft.draft202012).compileAsync(
          options: SchemaOptions(
            resolver: (requested) async {
              fetched.add(requested);
              return {
                r'$schema': SchemaDraft.draft202012.metaSchemaUri,
                'required': ['title'],
              };
            },
          ),
        );
    expect(fetched, [uri]);
    expect(validator.isValid('value'), isTrue);
    expect(validator.isValid(1), isFalse);
  });
  test('anchor syntax follows the resource dialect', () {
    for (final draft in [SchemaDraft.draft201909, SchemaDraft.draft202012]) {
      for (final name in ['bad anchor', '1invalid', 'trailing\n']) {
        expect(
          () => JsonSchema.fromJson({r'$anchor': name}, draft: draft).compile(),
          throwsA(isA<SchemaException>()),
        );
      }
      expect(
        JsonSchema.fromJson({
          r'$anchor': 'valid.name-1',
        }, draft: draft).compile().isValid(null),
        isTrue,
      );
    }
    expect(
      JsonSchema.fromJson({r'$anchor': '_valid'}).compile().isValid(null),
      isTrue,
    );
    expect(
      () => JsonSchema.fromJson({
        r'$anchor': '_invalid',
      }, draft: SchemaDraft.draft201909).compile(),
      throwsA(isA<SchemaException>()),
    );
    expect(
      () => JsonSchema.fromJson({r'$dynamicAnchor': 'bad anchor'}).compile(),
      throwsA(isA<SchemaException>()),
    );
  });
  test('comment keyword grammar begins in Draft 07', () {
    expect(
      JsonSchema.fromJson({
        r'$comment': false,
      }, draft: SchemaDraft.draft6).compile().isValid(null),
      isTrue,
    );
    expect(
      () => JsonSchema.fromJson({
        r'$comment': false,
      }, draft: SchemaDraft.draft7).compile(),
      throwsA(isA<SchemaException>()),
    );
  });
  for (final required in [true, false]) {
    test('Format-Assertion applies with required=$required', () {
      final uri = Uri.parse('https://example.com/format-meta');
      final resources = <Uri, Object?>{
        uri: {
          r'$schema': SchemaDraft.draft202012.metaSchemaUri,
          r'$vocabulary': {
            'https://json-schema.org/draft/2020-12/vocab/core': true,
            'https://json-schema.org/draft/2020-12/vocab/format-assertion':
                required,
          },
        },
      };
      JsonSchema schema(String format) => JsonSchema.fromJson({
        r'$schema': uri.toString(),
        'format': format,
      }, draft: SchemaDraft.draft202012);
      final validator = schema('email').compile(
        options: SchemaOptions(assertFormats: false, resources: resources),
      );
      expect(validator.isValid('invalid'), isFalse);
      expect(validator.validate('invalid'), isNotNull);
      expect(validator.errors('invalid'), isNotEmpty);
      expect(
        () =>
            schema('application-format')
                .compile(options: SchemaOptions(resources: resources)),
        throwsA(isA<SchemaException>()),
      );
      final custom = schema('application-format').compile(
        options: SchemaOptions(
          resources: resources,
          formats: {
            'application-format': (value) => value.startsWith('allowed:'),
          },
        ),
      );
      expect(custom.isValid('allowed:value'), isTrue);
      expect(custom.isValid('invalid'), isFalse);
    });
  }
  test(
    'Draft 2019-09 required formats default to assertions with an override',
    () {
      final uri = Uri.parse('https://example.com/format-meta');
      final resources = <Uri, Object?>{
        uri: {
          r'$schema': SchemaDraft.draft201909.metaSchemaUri,
          r'$vocabulary': {
            'https://json-schema.org/draft/2019-09/vocab/core': true,
            'https://json-schema.org/draft/2019-09/vocab/format': true,
          },
        },
      };
      final schema = JsonSchema.fromJson({
        r'$schema': uri.toString(),
        'format': 'email',
      }, draft: SchemaDraft.draft201909);
      expect(
        schema
            .compile(options: SchemaOptions(resources: resources))
            .isValid('invalid'),
        isFalse,
      );
      expect(
        schema
            .compile(
              options: SchemaOptions(
                assertFormats: false,
                resources: resources,
              ),
            )
            .isValid('invalid'),
        isTrue,
      );
      expect(
        JsonSchema.fromJson({
              r'$schema': uri.toString(),
              'format': 'application-format',
            }, draft: SchemaDraft.draft201909)
            .compile(options: SchemaOptions(resources: resources))
            .isValid('anything'),
        isTrue,
      );
    },
  );
  test('a custom meta-schema can be retrieved under a different URI', () {
    final retrieval = Uri.parse('https://example.com/source');
    final identifier = Uri.parse('https://example.com/meta/custom');
    final options = SchemaOptions(
      resources: {
        retrieval: {
          r'$schema': SchemaDraft.draft202012.metaSchemaUri,
          r'$id': 'meta/custom',
          r'$vocabulary': {
            'https://json-schema.org/draft/2020-12/vocab/core': true,
          },
          'required': ['title'],
        },
      },
    );
    final validator = JsonSchema.fromJson({
      r'$schema': identifier.toString(),
      'title': 'A schema',
      'minimum': 'annotation',
    }, draft: SchemaDraft.draft202012).compile(options: options);
    expect(validator.isValid('unrestricted'), isTrue);
    expect(
      () => JsonSchema.fromJson({
        r'$schema': identifier.toString(),
      }, draft: SchemaDraft.draft202012).compile(options: options),
      throwsA(isA<SchemaException>()),
    );
  });
}
