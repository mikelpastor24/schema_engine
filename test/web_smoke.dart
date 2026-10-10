import 'package:schema_engine/schema_engine.dart';

/// Exercises the portable core after JavaScript compilation.
void main() {
  var checks = 0;
  void check(bool condition) {
    if (!condition) {
      throw StateError('Portable core check $checks failed.');
    }
    checks++;
  }

  for (final draft in SchemaDraft.values) {
    final schema = JsonSchema.build(
      draft: draft,
      type: SchemaType.object,
      properties: {
        'name': JsonSchema.build(draft: draft, type: SchemaType.string),
      },
      required: ['name'],
    );
    final parsed = JsonSchema.parse(schema.toJsonString());
    final validator = parsed.compile();
    check(validator.isValid({'name': 'Example'}));
    check(!validator.isValid({}));
    check(validator.validate({'name': false}) != null);
    final metadata = JsonSchema.fromJson({r'$ref': draft.metaSchemaUri})
        .compile();
    check(metadata.isValid({'type': 'string', 'minLength': 1}));
    check(
      !metadata.isValid({
        'properties': {
          'name': {'type': 1},
        },
      }),
    );
  }
  final decimal = JsonSchema.fromJson({'multipleOf': 0.1}).compile();
  check(decimal.isValid(0.3));
  check(!decimal.isValid(0.30000000000000004));
  final large = JsonSchema.parse(
    '{"type":"integer","minimum":9007199254740993}',
  ).compile();
  check(large.isValid(decodeJson('9007199254740993')));
  check(!large.isValid(decodeJson('9007199254740992')));
  final legacyInteger = JsonSchema.build(
    draft: SchemaDraft.draft4,
    type: SchemaType.integer,
  ).compile();
  check(legacyInteger.isValid(decodeJson('1')));
  check(!legacyInteger.isValid(decodeJson('1.0')));
  check(!legacyInteger.isValid(decodeJson('1e0')));
  check(legacyInteger.isValid(decodeJson('999999999999999999999')));
  final exactUnique = JsonSchema.fromJson({'uniqueItems': true}).compile();
  check(!exactUnique.isValid([1, BigInt.one]));
  check(
    !exactUnique.isValid([
      BigInt.parse('9007199254740993'),
      JsonNumber.parse('9007199254740993.0'),
    ]),
  );
  final exactRoundTrip = decodeJson(encodeJson(JsonNumber.parse('100')));
  check(legacyInteger.isValid(exactRoundTrip));
  final international = JsonSchema.fromJson({'format': 'idn-hostname'})
      .compile(options: SchemaOptions(assertFormats: true));
  check(international.isValid('münchen.example'));
  check(!international.isValid('bad_host.example'));
  final ipv4 = JsonSchema.fromJson({'format': 'ipv4'})
      .compile(options: SchemaOptions(assertFormats: true));
  check(ipv4.isValid('0.0.0.0'));
  check(ipv4.isValid('255.255.255.255'));
  check(!ipv4.isValid('01.2.3.4'));
  check(!ipv4.isValid('256.2.3.4'));
  check(!ipv4.isValid('1.2.3.4.5'));
  final metaUri = Uri.parse('https://example.com/strict-format');
  final strict =
      JsonSchema.fromJson({
        r'$schema': metaUri.toString(),
        'format': 'email',
      }, draft: SchemaDraft.draft202012).compile(
        options: SchemaOptions(
          resources: {
            metaUri: {
              r'$schema': SchemaDraft.draft202012.metaSchemaUri,
              r'$vocabulary': {
                'https://json-schema.org/draft/2020-12/vocab/core': true,
                'https://json-schema.org/draft/2020-12/vocab/format-assertion':
                    false,
              },
            },
          },
        ),
      );
  check(strict.isValid('user@example.com'));
  check(!strict.isValid('invalid'));
  print('$checks portable core checks passed.');
}
