part of 'validator.dart';

const _vocabularyKeywords = <String, Set<String>>{
  'validation': {
    'type',
    'enum',
    'const',
    'multipleOf',
    'minimum',
    'maximum',
    'exclusiveMinimum',
    'exclusiveMaximum',
    'minLength',
    'maxLength',
    'pattern',
    'minItems',
    'maxItems',
    'uniqueItems',
    'minContains',
    'maxContains',
    'minProperties',
    'maxProperties',
    'required',
    'dependentRequired',
  },
  'applicator': {
    'properties',
    'patternProperties',
    'additionalProperties',
    'propertyNames',
    'items',
    'additionalItems',
    'prefixItems',
    'contains',
    'allOf',
    'anyOf',
    'oneOf',
    'not',
    'if',
    'then',
    'else',
    'dependentSchemas',
  },
  'unevaluated': {'unevaluatedProperties', 'unevaluatedItems'},
  'format': {'format'},
  'content': {'contentEncoding', 'contentMediaType', 'contentSchema'},
  'meta-data': {
    'title',
    'description',
    'default',
    'examples',
    'deprecated',
    'readOnly',
    'writeOnly',
  },
};

Map<String, Object?> _semanticMap(
  Map<String, Object?> value,
  _Resource resource,
) {
  final vocabulary = resource.vocabulary;
  if (vocabulary == null || !resource.draft.supportsVocabularies) {
    return value;
  }
  final prefix = resource.draft == SchemaDraft.draft202012
      ? 'https://json-schema.org/draft/2020-12/vocab/'
      : 'https://json-schema.org/draft/2019-09/vocab/';
  final filtered = Map<String, Object?>.of(value);
  for (final category in _vocabularyKeywords.entries) {
    final available = switch (category.key) {
      'format' =>
        vocabulary.containsKey('${prefix}format') ||
            vocabulary.containsKey('${prefix}format-annotation') ||
            vocabulary.containsKey('${prefix}format-assertion'),
      'unevaluated' =>
        vocabulary.containsKey('${prefix}unevaluated') ||
            resource.draft == SchemaDraft.draft201909 &&
                vocabulary.containsKey('${prefix}applicator'),
      _ => vocabulary.containsKey('$prefix${category.key}'),
    };
    if (!available) {
      for (final keyword in category.value) {
        filtered.remove(keyword);
      }
    }
  }
  return filtered;
}
