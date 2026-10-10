part of 'validator.dart';

// These constraints are authored from the keyword grammars. They are not copies
// of third-party meta-schema documents. Historical grammars use the latest
// applicators; modern grammars retain their extensible reference semantics.
Map<String, Object?>? _builtInMetaSchema(Uri uri) {
  if (uri.host != 'json-schema.org' ||
      uri.hasQuery ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  try {
    return _metaSchema(SchemaDraft.fromUri(uri.toString()));
  } on FormatException {
    // Vocabulary meta-schemas are resources, rather than complete dialects.
  }
  for (final draft in [SchemaDraft.draft201909, SchemaDraft.draft202012]) {
    final prefix = Uri.parse(draft.metaSchemaUri).path
        .replaceFirst('/schema', '/meta/');
    if (!uri.path.startsWith(prefix)) {
      continue;
    }
    final category = uri.path.substring(prefix.length);
    final modern = draft == SchemaDraft.draft202012;
    final valid = {
      'core',
      'applicator',
      'validation',
      'meta-data',
      'content',
      if (modern) ...[
        'unevaluated',
        'format-annotation',
        'format-assertion',
      ] else
        'format',
    };
    if (!valid.contains(category)) {
      return null;
    }
    final metadata = _metaSchema(draft);
    final properties = metadata['properties']! as Map<String, Object?>;
    final keywords = category == 'core'
        ? properties.keys.where((name) => name.startsWith(r'$')).toSet()
        : {
            ...?_vocabularyKeywords[category.startsWith('format-')
                ? 'format'
                : category],
            if (!modern && category == 'applicator')
              ..._vocabularyKeywords['unevaluated']!,
          };
    metadata['properties'] = {
      for (final keyword in keywords)
        if (properties.containsKey(keyword)) keyword: properties[keyword],
    };
    return metadata;
  }
  return null;
}

Map<String, Object?> _metaSchema(SchemaDraft draft) {
  final ref = <String, Object?>{
    if (draft == SchemaDraft.draft202012)
      r'$dynamicRef': '#meta'
    else if (draft == SchemaDraft.draft201909)
      r'$recursiveRef': '#'
    else
      r'$ref': '#',
  };
  final schema = draft.supportsBooleanSchemas
      ? ref
      : <String, Object?>{
          'allOf': [
            ref,
            {'type': 'object'},
          ],
        };
  final schemaOrBoolean = <String, Object?>{
    'anyOf': [
      ref,
      {'type': 'boolean'},
    ],
  };
  final schemaMap = <String, Object?>{
    'type': 'object',
    'additionalProperties': schema,
  };
  final schemaArray = <String, Object?>{
    'type': 'array',
    if (!draft.isLegacy) 'minItems': 1,
    'items': schema,
  };
  final stringArray = <String, Object?>{
    'type': 'array',
    'items': {'type': 'string'},
    'uniqueItems': true,
  };
  final nonNegative = <String, Object?>{'type': 'integer', 'minimum': 0};
  final anchor = <String, Object?>{
    'type': 'string',
    'pattern': draft == SchemaDraft.draft202012
        ? r'^[A-Za-z_][A-Za-z0-9._-]*$'
        : r'^[A-Za-z][A-Za-z0-9._:-]*$',
  };
  final properties = <String, Object?>{
    r'$schema': {'type': 'string', 'format': 'uri'},
    r'$ref': {'type': 'string', 'format': 'uri-reference'},
    draft.index < SchemaDraft.draft6.index ? 'id' : r'$id': {'type': 'string'},
    'title': {'type': 'string'},
    'description': {'type': 'string'},
    'type': {
      'anyOf': [
        draft.isLegacy
            ? {'type': 'string'}
            : {
                'enum': [
                  ...SchemaType.values.map((type) => type.jsonName),
                  if (draft.isLegacy) 'any',
                ],
              },
        {
          'type': 'array',
          if (!draft.isLegacy) 'minItems': 1,
          'uniqueItems': true,
          'items': draft.isLegacy
              ? {
                  'anyOf': [
                    schema,
                    {'type': 'string'},
                  ],
                }
              : {
                  'enum': SchemaType.values
                      .map((type) => type.jsonName)
                      .toList(),
                },
        },
      ],
    },
    'properties': schemaMap,
    'additionalProperties': schemaOrBoolean,
    'items': draft == SchemaDraft.draft202012
        ? schema
        : {
            'anyOf': [schema, schemaArray],
          },
    'minimum': {'type': 'number'},
    'maximum': {'type': 'number'},
    'minLength': nonNegative,
    'maxLength': nonNegative,
    'minItems': nonNegative,
    'maxItems': nonNegative,
    'pattern': {'type': 'string', 'format': 'regex'},
    'format': {'type': 'string'},
    'enum': {
      'type': 'array',
      if (!draft.supportsVocabularies) ...{'minItems': 1, 'uniqueItems': true},
    },
  };
  if (draft.index < SchemaDraft.draft3.index) {
    for (final keyword in ['optional', 'minimumCanEqual', 'maximumCanEqual']) {
      properties[keyword] = {'type': 'boolean'};
    }
    properties['requires'] = {
      'anyOf': [
        {'type': 'string'},
        schema,
      ],
    };
    if (draft.index < SchemaDraft.draft2.index) {
      properties['maxDecimal'] = nonNegative;
    }
  }
  if (draft.isLegacy) {
    properties['extends'] = {
      'anyOf': [schema, schemaArray],
    };
    properties['disallow'] = properties['type'];
  }
  if (draft.index >= SchemaDraft.draft2.index) {
    properties[draft.isLegacy ? 'divisibleBy' : 'multipleOf'] = {
      'type': 'number',
      'exclusiveMinimum': 0,
    };
    properties['uniqueItems'] = {'type': 'boolean'};
  }
  if (draft.index >= SchemaDraft.draft3.index) {
    properties['patternProperties'] = schemaMap;
    properties['additionalItems'] = schemaOrBoolean;
    properties['required'] = draft == SchemaDraft.draft3
        ? {'type': 'boolean'}
        : {...stringArray, if (draft == SchemaDraft.draft4) 'minItems': 1};
    properties['exclusiveMinimum'] = {
      'type': draft.index < SchemaDraft.draft6.index ? 'boolean' : 'number',
    };
    properties['exclusiveMaximum'] = properties['exclusiveMinimum'];
  }
  if (!draft.isLegacy) {
    properties['definitions'] = schemaMap;
    properties['minProperties'] = nonNegative;
    properties['maxProperties'] = nonNegative;
    for (final keyword in ['allOf', 'anyOf', 'oneOf']) {
      properties[keyword] = schemaArray;
    }
    properties['not'] = schema;
  }
  if (draft.index >= SchemaDraft.draft6.index) {
    properties['const'] = <String, Object?>{};
    properties['examples'] = {'type': 'array'};
    properties['contains'] = schema;
    properties['propertyNames'] = schema;
  }
  if (draft.index >= SchemaDraft.draft7.index) {
    properties[r'$comment'] = {'type': 'string'};
    properties['contentEncoding'] = {'type': 'string'};
    properties['contentMediaType'] = {'type': 'string'};
    for (final keyword in ['if', 'then', 'else']) {
      properties[keyword] = schema;
    }
    for (final keyword in ['readOnly', 'writeOnly']) {
      properties[keyword] = {'type': 'boolean'};
    }
  }
  if (draft.supportsVocabularies) {
    properties['deprecated'] = {'type': 'boolean'};
    properties[r'$defs'] = schemaMap;
    properties['dependentSchemas'] = schemaMap;
    properties['dependentRequired'] = {
      'type': 'object',
      'additionalProperties': stringArray,
    };
    for (final keyword in [
      'unevaluatedProperties',
      'unevaluatedItems',
      'contentSchema',
    ]) {
      properties[keyword] = schema;
    }
    properties['minContains'] = nonNegative;
    properties['maxContains'] = nonNegative;
    properties[r'$anchor'] = anchor;
    properties[r'$vocabulary'] = {
      'type': 'object',
      'additionalProperties': {'type': 'boolean'},
    };
  } else if (draft.index >= SchemaDraft.draft3.index) {
    properties['dependencies'] = {
      'type': 'object',
      'additionalProperties': {
        'anyOf': [
          schema,
          {
            ...stringArray,
            if (draft == SchemaDraft.draft3) 'uniqueItems': false,
            if (draft == SchemaDraft.draft4) 'minItems': 1,
          },
          if (draft == SchemaDraft.draft3) {'type': 'string'},
        ],
      },
    };
  }
  if (draft == SchemaDraft.draft202012) {
    properties['prefixItems'] = schemaArray;
    properties.remove('additionalItems');
    properties[r'$dynamicAnchor'] = anchor;
    properties[r'$dynamicRef'] = {'type': 'string', 'format': 'uri-reference'};
  } else if (draft == SchemaDraft.draft201909) {
    properties[r'$recursiveAnchor'] = {'type': 'boolean'};
    properties[r'$recursiveRef'] = {
      'type': 'string',
      'format': 'uri-reference',
    };
  }
  return {
    r'$schema': (draft.supportsVocabularies ? draft : SchemaDraft.draft202012)
        .metaSchemaUri,
    if (draft == SchemaDraft.draft202012) r'$dynamicAnchor': 'meta',
    if (draft == SchemaDraft.draft201909) r'$recursiveAnchor': true,
    'type': draft.supportsBooleanSchemas ? ['object', 'boolean'] : 'object',
    'properties': properties,
    draft.supportsVocabularies ? r'$defs' : 'definitions': {
      'schemaArray': schemaArray,
      'nonNegativeInteger': nonNegative,
      'nonNegativeIntegerDefault0': {...nonNegative, 'default': 0},
      'simpleTypes': {
        'enum': SchemaType.values.map((type) => type.jsonName).toList(),
      },
      'stringArray': stringArray,
      if (draft.supportsVocabularies) ...{
        'anchorString': anchor,
        'uriString': {'type': 'string', 'format': 'uri'},
        'uriReferenceString': {'type': 'string', 'format': 'uri-reference'},
      },
    },
    if (draft == SchemaDraft.draft3 || draft == SchemaDraft.draft4)
      'dependentRequired': {
        'exclusiveMinimum': ['minimum'],
        'exclusiveMaximum': ['maximum'],
      },
  };
}
