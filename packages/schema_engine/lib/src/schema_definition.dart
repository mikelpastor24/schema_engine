import 'dart:collection';

import 'draft.dart';
import 'errors.dart';
import 'json.dart';
import 'options.dart';
import 'schema.dart';
import 'validator.dart';

/// Defines a JSON string, with optional length, pattern, and format checks.
StringSchema string() => StringSchema._();

/// Defines a finite JSON number.
NumberSchema number() => NumberSchema._();

/// Defines an integer using the selected draft's numeric rules.
NumberSchema integer() => NumberSchema._(integer: true);

/// Defines a JSON boolean.
SchemaDefinition boolean() => const _Primitive(SchemaType.boolean);

/// Defines a JSON null value.
SchemaDefinition nullValue() => const _Primitive(SchemaType.nullValue);

/// Defines a schema accepting every JSON value.
SchemaDefinition any() => const _BooleanDefinition(true);

/// Defines a schema rejecting every JSON value.
SchemaDefinition never() => const _BooleanDefinition(false);

/// Defines an object with required properties and no additional properties.
///
/// Mark individual properties with [SchemaDefinition.optional] to allow their
/// absence. Use [ObjectSchema.passthrough] or [ObjectSchema.catchall] to accept
/// additional properties. No constructor or validator strips input properties.
ObjectSchema object(Map<String, SchemaDefinition> shape) =>
    ObjectSchema._(shape);

/// Defines an object that rejects additional properties.
ObjectSchema strictObject(Map<String, SchemaDefinition> shape) => object(shape);

/// Defines an object that accepts additional properties without constraints.
ObjectSchema looseObject(Map<String, SchemaDefinition> shape) =>
    object(shape).passthrough();

/// Defines an array whose elements conform to [element].
ArraySchema array(SchemaDefinition element) => ArraySchema._(element);

/// Defines a fixed-length tuple with one schema for each position.
///
/// [TupleSchema.rest] allows additional elements of a selected schema. Optional
/// markers affect object properties only; every tuple position is required.
TupleSchema tuple(Iterable<SchemaDefinition> elements) =>
    TupleSchema._(elements);

/// Defines an object whose property values conform to [value].
ObjectSchema record(SchemaDefinition value) => object({}).catchall(value);

/// Defines a schema accepting at least one of [alternatives].
///
/// Throws [ArgumentError] for an empty list. Legacy drafts use schema-valued
/// `type` alternatives; later drafts use `anyOf`.
SchemaDefinition union(Iterable<SchemaDefinition> alternatives) =>
    _Union(alternatives);

/// Defines a schema satisfying both [left] and [right].
///
/// This applies both schemas independently. To combine closed object shapes,
/// use [ObjectSchema.extend] instead of intersecting them.
SchemaDefinition intersection(SchemaDefinition left, SchemaDefinition right) =>
    _Intersection(left, right);

/// Defines a schema accepting exactly one JSON [value].
///
/// Copies mutable values. Draft 06 and later use `const`; older drafts use a
/// single-value `enum`. Exact numeric representations are supported.
SchemaDefinition literal(Object? value) => _Literal(freezeJson(value));

/// Defines a string enumeration from distinct, non-empty [values].
///
/// Throws [ArgumentError] for empty or duplicate alternatives.
SchemaDefinition enumValues(Iterable<String> values) {
  final choices = List<String>.unmodifiable(values);
  if (choices.isEmpty || choices.toSet().length != choices.length) {
    throw ArgumentError.value(
      values,
      'values',
      'Use distinct, non-empty values.',
    );
  }
  return _Enumeration(choices);
}

/// Embeds an existing schema without changing its dialect or keywords.
///
/// Generation must select the document's [JsonSchema.draft]; other targets
/// throw [SchemaException]. This escape hatch supports references and keywords
/// without dedicated declarative constructors.
SchemaDefinition fromSchema(JsonSchema schema) => _Existing(schema);

/// A reusable, immutable declaration that generates a schema for a chosen draft.
///
/// Import the package with a namespace such as `schema` and compose declarations:
///
/// ```dart
/// final user = schema.object({
///   'name': schema.string().min(1),
///   'age': schema.integer().min(0).optional(),
/// });
/// final document = user.toJsonSchema(draft: schema.SchemaDraft.draft7);
/// final validator = document.compile();
/// ```
/// Modifiers create new declarations. Construction and generation do not add
/// work to the compiled validator's instance-validation path.
sealed class SchemaDefinition {
  const SchemaDefinition();

  /// Whether an enclosing object may omit this property.
  ///
  /// This marker has no effect on root values or array elements. Optional does
  /// not imply nullable; JSON has no `undefined` value.
  bool get isOptional => false;

  /// Allows an enclosing object to omit this property.
  SchemaDefinition optional() => _Presence(this, optional: true);

  /// Requires this property in an enclosing object.
  SchemaDefinition nonOptional() => _Presence(this, optional: false);

  /// Accepts null in addition to this declaration's values.
  SchemaDefinition nullable() => _Nullable(this);

  /// Allows an omitted object property or a null property value.
  SchemaDefinition nullish() => nullable().optional();

  /// Defines an array of this declaration's values.
  ArraySchema array() => ArraySchema._(this);

  /// Accepts values satisfying this declaration or [other].
  SchemaDefinition or(SchemaDefinition other) => union([this, other]);

  /// Requires values to satisfy this declaration and [other].
  SchemaDefinition and(SchemaDefinition other) => intersection(this, other);

  /// Adds a description annotation without changing validation.
  SchemaDefinition describe(String description) =>
      withKeywords({'description': description});

  /// Adds a default annotation without inserting values or changing presence.
  SchemaDefinition defaultValue(Object? value) =>
      withKeywords({'default': value});

  /// Copies and merges raw [keywords] into the generated schema.
  ///
  /// Supplied entries override generated entries, including assertion keywords.
  /// Compilation checks keyword syntax. This escape hatch preserves extensions
  /// and supports annotations without a dedicated convenience method.
  SchemaDefinition withKeywords(Map<String, Object?> keywords) =>
      _Keywords(this, freezeJson(keywords)! as Map<String, Object?>);

  /// Generates an immutable schema, defaulting to Draft 2020-12.
  ///
  /// All nested declarations target [draft]. Throws [SchemaException] when a
  /// constraint is unavailable in that draft or an embedded document uses a
  /// different dialect. Raw keyword syntax is checked during compilation.
  JsonSchema toJsonSchema({SchemaDraft draft = SchemaDraft.draft202012}) =>
      _Renderer(draft).render(this);

  /// Returns generated JSON values, including the root dialect declaration.
  Object toJson({SchemaDraft draft = SchemaDraft.draft202012}) =>
      toJsonSchema(draft: draft).toJson();

  /// Serializes a generated schema, preserving exact numbers and extensions.
  String toJsonString({
    SchemaDraft draft = SchemaDraft.draft202012,
    String? indent,
  }) => toJsonSchema(draft: draft).toJsonString(indent: indent);

  /// Generates and compiles a reusable validator without instance-time wrapping.
  ///
  /// [SchemaOptions.draft] takes precedence over [draft] for generation too.
  /// Reuse the returned validator instead of compiling for each instance.
  CompiledSchema compile({
    SchemaDraft draft = SchemaDraft.draft202012,
    SchemaOptions? options,
    Uri? baseUri,
  }) =>
      toJsonSchema(draft: options?.draft ?? draft)
          .compile(options: options, baseUri: baseUri);

  /// Generates a schema and loads references before returning a sync validator.
  ///
  /// Dialect selection follows [compile]; loading follows
  /// [JsonSchema.compileAsync].
  Future<CompiledSchema> compileAsync({
    SchemaDraft draft = SchemaDraft.draft202012,
    SchemaOptions? options,
    Uri? baseUri,
  }) =>
      toJsonSchema(draft: options?.draft ?? draft)
          .compileAsync(options: options, baseUri: baseUri);

  JsonSchema _build(_Renderer renderer);
}

/// An immutable string declaration with typed constraint modifiers.
final class StringSchema extends SchemaDefinition {
  StringSchema._({
    this._minimum,
    this._maximum,
    Iterable<String> patterns = const [],
    Iterable<String> formats = const [],
  }) : _patterns = List.unmodifiable(patterns),
       _formats = List.unmodifiable(formats);

  final int? _minimum;
  final int? _maximum;
  final List<String> _patterns;
  final List<String> _formats;

  /// Requires at least [length] Unicode code points.
  StringSchema min(int length) {
    _length(length);
    return _copy(minimum: _greater(_minimum, length));
  }

  /// Allows at most [length] Unicode code points.
  StringSchema max(int length) {
    _length(length);
    return _copy(maximum: _smaller(_maximum, length));
  }

  /// Requires exactly [length] Unicode code points.
  StringSchema length(int length) => min(length).max(length);

  /// Requires at least one Unicode code point.
  StringSchema nonempty() => min(1);

  /// Adds an unanchored JSON Schema regular-expression [pattern].
  ///
  /// Multiple calls retain every pattern. Throws [FormatException] for a pattern
  /// the portable engine cannot compile.
  StringSchema pattern(String pattern) {
    RegExp(pattern, unicode: true);
    return _copy(patterns: [..._patterns, pattern]);
  }

  /// Adds a Dart regular expression whose flags JSON Schema can represent.
  ///
  /// Throws [ArgumentError] for case-insensitive, multiline, or dot-all flags.
  /// JSON Schema patterns use the engine's Unicode regular-expression mode.
  StringSchema regex(RegExp expression) {
    if (!expression.isCaseSensitive ||
        expression.isMultiLine ||
        expression.isDotAll) {
      throw ArgumentError.value(
        expression,
        'expression',
        'Flags cannot be serialized as JSON Schema patterns.',
      );
    }
    return pattern(expression.pattern);
  }

  /// Adds a format annotation, asserted when compilation options enable formats.
  StringSchema format(String name) => _copy(formats: [..._formats, name]);

  /// Adds the email format.
  StringSchema email() => format('email');

  /// Adds the UUID format.
  StringSchema uuid() => format('uuid');

  /// Adds the absolute URI format.
  StringSchema url() => format('uri');

  /// Adds the date-time format.
  StringSchema datetime() => format('date-time');

  StringSchema _copy({
    int? minimum,
    int? maximum,
    List<String>? patterns,
    List<String>? formats,
  }) => StringSchema._(
    minimum: minimum ?? _minimum,
    maximum: maximum ?? _maximum,
    patterns: patterns ?? _patterns,
    formats: formats ?? _formats,
  );

  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    type: SchemaType.string,
    minLength: _minimum,
    maxLength: _maximum,
    pattern: _patterns.isEmpty ? null : _patterns.first,
    format: _formats.isEmpty ? null : _formats.first,
    allOf: _patterns.length <= 1 && _formats.length <= 1
        ? null
        : [
            for (final pattern in _patterns.skip(1))
              JsonSchema.build(draft: renderer.draft, pattern: pattern),
            for (final format in _formats.skip(1))
              JsonSchema.build(draft: renderer.draft, format: format),
          ],
  );
}

/// An immutable numeric declaration with inclusive and exclusive bounds.
final class NumberSchema extends SchemaDefinition {
  NumberSchema._({
    this._integer = false,
    this._minimum,
    this._maximum,
    this._exclusiveMinimum,
    this._exclusiveMaximum,
    Iterable<num> multiples = const [],
  }) : _multiples = List.unmodifiable(multiples);

  final bool _integer;
  final num? _minimum;
  final num? _maximum;
  final num? _exclusiveMinimum;
  final num? _exclusiveMaximum;
  final List<num> _multiples;

  /// Restricts values to integers using the selected draft's rules.
  NumberSchema int() => _copy(integer: true);

  /// Requires values greater than or equal to [value].
  NumberSchema min(num value) {
    _finite(value);
    return _copy(minimum: _greaterNumber(_minimum, value));
  }

  /// Requires values less than or equal to [value].
  NumberSchema max(num value) {
    _finite(value);
    return _copy(maximum: _smallerNumber(_maximum, value));
  }

  /// Requires values strictly greater than [value].
  NumberSchema gt(num value) {
    _finite(value);
    return _copy(exclusiveMinimum: _greaterNumber(_exclusiveMinimum, value));
  }

  /// Requires values greater than or equal to [value].
  NumberSchema gte(num value) => min(value);

  /// Requires values strictly less than [value].
  NumberSchema lt(num value) {
    _finite(value);
    return _copy(exclusiveMaximum: _smallerNumber(_exclusiveMaximum, value));
  }

  /// Requires values less than or equal to [value].
  NumberSchema lte(num value) => max(value);

  /// Requires values strictly greater than zero.
  NumberSchema positive() => gt(0);

  /// Requires values greater than or equal to zero.
  NumberSchema nonnegative() => min(0);

  /// Requires values strictly less than zero.
  NumberSchema negative() => lt(0);

  /// Requires values less than or equal to zero.
  NumberSchema nonpositive() => max(0);

  /// Adds an exact decimal multiple check with a positive, finite [divisor].
  ///
  /// Multiple calls retain every check. Draft 00 and 01 cannot express this
  /// constraint and throw [SchemaException] during generation.
  NumberSchema multipleOf(num divisor) {
    _finite(divisor);
    if (divisor <= 0) {
      throw ArgumentError.value(divisor, 'divisor', 'Must be positive.');
    }
    return _copy(multiples: [..._multiples, divisor]);
  }

  NumberSchema _copy({
    bool? integer,
    num? minimum,
    num? maximum,
    num? exclusiveMinimum,
    num? exclusiveMaximum,
    List<num>? multiples,
  }) => NumberSchema._(
    integer: integer ?? _integer,
    minimum: minimum ?? _minimum,
    maximum: maximum ?? _maximum,
    exclusiveMinimum: exclusiveMinimum ?? _exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum ?? _exclusiveMaximum,
    multiples: multiples ?? _multiples,
  );

  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    type: _integer ? SchemaType.integer : SchemaType.number,
    minimum: _minimum,
    maximum: _maximum,
    exclusiveMinimum: _exclusiveMinimum,
    exclusiveMaximum: _exclusiveMaximum,
    multipleOf: _multiples.isEmpty ? null : _multiples.first,
    allOf: _multiples.length < 2
        ? null
        : [
            for (final divisor in _multiples.skip(1))
              JsonSchema.build(draft: renderer.draft, multipleOf: divisor),
          ],
  );
}

/// An immutable object shape with presence and additional-property policies.
final class ObjectSchema extends SchemaDefinition {
  ObjectSchema._(
    Map<String, SchemaDefinition> shape, {
    this._open = false,
    this._catchall,
    this._minimum,
    this._maximum,
  }) : shape = Map.unmodifiable(shape);

  /// The immutable property declarations, including their optional markers.
  final Map<String, SchemaDefinition> shape;
  final bool _open;
  final SchemaDefinition? _catchall;
  final int? _minimum;
  final int? _maximum;

  /// Rejects properties absent from [shape].
  ObjectSchema strict() =>
      ObjectSchema._(shape, minimum: _minimum, maximum: _maximum);

  /// Accepts additional properties without modifying the instance.
  ObjectSchema passthrough() =>
      ObjectSchema._(shape, open: true, minimum: _minimum, maximum: _maximum);

  /// Validates each additional property with [schema].
  ObjectSchema catchall(SchemaDefinition schema) => ObjectSchema._(
    shape,
    catchall: schema,
    minimum: _minimum,
    maximum: _maximum,
  );

  /// Adds or replaces properties, preserving the additional-property policy.
  ObjectSchema extend(Map<String, SchemaDefinition> properties) =>
      _copy({...shape, ...properties});

  /// Retains only the named [keys], rejecting unknown names.
  ObjectSchema pick(Iterable<String> keys) {
    final names = _keys(keys);
    return _copy({
      for (final key in shape.keys)
        if (names.contains(key)) key: shape[key]!,
    });
  }

  /// Removes the named [keys], rejecting unknown names.
  ObjectSchema omit(Iterable<String> keys) {
    final names = _keys(keys);
    return _copy({
      for (final key in shape.keys)
        if (!names.contains(key)) key: shape[key]!,
    });
  }

  /// Makes all properties, or only [keys], optional without changing their types.
  ///
  /// This operation is shallow. Unknown property names throw [ArgumentError].
  ObjectSchema partial({Iterable<String>? keys}) {
    final names = keys == null ? shape.keys.toSet() : _keys(keys);
    return _copy({
      for (final entry in shape.entries)
        entry.key: names.contains(entry.key)
            ? entry.value.optional()
            : entry.value,
    });
  }

  /// Makes all properties, or only [keys], required, retaining nullable values.
  ObjectSchema required({Iterable<String>? keys}) {
    final names = keys == null ? shape.keys.toSet() : _keys(keys);
    return _copy({
      for (final entry in shape.entries)
        entry.key: names.contains(entry.key)
            ? entry.value.nonOptional()
            : entry.value,
    });
  }

  /// Requires at least [count] properties; unavailable before Draft 04.
  ObjectSchema min(int count) {
    _length(count);
    return _copy(shape, minimum: _greater(_minimum, count));
  }

  /// Allows at most [count] properties; unavailable before Draft 04.
  ObjectSchema max(int count) {
    _length(count);
    return _copy(shape, maximum: _smaller(_maximum, count));
  }

  Set<String> _keys(Iterable<String> keys) {
    final result = keys.toSet();
    for (final key in result) {
      if (!shape.containsKey(key)) {
        throw ArgumentError.value(key, 'keys', 'Unknown property name.');
      }
    }
    return result;
  }

  ObjectSchema _copy(
    Map<String, SchemaDefinition> properties, {
    int? minimum,
    int? maximum,
  }) => ObjectSchema._(
    properties,
    open: _open,
    catchall: _catchall,
    minimum: minimum ?? _minimum,
    maximum: maximum ?? _maximum,
  );

  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    type: SchemaType.object,
    properties: {
      for (final entry in shape.entries)
        entry.key: renderer.render(entry.value),
    },
    required:
        !renderer.draft.isLegacy &&
            shape.values.every((value) => value.isOptional)
        ? null
        : [
            for (final entry in shape.entries)
              if (!entry.value.isOptional) entry.key,
          ],
    minProperties: _minimum,
    maxProperties: _maximum,
    additionalProperties: _catchall == null ? null : renderer.render(_catchall),
    keywords: {if (_catchall == null) 'additionalProperties': _open},
  );
}

/// An immutable homogeneous array declaration.
final class ArraySchema extends SchemaDefinition {
  ArraySchema._(
    this.element, {
    this._minimum,
    this._maximum,
    this._unique = false,
  });

  /// The declaration applied to each array element.
  final SchemaDefinition element;
  final int? _minimum;
  final int? _maximum;
  final bool _unique;

  /// Requires at least [count] elements.
  ArraySchema min(int count) {
    _length(count);
    return _copy(minimum: _greater(_minimum, count));
  }

  /// Allows at most [count] elements.
  ArraySchema max(int count) {
    _length(count);
    return _copy(maximum: _smaller(_maximum, count));
  }

  /// Requires exactly [count] elements.
  ArraySchema length(int count) => min(count).max(count);

  /// Requires at least one element.
  ArraySchema nonempty() => min(1);

  /// Requires structurally distinct elements; unavailable before Draft 02.
  ArraySchema unique() => _copy(unique: true);

  ArraySchema _copy({int? minimum, int? maximum, bool? unique}) =>
      ArraySchema._(
        element,
        minimum: minimum ?? _minimum,
        maximum: maximum ?? _maximum,
        unique: unique ?? _unique,
      );

  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    type: SchemaType.array,
    items: renderer.render(element),
    minItems: _minimum,
    maxItems: _maximum,
    uniqueItems: _unique ? true : null,
  );
}

/// An immutable tuple with required positions and an optional rest schema.
final class TupleSchema extends SchemaDefinition {
  TupleSchema._(Iterable<SchemaDefinition> elements, {this._rest})
    : elements = List.unmodifiable(elements);

  /// The immutable declarations for the required tuple positions.
  final List<SchemaDefinition> elements;
  final SchemaDefinition? _rest;

  /// Allows additional elements conforming to [schema].
  TupleSchema rest(SchemaDefinition schema) =>
      TupleSchema._(elements, rest: schema);

  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    type: SchemaType.array,
    prefixItems: elements.isEmpty
        ? null
        : elements.map(renderer.render).toList(),
    items: _rest == null ? null : renderer.render(_rest),
    minItems: elements.length,
    maxItems: _rest == null ? elements.length : null,
  );
}

final class _Renderer {
  _Renderer(this.draft);
  final SchemaDraft draft;
  final Map<SchemaDefinition, JsonSchema> _cache = HashMap.identity();
  JsonSchema render(SchemaDefinition definition) =>
      _cache.putIfAbsent(definition, () => definition._build(this));
}

final class _Primitive extends SchemaDefinition {
  const _Primitive(this.type);
  final SchemaType type;
  @override
  JsonSchema _build(_Renderer renderer) =>
      JsonSchema.build(draft: renderer.draft, type: type);
}

final class _BooleanDefinition extends SchemaDefinition {
  const _BooleanDefinition(this.accepts);
  final bool accepts;
  @override
  JsonSchema _build(_Renderer renderer) => accepts
      ? JsonSchema.any(draft: renderer.draft)
      : JsonSchema.never(draft: renderer.draft);
}

final class _Presence extends SchemaDefinition {
  const _Presence(this.inner, {required bool optional}) : isOptional = optional;
  final SchemaDefinition inner;
  @override
  final bool isOptional;
  @override
  JsonSchema _build(_Renderer renderer) => renderer.render(inner);
}

final class _Nullable extends SchemaDefinition {
  const _Nullable(this.inner);
  final SchemaDefinition inner;

  @override
  bool get isOptional => inner.isOptional;

  @override
  JsonSchema _build(_Renderer renderer) {
    var definition = inner;
    while (definition is _Presence) {
      definition = definition.inner;
    }
    final schema = renderer.render(inner);
    if (definition is _Nullable) {
      return schema;
    }
    if (definition is _BooleanDefinition) {
      return definition.accepts ? schema : renderer.render(nullValue());
    }
    // Typed declarations constrain only their own primitive type. Adding null
    // to that type list avoids a combinator while retaining every constraint.
    // Raw declarations may contain assertions such as enum or const that also
    // restrict null, so they retain the general union representation.
    if (definition is StringSchema ||
        definition is NumberSchema ||
        definition is ObjectSchema ||
        definition is ArraySchema ||
        definition is TupleSchema ||
        definition is _Primitive) {
      final value = schema.value as Map<String, Object?>;
      final type = value['type']! as String;
      return JsonSchema.fromJson({
        ...value,
        'type': type == 'null' ? type : [type, 'null'],
      }, draft: renderer.draft);
    }
    return _Union([inner, nullValue()])._build(renderer);
  }
}

final class _Union extends SchemaDefinition {
  _Union(Iterable<SchemaDefinition> alternatives)
    : alternatives = List.unmodifiable(alternatives) {
    if (this.alternatives.isEmpty) {
      throw ArgumentError.value(
        alternatives,
        'alternatives',
        'Use at least one alternative.',
      );
    }
  }
  final List<SchemaDefinition> alternatives;
  @override
  bool get isOptional => alternatives.any((item) => item.isOptional);
  @override
  JsonSchema _build(_Renderer renderer) {
    final schemas = alternatives.map(renderer.render).toList();
    if (renderer.draft.isLegacy) {
      return JsonSchema.build(
        draft: renderer.draft,
        keywords: {
          'type': [for (final schema in schemas) _embedded(schema)],
        },
      );
    }
    return JsonSchema.build(draft: renderer.draft, anyOf: schemas);
  }
}

final class _Intersection extends SchemaDefinition {
  const _Intersection(this.left, this.right);
  final SchemaDefinition left;
  final SchemaDefinition right;
  @override
  bool get isOptional => left.isOptional && right.isOptional;
  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    allOf: [renderer.render(left), renderer.render(right)],
  );
}

final class _Literal extends SchemaDefinition {
  const _Literal(this.value);
  final Object? value;
  @override
  JsonSchema _build(_Renderer renderer) => renderer.draft.supportsBooleanSchemas
      ? JsonSchema.build(draft: renderer.draft, constValue: value)
      : JsonSchema.build(draft: renderer.draft, enumValues: [value]);
}

final class _Enumeration extends SchemaDefinition {
  const _Enumeration(this.values);
  final List<String> values;
  @override
  JsonSchema _build(_Renderer renderer) => JsonSchema.build(
    draft: renderer.draft,
    type: SchemaType.string,
    enumValues: values,
  );
}

final class _Existing extends SchemaDefinition {
  const _Existing(this.schema);
  final JsonSchema schema;
  @override
  JsonSchema _build(_Renderer renderer) {
    if (schema.draft != renderer.draft) {
      throw SchemaException(
        'The embedded schema uses ${schema.draft.name}; generate that dialect explicitly.',
      );
    }
    return schema;
  }
}

final class _Keywords extends SchemaDefinition {
  const _Keywords(this.inner, this.keywords);
  final SchemaDefinition inner;
  final Map<String, Object?> keywords;
  @override
  bool get isOptional => inner.isOptional;
  @override
  JsonSchema _build(_Renderer renderer) {
    final value = renderer.render(inner).value;
    return JsonSchema.fromJson({
      if (value is Map<String, Object?>) ...value,
      if (value == false) 'not': <String, Object?>{},
      r'$schema': renderer.draft.metaSchemaUri,
      ...keywords,
    }, draft: renderer.draft);
  }
}

Map<String, Object?> _embedded(JsonSchema schema) =>
    Map<String, Object?>.of(schema.value as Map<String, Object?>)
      ..remove(r'$schema');

void _length(int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'length', 'Must be non-negative.');
  }
}

void _finite(num value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
}

int _greater(int? current, int value) =>
    current == null || value > current ? value : current;
int _smaller(int? current, int value) =>
    current == null || value < current ? value : current;
num _greaterNumber(num? current, num value) =>
    current == null || value > current ? value : current;
num _smallerNumber(num? current, num value) =>
    current == null || value < current ? value : current;
