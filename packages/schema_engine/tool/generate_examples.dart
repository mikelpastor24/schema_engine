import 'dart:io';

import 'package:schema_engine/schema_engine.dart';

/// Generates original sample JSON documents for every published dialect.
void main() {
  final directory = Directory('example/schemas')..createSync(recursive: true);
  for (final draft in SchemaDraft.values) {
    final schema = JsonSchema.build(
      draft: draft,
      type: SchemaType.object,
      title: 'Person',
      description: 'A minimal person record.',
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
    );
    File('${directory.path}/${draft.name}.schema.json')
        .writeAsStringSync('${schema.toJsonString(indent: '  ')}\n');
  }
}
