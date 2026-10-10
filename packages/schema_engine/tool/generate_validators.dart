import 'dart:io';

import 'package:schema_engine/schema_engine.dart';

/// Generates original schema fixtures used to compare both validation backends.
void main() {
  final documents = <String, JsonSchema>{
    'GeneratedDeclarative': object({
      'name': string().min(1),
      'age': integer().nonnegative().optional(),
      'note': string().min(1).nullable(),
    }).toJsonSchema(),
    'GeneratedBigNumber': JsonSchema.parse(
      '{"type":"integer","minimum":9007199254740993}',
    ),
    'GeneratedInteger': JsonSchema.fromJson({
      'type': 'integer',
      'minimum': 0,
      'maximum': 1000,
    }),
    'GeneratedObject': JsonSchema.fromJson({
      'type': 'object',
      'required': ['id', 'name'],
      'properties': {
        'id': {'type': 'integer', 'minimum': 0},
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 64},
        'active': {'type': 'boolean'},
      },
      'additionalProperties': false,
    }),
    'GeneratedArray': JsonSchema.fromJson({
      'type': 'array',
      'minItems': 1,
      'items': {'type': 'integer', 'minimum': 0},
    }),
    'GeneratedConditional': JsonSchema.fromJson({
      'if': {'type': 'string'},
      'then': {'minLength': 2},
      'else': {'type': 'integer', 'minimum': 0},
    }),
    'GeneratedAlternatives': JsonSchema.fromJson({
      'oneOf': [
        {'type': 'string'},
        {'type': 'integer'},
      ],
    }),
    'GeneratedPatterns': JsonSchema.fromJson({
      'patternProperties': {
        r'^x\$': {'type': 'integer'},
      },
      'additionalProperties': false,
      'x-description': r'Text containing $ and quotes " safely.',
    }),
    'GeneratedFallback': JsonSchema.fromJson({'multipleOf': 0.1}),
    'GeneratedEmpty': JsonSchema.fromJson(<String, Object?>{}),
    'GeneratedFalse': JsonSchema.fromJson(false),
    'GeneratedEmptyCollection': JsonSchema.fromJson({
      'oneOf': [
        {'type': 'array', 'minItems': 0, 'maxItems': 0},
        {'type': 'object', 'minProperties': 0, 'maxProperties': 0},
      ],
    }),
    'GeneratedUnicodeString': JsonSchema.fromJson({
      'type': 'string',
      'minLength': 1,
      'maxLength': 1,
    }),
  };
  for (final draft in SchemaDraft.values) {
    documents['Generated${draft.name[0].toUpperCase()}${draft.name.substring(1)}'] =
        JsonSchema.build(
          draft: draft,
          type: SchemaType.object,
          properties: {
            'name': JsonSchema.build(draft: draft, type: SchemaType.string),
          },
          required: ['name'],
        );
  }
  final output = StringBuffer(
    '// Generated test fixtures. Run tool/generate_validators.dart.\n',
  )..writeln("import 'package:schema_engine/schema_engine.dart' as engine;");
  for (final entry in documents.entries) {
    final source = SchemaCodeGenerator(entry.value)
        .generate(className: entry.key);
    output.writeln(source.substring(source.indexOf('/// Validates')));
  }
  File('test/generated_validators.dart').writeAsStringSync(output.toString());
  stdout.writeln('Generated ${documents.length} validators.');
}
