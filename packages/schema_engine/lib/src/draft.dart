/// Published JSON Schema dialects, including the historical specifications.
///
/// Draft 05 uses the Draft 04 meta-schema and is represented by [draft4].
enum SchemaDraft {
  /// The original December 2009 specification.
  draft0('http://json-schema.org/draft-00/schema#'),

  /// The corrected December 2009 specification.
  draft1('http://json-schema.org/draft-01/schema#'),

  /// The March 2010 specification.
  draft2('http://json-schema.org/draft-02/schema#'),

  /// The November 2010 specification.
  draft3('http://json-schema.org/draft-03/schema#'),

  /// The January 2013 dialect, also used by Draft 05.
  draft4('http://json-schema.org/draft-04/schema#'),

  /// The April 2017 dialect.
  draft6('http://json-schema.org/draft-06/schema#'),

  /// The March 2018 dialect.
  draft7('http://json-schema.org/draft-07/schema#'),

  /// The September 2019 dialect.
  draft201909('https://json-schema.org/draft/2019-09/schema'),

  /// The December 2020 dialect, including its published corrections.
  draft202012('https://json-schema.org/draft/2020-12/schema');

  const SchemaDraft(this.metaSchemaUri);

  /// The canonical meta-schema identifier for this dialect.
  final String metaSchemaUri;

  /// Whether schemas may be boolean values.
  bool get supportsBooleanSchemas => index >= draft6.index;

  /// Whether the historical type, optional, and extends rules apply.
  bool get isLegacy => index <= draft3.index;

  /// Whether vocabularies and unevaluated applicators are available.
  bool get supportsVocabularies => index >= draft201909.index;

  /// Parses a meta-schema URI, accepting HTTP/HTTPS and empty fragments.
  ///
  /// Throws [FormatException] for unknown dialects rather than guessing.
  static SchemaDraft fromUri(String identifier) {
    final uri = Uri.parse(identifier);
    if (uri.host != 'json-schema.org' ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.hasQuery ||
        uri.fragment.isNotEmpty) {
      throw FormatException('Unsupported schema dialect: $identifier');
    }
    for (final draft in values) {
      if (uri.path == Uri.parse(draft.metaSchemaUri).path ||
          uri.path ==
              Uri.parse(draft.metaSchemaUri).path
                  .replaceFirst('/schema', '/hyper-schema')) {
        return draft;
      }
    }
    throw FormatException('Unsupported schema dialect: $identifier');
  }
}

/// JSON primitive types understood by schemas.
enum SchemaType {
  /// A JSON null value.
  nullValue('null'),

  /// A JSON boolean.
  boolean('boolean'),

  /// A JSON object with string keys.
  object('object'),

  /// A JSON array.
  array('array'),

  /// A JSON number, including integers.
  number('number'),

  /// A JSON number without a fractional part.
  integer('integer'),

  /// A JSON string.
  string('string');

  const SchemaType(this.jsonName);

  /// The spelling used in JSON Schema documents.
  final String jsonName;
}
