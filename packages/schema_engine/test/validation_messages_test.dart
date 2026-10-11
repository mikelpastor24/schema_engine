import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

class _FailureCase {
  const _FailureCase(
    this.document,
    this.instance,
    this.code,
    this.parameters,
    this.messagePart, {
    this.draft = SchemaDraft.draft202012,
    this.options,
  });

  final Object document;
  final Object? instance;
  final String code;
  final Map<String, Object?> parameters;
  final String messagePart;
  final SchemaDraft draft;
  final SchemaOptions? options;
}

class _ApplicationMessages implements ValidationMessages {
  const _ApplicationMessages();

  @override
  String format(ValidationError error) =>
      'Application rule ${error.code}: ${error.parameters}';
}

class _ShortMessages extends EnglishValidationMessages {
  const _ShortMessages();

  @override
  String format(ValidationError error) =>
      error.code == ValidationErrorCodes.minLength
      ? 'Minimum length: ${error.parameters['limit']}'
      : super.format(error);
}

void main() {
  final cases = <String, _FailureCase>{
    'type': const _FailureCase(
      {'type': 'string'},
      12,
      'type',
      {
        'expectedTypes': ['string'],
        'actualType': 'integer',
      },
      'Expected string; received integer',
    ),
    'nullable union': const _FailureCase(
      {
        'type': ['string', 'null'],
      },
      false,
      'type',
      {
        'expectedTypes': ['string', 'null'],
        'actualType': 'boolean',
      },
      'string or null',
    ),
    'enum': const _FailureCase(
      {
        'enum': ['reader', 'editor'],
      },
      'admin',
      'enum',
      {
        'allowedValues': ['reader', 'editor'],
      },
      '["reader","editor"]',
    ),
    'const': const _FailureCase(
      {
        'const': {'enabled': true},
      },
      false,
      'const',
      {
        'expectedValue': {'enabled': true},
      },
      '{"enabled":true}',
    ),
    'minimum': const _FailureCase(
      {'minimum': 3},
      2,
      'minimum',
      {'limit': 3, 'exclusive': false, 'actualValue': 2},
      'at least 3',
    ),
    'maximum': const _FailureCase(
      {'maximum': 3},
      4,
      'maximum',
      {'limit': 3, 'exclusive': false, 'actualValue': 4},
      'at most 3',
    ),
    'exclusiveMinimum': const _FailureCase(
      {'exclusiveMinimum': 3},
      3,
      'exclusiveMinimum',
      {'limit': 3, 'actualValue': 3},
      'greater than 3',
    ),
    'exclusiveMaximum': const _FailureCase(
      {'exclusiveMaximum': 3},
      3,
      'exclusiveMaximum',
      {'limit': 3, 'actualValue': 3},
      'less than 3',
    ),
    'multipleOf': const _FailureCase(
      {'multipleOf': 3},
      4,
      'multipleOf',
      {'divisor': 3, 'actualValue': 4},
      'multiple of 3',
    ),
    'minLength': const _FailureCase(
      {'minLength': 3},
      '😀a',
      'minLength',
      {'limit': 3, 'length': 2},
      'at least 3 Unicode characters; received 2',
    ),
    'maxLength': const _FailureCase(
      {'maxLength': 1},
      '😀a',
      'maxLength',
      {'limit': 1, 'length': 2},
      'at most 1 Unicode character; received 2',
    ),
    'pattern': const _FailureCase(
      {'pattern': r'^a+$'},
      'bbb',
      'pattern',
      {'pattern': r'^a+$'},
      r'"^a+$"',
    ),
    'format': _FailureCase(
      {'format': 'email'},
      '12231312312',
      'format',
      {'format': 'email'},
      'valid "email"',
      options: SchemaOptions(assertFormats: true),
    ),
    'contentEncoding': _FailureCase(
      {'contentEncoding': 'base64'},
      '*invalid*',
      'contentEncoding',
      {'encoding': 'base64'},
      '"base64" content encoding',
      draft: SchemaDraft.draft7,
      options: SchemaOptions(assertContent: true),
    ),
    'contentMediaType': _FailureCase(
      {'contentEncoding': 'base64', 'contentMediaType': 'application/json'},
      'aGVsbG8=',
      'contentMediaType',
      {'encoding': 'base64', 'mediaType': 'application/json'},
      'valid "application/json" content after base64 decoding',
      draft: SchemaDraft.draft7,
      options: SchemaOptions(assertContent: true),
    ),
    'minItems': const _FailureCase({'minItems': 2}, [1], 'minItems', {
      'limit': 2,
      'count': 1,
    }, 'at least 2 items; received 1'),
    'maxItems': const _FailureCase({'maxItems': 1}, [1, 2], 'maxItems', {
      'limit': 1,
      'count': 2,
    }, 'at most 1 item; received 2'),
    'minProperties': const _FailureCase(
      {'minProperties': 2},
      {'one': 1},
      'minProperties',
      {'limit': 2, 'count': 1},
      'at least 2 properties; received 1',
    ),
    'maxProperties': const _FailureCase(
      {'maxProperties': 1},
      {'one': 1, 'two': 2},
      'maxProperties',
      {'limit': 1, 'count': 2},
      'at most 1 property; received 2',
    ),
    'uniqueItems': const _FailureCase(
      {'uniqueItems': true},
      [
        {'a': 1},
        2,
        {'a': 1.0},
      ],
      'uniqueItems',
      {'firstIndex': 0, 'secondIndex': 2},
      'indexes 0 and 2',
    ),
    'required': const _FailureCase(
      {
        'required': ['a/b~c'],
      },
      <String, Object?>{},
      'required',
      {'property': 'a/b~c'},
      'Property "a/b~c" is required',
    ),
    'dependentRequired': const _FailureCase(
      {
        'dependentRequired': {
          'card': ['address'],
        },
      },
      {'card': 12},
      'dependentRequired',
      {'property': 'card', 'missingProperty': 'address'},
      '"card" requires property "address"',
    ),
    'dependencies': const _FailureCase(
      {
        'dependencies': {
          'card': ['address'],
        },
      },
      {'card': 12},
      'dependencies',
      {'property': 'card', 'missingProperty': 'address'},
      '"card" requires property "address"',
      draft: SchemaDraft.draft7,
    ),
    'additionalProperties': const _FailureCase(
      {'additionalProperties': false},
      {'extra': true},
      'additionalProperties',
      {'property': 'extra'},
      'Additional property "extra" is not allowed',
    ),
    'unevaluatedProperties': const _FailureCase(
      {'unevaluatedProperties': false},
      {'extra': true},
      'unevaluatedProperties',
      {'property': 'extra'},
      'Unevaluated property "extra" is not allowed',
    ),
    'items': const _FailureCase(
      {
        'prefixItems': [<String, Object?>{}],
        'items': false,
      },
      [1, 2],
      'items',
      {'index': 1, 'limit': 1},
      'index 1 is not allowed; at most 1',
    ),
    'additionalItems': const _FailureCase(
      {
        'items': [<String, Object?>{}],
        'additionalItems': false,
      },
      [1, 2],
      'additionalItems',
      {'index': 1, 'limit': 1},
      'index 1 is not allowed; at most 1',
      draft: SchemaDraft.draft7,
    ),
    'unevaluatedItems': const _FailureCase(
      {'unevaluatedItems': false},
      [1],
      'unevaluatedItems',
      {'index': 0},
      'Unevaluated array item at index 0',
    ),
    'contains minimum': const _FailureCase(
      {
        'contains': {'type': 'string'},
        'minContains': 2,
      },
      ['one', 2],
      'contains',
      {'minimum': 2, 'maximum': null, 'matches': 1, 'reason': 'tooFew'},
      'at least 2 items matching the "contains" schema; 1 matched',
    ),
    'contains maximum': const _FailureCase(
      {'contains': <String, Object?>{}, 'maxContains': 1},
      [1, 2, 3],
      'contains',
      {'minimum': 1, 'maximum': 1, 'matches': 2, 'reason': 'tooMany'},
      'at most 1 item matching the "contains" schema; at least 2 matched',
    ),
    'anyOf': const _FailureCase(
      {
        'anyOf': [
          {'type': 'string'},
          {'type': 'integer'},
        ],
      },
      false,
      'anyOf',
      {'branchCount': 2, 'matches': 0},
      'at least one of 2 schemas; none matched',
    ),
    'oneOf none': const _FailureCase(
      {
        'oneOf': [
          {'type': 'string'},
          {'type': 'integer'},
        ],
      },
      false,
      'oneOf',
      {'branchCount': 2, 'matches': 0},
      'exactly one of 2 schemas; none matched',
    ),
    'oneOf multiple': const _FailureCase(
      {
        'oneOf': [
          <String, Object?>{},
          <String, Object?>{},
          <String, Object?>{},
        ],
      },
      false,
      'oneOf',
      {'branchCount': 3, 'matches': 2},
      'more than one matched',
    ),
    'not': const _FailureCase(
      {
        'not': {'type': 'string'},
      },
      'hello',
      'not',
      {'branchCount': 1, 'matches': 1},
      'must not match the schema',
    ),
    'false': const _FailureCase(
      false,
      'hello',
      'false',
      {},
      'No value is allowed',
    ),
    'legacy integer representation': const _FailureCase(
      {'type': 'integer'},
      1.0,
      'type',
      {
        'expectedTypes': ['integer'],
        'actualType': 'number',
      },
      'Expected integer; received number',
      draft: SchemaDraft.draft4,
    ),
    'legacy exclusive minimum': const _FailureCase(
      {'minimum': 3, 'exclusiveMinimum': true},
      3,
      'minimum',
      {'limit': 3, 'exclusive': true, 'actualValue': 3},
      'greater than 3',
      draft: SchemaDraft.draft4,
    ),
    'historical exclusive maximum': const _FailureCase(
      {'maximum': 3, 'maximumCanEqual': false},
      3,
      'maximum',
      {'limit': 3, 'exclusive': true, 'actualValue': 3},
      'less than 3',
      draft: SchemaDraft.draft1,
    ),
    'maxDecimal': const _FailureCase(
      {'maxDecimal': 1},
      1.25,
      'maxDecimal',
      {'limit': 1, 'decimalPlaces': 2},
      'at most 1 decimal place; received 2',
      draft: SchemaDraft.draft1,
    ),
    'divisibleBy': const _FailureCase(
      {'divisibleBy': 3},
      4,
      'divisibleBy',
      {'divisor': 3, 'actualValue': 4},
      'multiple of 3',
      draft: SchemaDraft.draft2,
    ),
    'historical requires': const _FailureCase(
      {
        'properties': {
          'card': {'optional': true, 'requires': 'address'},
        },
      },
      {'card': 12},
      'requires',
      {'property': 'card', 'missingProperty': 'address'},
      '"card" requires property "address"',
      draft: SchemaDraft.draft1,
    ),
    'historical optional': const _FailureCase(
      {
        'properties': {'name': <String, Object?>{}},
      },
      <String, Object?>{},
      'optional',
      {'property': 'name'},
      'Property "name" is required',
      draft: SchemaDraft.draft1,
    ),
    'historical required': const _FailureCase(
      {
        'properties': {
          'name': {'required': true},
        },
      },
      <String, Object?>{},
      'required',
      {'property': 'name'},
      'Property "name" is required',
      draft: SchemaDraft.draft3,
    ),
    'disallow type': const _FailureCase(
      {'disallow': 'string'},
      'hello',
      'disallow',
      {
        'disallowedTypes': ['string'],
        'actualType': 'string',
      },
      'must not have type string',
      draft: SchemaDraft.draft3,
    ),
    'disallow schema': const _FailureCase(
      {
        'disallow': [
          {'type': 'string'},
        ],
      },
      'hello',
      'disallow',
      {'schemaIndex': 0, 'actualType': 'string'},
      'must not match disallowed schema 0',
      draft: SchemaDraft.draft3,
    ),
    'historical schema type alternatives': const _FailureCase(
      {
        'type': [
          'string',
          {'minimum': 3, 'type': 'integer'},
        ],
      },
      false,
      'type',
      {
        'expectedTypes': ['string'],
        'schemaAlternatives': 1,
        'actualType': 'boolean',
      },
      'string or a value matching one of 1 alternative schemas',
      draft: SchemaDraft.draft3,
    ),
  };

  test(
    'the public code registry covers the implemented diagnostic families',
    () {
      final covered = cases.values.map((fixture) => fixture.code).toSet()
        ..add(ValidationErrorCodes.custom);
      expect(ValidationErrorCodes.byKeyword.values.toSet(), covered);
      expect(
        ValidationErrorCodes.forKeyword('enum'),
        ValidationErrorCodes.enumValue,
      );
      expect(
        ValidationErrorCodes.forKeyword('const'),
        ValidationErrorCodes.constant,
      );
      expect(
        ValidationErrorCodes.forKeyword('false'),
        ValidationErrorCodes.falseSchema,
      );
      expect(
        ValidationErrorCodes.forKeyword('applicationAssertion'),
        'applicationAssertion',
      );
      expect(
        () =>
            ValidationErrorCodes.byKeyword['applicationAssertion'] = 'changed',
        throwsUnsupportedError,
      );
    },
  );

  for (final entry in cases.entries) {
    test('reports specific ${entry.key} diagnostics through open catalogs', () {
      final fixture = entry.value;
      final validator = JsonSchema.fromJson(
        fixture.document,
        draft: fixture.draft,
      ).compile(options: fixture.options);
      expect(validator.isValid(fixture.instance), isFalse);
      final first = validator.validate(fixture.instance)!;
      final all = validator.errors(fixture.instance);
      expect(first.code, fixture.code);
      expect(first.toJson(), all.first.toJson());
      for (final parameter in fixture.parameters.entries) {
        expect(first.parameters[parameter.key], parameter.value);
      }
      expect(first.message, contains(fixture.messagePart));
      expect(first.message, isNot(contains('The instance fails')));
      final localized = first.formatMessage(
        const _ApplicationMessages().format,
      );
      expect(localized, isNot(first.message));
      expect(localized, contains('Application rule ${first.code}'));
      expect(
        first.formatMessage(const ValidationMessages.english().format),
        first.message,
      );
      expect(() => first.parameters['changed'] = true, throwsUnsupportedError);
    });
  }

  test('property-name diagnostics identify the name and its exact failure', () {
    final error = JsonSchema.fromJson({
      'propertyNames': {'minLength': 3},
    }).compile().validate({'a': true})!;
    expect(error.code, 'minLength');
    expect(error.parameters, {'limit': 3, 'length': 1, 'propertyName': 'a'});
    expect(
      error.message,
      startsWith('Property name "a": Text must contain at least 3'),
    );
    expect(error.schemaPath, '/propertyNames/minLength');
    expect(error.instancePath, '/a');
  });

  test(
    'contains diagnostics do not claim short-circuited counts are exact',
    () {
      final error = JsonSchema.fromJson({
        'contains': <String, Object?>{},
        'minContains': 10,
        'maxContains': 1,
      }).compile().validate(List.generate(12, (index) => index))!;
      expect(error.parameters['reason'], 'tooMany');
      expect(error.parameters['matches'], 2);
      expect(error.message, contains('at least 2 matched'));
    },
  );

  test('every JSON type has a specific expected-type diagnostic', () {
    for (final type in [
      'null',
      'boolean',
      'object',
      'array',
      'number',
      'integer',
    ]) {
      final error = JsonSchema.fromJson({'type': type})
          .compile()
          .validate('text')!;
      expect(error.parameters['expectedTypes'], [type]);
      expect(error.parameters['actualType'], 'string');
      expect(error.message, 'Expected $type; received string.');
    }
  });

  test(
    'asynchronous compilation keeps the selected message formatter',
    () async {
      final validator =
          await JsonSchema.fromJson({r'$ref': 'https://example.com/remote'})
              .compileAsync(
                options: SchemaOptions(
                  resolver: (_) async => {'minLength': 3},
                  messageFormatter: const _ShortMessages().format,
                ),
              );
      final error = validator.validate('No')!;
      expect(error.message, 'Minimum length: 3');
      expect(
        error.schemaLocation.toString(),
        'https://example.com/remote#/minLength',
      );
    },
  );

  test('diagnostics retain exact numeric limits and frozen schema values', () {
    final large = BigInt.parse('900719925474099312345');
    final decimal = JsonNumber.parse('0.123456789012345678901');
    final original = <String, Object?>{'minimum': large};
    final validator = JsonSchema.fromJson(original).compile();
    original['minimum'] = 0;
    final error = validator.validate(large - BigInt.one)!;
    expect(error.parameters['limit'], large);
    expect(error.message, contains(large.toString()));
    expect(encodeJson(error.toJson()), contains(large.toString()));
    final decimalError = JsonSchema.fromJson({'multipleOf': decimal})
        .compile()
        .validate(1)!;
    expect(decimalError.parameters['divisor'], same(decimal));
    expect(decimalError.message, contains(decimal.toString()));
    final enumError = JsonSchema.fromJson({
      'enum': [
        {'name': 'Original'},
      ],
    }).compile().validate(false)!;
    final options = enumError.parameters['allowedValues']! as List<Object?>;
    expect(() => options.add(false), throwsUnsupportedError);
    expect(
      () => (options.single! as Map<String, Object?>)['name'] = 'Changed',
      throwsUnsupportedError,
    );
  });

  test(
    'formatting is lazy and locale selection reuses the compiled validator',
    () {
      var formats = 0;
      String custom(ValidationError error) {
        formats++;
        return 'Minimum: ${error.parameters['limit']}';
      }

      final validator = JsonSchema.fromJson({'minLength': 3})
          .compile(options: SchemaOptions(messageFormatter: custom));
      expect(validator.isValid('x'), isFalse);
      expect(validator.validate('Long'), isNull);
      final error = validator.validate('x')!;
      final all = validator.errors('x');
      expect(formats, 0);
      expect(error.message, 'Minimum: 3');
      expect(formats, 1);
      final catalog = ValidationMessages.fromTemplates({
        ValidationErrorCodes.minLength: (error) =>
            'Length >= ${error.parameters['limit']}',
      });
      final localized = validator.validate(
        'x',
        messageFormatter: catalog.format,
      )!;
      expect(localized.message, 'Length >= 3');
      expect(localized.parameters, error.parameters);
      expect(localized.schemaLocation, error.schemaLocation);
      expect(
        all.single.formatMessage(const ValidationMessages.english().format),
        const ValidationMessages.english().format(error),
      );
      expect(
        ValidationMessages.fromTemplates({}).format(validator.validate('x')!),
        const ValidationMessages.english().format(error),
      );
      expect(formats, 1);
      expect(
        validator.errors('x', messageFormatter: catalog.format).single.message,
        localized.message,
      );
      expect(localized.toJson()['message'], localized.message);
    },
  );

  test('template catalogs freeze overrides and support custom fallbacks', () {
    final overrides = <String, ValidationErrorFormatter>{
      ValidationErrorCodes.minLength: (error) =>
          'Minimum length: ${error.parameters['limit']}',
    };
    final messages = ValidationMessages.fromTemplates(overrides);
    overrides[ValidationErrorCodes.minLength] = (_) => 'Changed';
    final error = JsonSchema.fromJson({'minLength': 3})
        .compile()
        .validate('No')!;
    expect(messages.format(error), 'Minimum length: 3');
    expect(const _ShortMessages().format(error), messages.format(error));
    final maximum = JsonSchema.fromJson({'maximum': 3}).compile().validate(4)!;
    expect(messages.format(maximum), maximum.message);
    final customFallback = ValidationMessages.fromTemplates(
      const {},
      fallback: const _ApplicationMessages(),
    );
    expect(
      customFallback.format(maximum),
      startsWith('Application rule maximum'),
    );
  });

  test(
    'custom formatters can fall back without recursive message formatting',
    () {
      final validator = JsonSchema.fromJson({'minimum': 2}).compile(
        options: SchemaOptions(
          messageFormatter: (error) => 'Custom: ${error.message}',
        ),
      );
      expect(
        validator.validate(1)!.message,
        'Custom: Number must be at least 2; received 1.',
      );
      final manual = ValidationError(
        keyword: 'extension',
        message: 'Application explanation.',
        instancePath: '',
        schemaPath: '/extension',
        schemaLocation: Uri.parse('https://example.com/schema#/extension'),
      );
      expect(manual.message, 'Application explanation.');
    },
  );

  test('message fallbacks work for validation and presentation overrides', () {
    const explanation = 'Number must be at least 2; received 1.';
    String custom(ValidationError error) => 'Custom: ${error.message}';

    final validator = JsonSchema.fromJson({'minimum': 2})
        .compile(options: SchemaOptions(messageFormatter: custom));
    final error = validator.validate(1)!;
    expect(error.message, 'Custom: $explanation');
    expect(error.formatMessage(), error.message);
    expect(error.formatMessage(custom), error.message);
    expect(error.formatMessage((error) => error.message), explanation);
    expect(error.toJson()['message'], error.message);
    expect(error.toString(), contains(error.message));

    final messages = ValidationMessages.fromTemplates({
      ValidationErrorCodes.minimum: (error) => 'Override: ${error.message}',
    });
    expect(error.formatMessage(messages.format), 'Override: $explanation');
    final first = validator.validate(1, messageFormatter: messages.format)!;
    final all = validator.errors(1, messageFormatter: messages.format).single;
    expect(first.message, 'Override: $explanation');
    expect(all.message, first.message);
    expect(first.parameters, error.parameters);
    expect(first.instancePath, error.instancePath);
    expect(first.schemaPath, error.schemaPath);
    expect(first.schemaLocation, error.schemaLocation);
  });

  test(
    'formatter fallbacks preserve explicit messages and diagnostic data',
    () {
      var formats = 0;
      final location = Uri.parse('https://example.com/schema#/extension');
      String custom(ValidationError error) {
        formats++;
        expect(error.keyword, 'extension');
        expect(error.code, 'applicationRule');
        expect(error.parameters, {'limit': 3});
        expect(error.instancePath, '/name');
        expect(error.schemaPath, '/extension');
        expect(error.schemaLocation, location);
        return 'Custom: ${error.message}';
      }

      final error = ValidationError(
        keyword: 'extension',
        code: 'applicationRule',
        parameters: const {'limit': 3},
        message: 'Application explanation.',
        messageFormatter: custom,
        instancePath: '/name',
        schemaPath: '/extension',
        schemaLocation: location,
      );
      expect(formats, 0);
      expect(error.message, 'Custom: Application explanation.');
      expect(formats, 1);
      expect(error.formatMessage(custom), 'Custom: Application explanation.');
      expect(formats, 2);
      expect(
        error.formatMessage((error) => error.message),
        'Application explanation.',
      );
      expect(formats, 2);
    },
  );

  test('custom assertion diagnostics carry the immutable constraint', () {
    final error =
        JsonSchema.fromJson({
              'applicationLimit': {'limit': 3},
            })
            .compile(
              options: SchemaOptions(
                keywords: {'applicationLimit': (_, _) => false},
              ),
            )
            .validate({'private': 'not embedded'})!;
    expect(error.keyword, 'applicationLimit');
    expect(error.code, 'custom');
    expect(error.parameters, {
      'constraint': {'limit': 3},
    });
    expect(
      error.message,
      contains('"applicationLimit" with constraint {"limit":3}'),
    );
    expect(encodeJson(error.toJson()), isNot(contains('private')));
  });

  test(
    'references and applicator branches preserve specific child diagnostics',
    () {
      final cases = <String, Object>{
        'allOf': {
          'allOf': [
            {'minLength': 3},
          ],
        },
        'then': {
          'if': {'type': 'string'},
          'then': {'minLength': 3},
        },
        'else': {
          'if': {'type': 'integer'},
          'else': {'minLength': 3},
        },
        'dependentSchemas': {
          'dependentSchemas': {
            'name': {
              'properties': {
                'name': {'minLength': 3},
              },
            },
          },
        },
        'reference': {
          r'$defs': {
            'name': {'minLength': 3},
          },
          r'$ref': r'#/$defs/name',
        },
      };
      for (final entry in cases.entries) {
        final instance = entry.key == 'dependentSchemas'
            ? {'name': 'No'}
            : 'No';
        final validator = JsonSchema.fromJson(entry.value).compile();
        final error = validator.validate(instance)!;
        expect(error.code, 'minLength', reason: entry.key);
        expect(error.parameters, {'limit': 3, 'length': 2});
        expect(
          error.message,
          contains('at least 3 Unicode characters; received 2'),
        );
        expect(validator.isValid(instance), isFalse);
        expect(validator.errors(instance).single.code, error.code);
      }
    },
  );
}
