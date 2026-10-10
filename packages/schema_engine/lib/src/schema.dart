import 'draft.dart';
import 'errors.dart';
import 'json.dart';
import 'json_codec.dart';
import 'options.dart';
import 'validator.dart';

const _absent = Object();

/// An immutable JSON Schema document with a selected dialect.
///
/// Parse JSON text with [JsonSchema.parse], use [JsonSchema.fromJson] for decoded
/// values, or construct a document with [JsonSchema.build]. Compile once with
/// [compile] and reuse the resulting validator for many instances.
final class JsonSchema {
  JsonSchema._(this.value, this.draft);

  /// Creates a schema that accepts every JSON instance in [draft].
  factory JsonSchema.any({SchemaDraft draft = SchemaDraft.draft202012}) =>
      JsonSchema.fromJson(
        draft.supportsBooleanSchemas
            ? true
            : <String, Object?>{r'$schema': draft.metaSchemaUri},
        draft: draft,
      );

  /// Creates a schema that rejects every JSON instance in [draft].
  factory JsonSchema.never({SchemaDraft draft = SchemaDraft.draft202012}) =>
      JsonSchema.fromJson(
        draft.supportsBooleanSchemas
            ? false
            : <String, Object?>{
                r'$schema': draft.metaSchemaUri,
                if (draft.isLegacy)
                  'type': <Object?>[]
                else
                  'not': <String, Object?>{},
              },
        draft: draft,
      );

  /// Copies and freezes a decoded schema, preserving extension keywords.
  ///
  /// [draft] overrides the root declaration. Without either, Draft 2020-12 is
  /// used. Throws [SchemaException] for non-schema values and [FormatException]
  /// for unknown dialects. Keyword syntax is checked during compilation.
  factory JsonSchema.fromJson(Object? value, {SchemaDraft? draft}) {
    final frozen = freezeJson(value);
    if (frozen is! Map<String, Object?> && frozen is! bool) {
      throw const SchemaException('A schema must be an object or boolean.');
    }
    final declared = frozen is Map<String, Object?> ? frozen[r'$schema'] : null;
    if (declared != null && declared is! String) {
      throw const SchemaException(r'$schema must be a URI string.');
    }
    final selected =
        draft ??
        (declared is String
            ? SchemaDraft.fromUri(declared)
            : SchemaDraft.draft202012);
    if (frozen is bool && !selected.supportsBooleanSchemas) {
      throw SchemaException(
        'Boolean schemas are not allowed in ${selected.name}.',
      );
    }
    return JsonSchema._(frozen!, selected);
  }

  /// Parses a JSON schema document, forwarding [draft] to [JsonSchema.fromJson].
  ///
  /// Throws [FormatException] for malformed JSON or unknown dialects.
  factory JsonSchema.parse(String source, {SchemaDraft? draft}) =>
      JsonSchema.fromJson(decodeJson(source), draft: draft);

  /// Builds a schema with typed options and dialect-aware keyword spellings.
  ///
  /// Use [keywords] for annotations, uncommon keywords, or extensions. Typed
  /// arguments override entries in [keywords]. Unsupported typed arguments
  /// throw [SchemaException]. Use [constValue] to assert any JSON value,
  /// including null. A default value belongs in `keywords['default']`.
  /// Embedding a different dialect involving 2019-09 or 2020-12 requires that
  /// child schema to have an explicit resource identifier.
  factory JsonSchema.build({
    SchemaDraft draft = SchemaDraft.draft202012,
    SchemaType? type,
    List<SchemaType>? types,
    String? id,
    String? reference,
    String? title,
    String? description,
    Map<String, JsonSchema>? properties,
    List<String>? required,
    Map<String, JsonSchema>? patternProperties,
    JsonSchema? additionalProperties,
    JsonSchema? propertyNames,
    Map<String, JsonSchema>? definitions,
    JsonSchema? items,
    List<JsonSchema>? prefixItems,
    JsonSchema? additionalItems,
    JsonSchema? contains,
    int? minContains,
    int? maxContains,
    int? minItems,
    int? maxItems,
    bool? uniqueItems,
    int? minProperties,
    int? maxProperties,
    num? minimum,
    num? maximum,
    num? exclusiveMinimum,
    num? exclusiveMaximum,
    num? multipleOf,
    int? minLength,
    int? maxLength,
    String? pattern,
    String? format,
    List<Object?>? enumValues,
    Object? constValue = _absent,
    List<JsonSchema>? allOf,
    List<JsonSchema>? anyOf,
    List<JsonSchema>? oneOf,
    JsonSchema? not,
    JsonSchema? ifSchema,
    JsonSchema? thenSchema,
    JsonSchema? elseSchema,
    JsonSchema? unevaluatedProperties,
    JsonSchema? unevaluatedItems,
    Map<String, List<String>>? dependentRequired,
    Map<String, JsonSchema>? dependentSchemas,
    Map<String, Object?> keywords = const {},
  }) {
    if (type != null && types != null) {
      throw const SchemaException('Specify type or types, not both.');
    }
    void needs(bool supported, String keyword) {
      if (!supported) {
        throw SchemaException('$keyword is unavailable in ${draft.name}.');
      }
    }

    final json = <String, Object?>{
      ...keywords,
      r'$schema': draft.metaSchemaUri,
    };
    void put(String keyword, Object? value) {
      if (value != null) {
        json[keyword] = value;
      }
    }

    Map<String, Object?> encodeSchemas(Map<String, JsonSchema> schemas) =>
        schemas.map((name, schema) => MapEntry(name, schema._embedded(draft)));
    List<Object?> encodeList(List<JsonSchema> schemas) =>
        schemas.map((schema) => schema._embedded(draft)).toList();
    put('type', type?.jsonName ?? types?.map((t) => t.jsonName).toList());
    put(draft.index < SchemaDraft.draft6.index ? 'id' : r'$id', id);
    put(r'$ref', reference);
    put('title', title);
    put('description', description);
    put('properties', properties == null ? null : encodeSchemas(properties));
    if (required != null) {
      if (draft.isLegacy) {
        final props = json['properties'] as Map<String, Object?>? ?? {};
        for (final name in {...props.keys, ...required}) {
          final child = Map<String, Object?>.of(
            props[name] as Map<String, Object?>? ?? {},
          );
          child[draft == SchemaDraft.draft3
              ? 'required'
              : 'optional'] = draft == SchemaDraft.draft3
              ? required.contains(name)
              : !required.contains(name);
          props[name] = child;
        }
        json['properties'] = props;
      } else {
        json['required'] = required;
      }
    } else if (properties != null && draft.index < SchemaDraft.draft3.index) {
      // The builder's properties are optional unless explicitly required.
      final props = json['properties']! as Map<String, Object?>;
      for (final name in props.keys.toList()) {
        props[name] = {
          ...props[name]! as Map<String, Object?>,
          'optional': true,
        };
      }
    }
    if (patternProperties != null) {
      needs(draft.index >= SchemaDraft.draft3.index, 'patternProperties');
      put('patternProperties', encodeSchemas(patternProperties));
    }
    put('additionalProperties', additionalProperties?._embedded(draft));
    if (propertyNames != null) {
      needs(draft.index >= SchemaDraft.draft6.index, 'propertyNames');
      put('propertyNames', propertyNames._embedded(draft));
    }
    if (definitions != null) {
      put(
        draft.supportsVocabularies ? r'$defs' : 'definitions',
        encodeSchemas(definitions),
      );
    }
    if (prefixItems != null) {
      put(
        draft == SchemaDraft.draft202012 ? 'prefixItems' : 'items',
        encodeList(prefixItems),
      );
    }
    if (items != null) {
      final keyword = prefixItems != null && draft != SchemaDraft.draft202012
          ? (draft.index < SchemaDraft.draft3.index
                ? 'additionalProperties'
                : 'additionalItems')
          : 'items';
      put(keyword, items._embedded(draft));
    }
    if (additionalItems != null) {
      needs(draft != SchemaDraft.draft202012, 'additionalItems');
      put(
        draft.index < SchemaDraft.draft3.index
            ? 'additionalProperties'
            : 'additionalItems',
        additionalItems._embedded(draft),
      );
    }
    if (contains != null) {
      needs(draft.index >= SchemaDraft.draft6.index, 'contains');
      put('contains', contains._embedded(draft));
    }
    if (minContains != null || maxContains != null) {
      needs(draft.supportsVocabularies, 'minContains/maxContains');
      put('minContains', minContains);
      put('maxContains', maxContains);
    }
    put('minItems', minItems);
    put('maxItems', maxItems);
    if (uniqueItems != null) {
      needs(draft.index >= SchemaDraft.draft2.index, 'uniqueItems');
      put('uniqueItems', uniqueItems);
    }
    if (minProperties != null || maxProperties != null) {
      needs(!draft.isLegacy, 'minProperties/maxProperties');
      put('minProperties', minProperties);
      put('maxProperties', maxProperties);
    }
    put('minimum', minimum);
    put('maximum', maximum);
    for (final entry in {
      'exclusiveMinimum': exclusiveMinimum,
      'exclusiveMaximum': exclusiveMaximum,
    }.entries) {
      if (entry.value == null) {
        continue;
      }
      if (draft.index >= SchemaDraft.draft6.index) {
        put(entry.key, entry.value);
      } else {
        final lower = entry.key == 'exclusiveMinimum';
        final inclusive = lower ? minimum : maximum;
        final exclusive =
            inclusive == null ||
            (lower ? entry.value! >= inclusive : entry.value! <= inclusive);
        put(lower ? 'minimum' : 'maximum', exclusive ? entry.value : inclusive);
        put(
          draft.index < SchemaDraft.draft3.index
              ? (lower ? 'minimumCanEqual' : 'maximumCanEqual')
              : entry.key,
          draft.index >= SchemaDraft.draft3.index ? exclusive : !exclusive,
        );
      }
    }
    if (multipleOf != null) {
      needs(draft.index >= SchemaDraft.draft2.index, 'multipleOf');
      put(draft.isLegacy ? 'divisibleBy' : 'multipleOf', multipleOf);
    }
    put('minLength', minLength);
    put('maxLength', maxLength);
    put('pattern', pattern);
    put('format', format);
    put('enum', enumValues);
    if (!identical(constValue, _absent)) {
      needs(draft.index >= SchemaDraft.draft6.index, 'const');
      json['const'] = constValue;
    }
    if (allOf != null) {
      put(draft.isLegacy ? 'extends' : 'allOf', encodeList(allOf));
    }
    if (anyOf != null || oneOf != null || not != null) {
      needs(!draft.isLegacy, 'anyOf/oneOf/not');
      put('anyOf', anyOf == null ? null : encodeList(anyOf));
      put('oneOf', oneOf == null ? null : encodeList(oneOf));
      put('not', not?._embedded(draft));
    }
    if (ifSchema != null || thenSchema != null || elseSchema != null) {
      needs(draft.index >= SchemaDraft.draft7.index, 'if/then/else');
      put('if', ifSchema?._embedded(draft));
      put('then', thenSchema?._embedded(draft));
      put('else', elseSchema?._embedded(draft));
    }
    if (unevaluatedProperties != null || unevaluatedItems != null) {
      needs(
        draft.supportsVocabularies,
        'unevaluatedProperties/unevaluatedItems',
      );
      put('unevaluatedProperties', unevaluatedProperties?._embedded(draft));
      put('unevaluatedItems', unevaluatedItems?._embedded(draft));
    }
    if (dependentRequired != null || dependentSchemas != null) {
      if (draft.supportsVocabularies) {
        put('dependentRequired', dependentRequired);
        put(
          'dependentSchemas',
          dependentSchemas == null ? null : encodeSchemas(dependentSchemas),
        );
      } else {
        needs(draft.index >= SchemaDraft.draft3.index, 'dependencies');
        put('dependencies', <String, Object?>{
          ...?dependentRequired,
          if (dependentSchemas != null) ...encodeSchemas(dependentSchemas),
        });
      }
    }
    return JsonSchema.fromJson(json, draft: draft);
  }

  /// The frozen object or boolean schema representation.
  final Object value;

  /// The selected root dialect.
  final SchemaDraft draft;

  Object _embedded(SchemaDraft parent) {
    if (value is bool) {
      return value;
    }
    if (draft != parent) {
      final identifier =
          (value as Map<String, Object?>)[draft.index < SchemaDraft.draft6.index
              ? 'id'
              : r'$id'];
      if ((draft.supportsVocabularies || parent.supportsVocabularies) &&
          identifier is! String) {
        throw const SchemaException(
          'Embedding a different dialect requires '
          'an explicit resource identifier.',
        );
      }
      return value;
    }
    return Map<String, Object?>.of(value as Map<String, Object?>)
      ..remove(r'$schema');
  }

  /// Returns immutable JSON values, including exact numeric representations.
  ///
  /// Use [encodeJson] when the document contains BigInt or exact decimals.
  Object toJson() => value;

  /// Serializes this schema, optionally using [indent] for readable output.
  String toJsonString({String? indent}) => encodeJson(value, indent: indent);

  /// Compiles an offline reusable validator.
  ///
  /// Throws [SchemaException] for invalid keyword syntax and [ReferenceException]
  /// for references absent from the resource registry.
  CompiledSchema compile({SchemaOptions? options, Uri? baseUri}) =>
      CompiledSchema.compile(this, options: options, baseUri: baseUri);

  /// Compiles a validator, loading missing resources through the resolver.
  Future<CompiledSchema> compileAsync({SchemaOptions? options, Uri? baseUri}) =>
      CompiledSchema.compileAsync(this, options: options, baseUri: baseUri);
}
