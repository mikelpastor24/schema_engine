part of 'validator.dart';

// Constraint data is prepared once. Actual counts and duplicate indexes are
// derived only after a failure on a diagnostic path, never on boolean checks.
Map<String, Object?> _constraintParameters(
  String keyword,
  Map<String, Object?> schema,
  SchemaDraft draft,
) {
  final value = schema[keyword];
  return switch (keyword) {
    'type' => {
      'expectedTypes': List<String>.unmodifiable(
        value is List<Object?> ? value.cast<String>() : [value! as String],
      ),
    },
    'enum' => {'allowedValues': value},
    'const' => {'expectedValue': value},
    'minimum' || 'maximum' => {
      'limit': value,
      'exclusive': draft.index < SchemaDraft.draft3.index
          ? schema[keyword == 'minimum'
                    ? 'minimumCanEqual'
                    : 'maximumCanEqual'] ==
                false
          : draft.index < SchemaDraft.draft6.index &&
                schema[keyword == 'minimum'
                        ? 'exclusiveMinimum'
                        : 'exclusiveMaximum'] ==
                    true,
    },
    'exclusiveMinimum' ||
    'exclusiveMaximum' ||
    'minLength' ||
    'maxLength' ||
    'minItems' ||
    'maxItems' ||
    'minProperties' ||
    'maxProperties' ||
    'maxDecimal' => {'limit': value},
    'multipleOf' || 'divisibleBy' => {'divisor': value},
    'pattern' => {'pattern': value},
    'format' => {'format': value},
    'contentEncoding' => {'encoding': value},
    'contentMediaType' => {
      'mediaType': value,
      if (schema['contentEncoding'] == 'base64') 'encoding': 'base64',
    },
    _ => const {},
  };
}

Map<String, Object?> _instanceParameters(
  String code,
  Object? instance,
  Map<String, Object?> constraints,
  SchemaDraft draft,
) {
  final parameters = <String, Object?>{...constraints};
  switch (code) {
    case ValidationErrorCodes.type:
    case ValidationErrorCodes.disallow:
      parameters['actualType'] = _instanceType(instance, draft);
    case ValidationErrorCodes.minimum:
    case ValidationErrorCodes.maximum:
    case ValidationErrorCodes.exclusiveMinimum:
    case ValidationErrorCodes.exclusiveMaximum:
    case ValidationErrorCodes.multipleOf:
    case ValidationErrorCodes.divisibleBy:
      parameters['actualValue'] = instance;
    case ValidationErrorCodes.maxDecimal:
      final scale = _Decimal.of(instance!).scale;
      parameters['decimalPlaces'] = scale < 0 ? 0 : scale;
    case ValidationErrorCodes.minLength:
    case ValidationErrorCodes.maxLength:
      parameters['length'] = (instance! as String).runes.length;
    case ValidationErrorCodes.minItems:
    case ValidationErrorCodes.maxItems:
      parameters['count'] = (instance! as List<Object?>).length;
    case ValidationErrorCodes.minProperties:
    case ValidationErrorCodes.maxProperties:
      parameters['count'] = (instance! as Map<Object?, Object?>).length;
    case ValidationErrorCodes.uniqueItems:
      final items = instance! as List<Object?>;
      final seen = HashMap<Object?, int>(
        equals: jsonEquals,
        hashCode: jsonHash,
      );
      for (var second = 1; second < items.length; second++) {
        if (second == 1) {
          seen[items.first] = 0;
        }
        final first = seen[items[second]];
        if (first != null) {
          parameters['firstIndex'] = first;
          parameters['secondIndex'] = second;
          return parameters;
        }
        seen[items[second]] = second;
      }
  }
  return parameters;
}

String _instanceType(Object? instance, SchemaDraft draft) {
  if (instance == null) {
    return 'null';
  }
  if (instance is bool) {
    return 'boolean';
  }
  if (instance is String) {
    return 'string';
  }
  if (isJsonNumber(instance)) {
    return isJsonInteger(
          instance,
          allowDecimal: draft.index >= SchemaDraft.draft6.index,
        )
        ? 'integer'
        : 'number';
  }
  if (instance is List<Object?>) {
    return 'array';
  }
  if (instance is Map<Object?, Object?>) {
    return 'object';
  }
  return 'non-JSON value (${instance.runtimeType})';
}

bool _rejectProperty(
  _Node node,
  String property,
  _Context? context,
  String path,
  bool report, {
  String code = ValidationErrorCodes.additionalProperties,
}) {
  if (report && context?.errors != null) {
    context!.fail(
      node.entry,
      'false',
      path,
      code: code,
      parameters: {'property': property},
    );
  }
  return false;
}

bool _rejectItem(
  _Node node,
  int index,
  _Context? context,
  String path,
  bool report, {
  String? code,
  int? limit,
}) {
  if (report && context?.errors != null) {
    context!.fail(
      node.entry,
      'false',
      _childPath(context, path, '$index', report),
      code:
          code ??
          (node.entry.path.endsWith('/items')
              ? ValidationErrorCodes.items
              : ValidationErrorCodes.additionalItems),
      parameters: {'index': index, 'limit': ?limit},
    );
  }
  return false;
}
