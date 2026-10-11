import 'errors.dart';
import 'json_codec.dart';
import 'json_number.dart';
import 'validation_error_codes.dart';

/// Formats structured validation errors using an application's message catalog.
///
/// Extend or implement this class to integrate any localization system. Use
/// [ValidationMessages.fromTemplates] for a small set of overrides with an
/// English fallback.
/// Catalogs receive stable codes and typed JSON parameters rather than having
/// to interpret English messages. The engine includes only an English catalog
/// and does not select a locale on the application's behalf.
abstract class ValidationMessages {
  /// Creates a catalog that can be implemented by an application.
  const ValidationMessages();

  /// Creates the default English catalog.
  const factory ValidationMessages.english() = EnglishValidationMessages;

  /// Creates a catalog from code-specific formatters.
  ///
  /// Copies [templates] into an immutable map. Missing codes are delegated to
  /// [fallback], which defaults to English. The callbacks can use translated
  /// templates, plural rules, or generated localization methods. Codes are
  /// available as [ValidationErrorCodes] constants and documented with their
  /// parameters in the diagnostic reference.
  factory ValidationMessages.fromTemplates(
    Map<String, ValidationErrorFormatter> templates, {
    ValidationMessages fallback = const EnglishValidationMessages(),
  }) => _TemplateValidationMessages(templates, fallback);

  /// Returns the explanation of [error] in this catalog's language.
  ///
  /// Formatting changes presentation only. Use [ValidationError.code] and
  /// [ValidationError.parameters], and leave the diagnostic's paths intact.
  /// When used as a [ValidationErrorFormatter], [ValidationError.message]
  /// provides the base explanation for unhandled codes. A separate fallback
  /// catalog can also supply those explanations.
  String format(ValidationError error);
}

class _TemplateValidationMessages extends ValidationMessages {
  _TemplateValidationMessages(
    Map<String, ValidationErrorFormatter> templates,
    this.fallback,
  ) : templates = Map.unmodifiable(templates);

  final Map<String, ValidationErrorFormatter> templates;
  final ValidationMessages fallback;

  @override
  String format(ValidationError error) =>
      templates[error.code]?.call(error) ?? fallback.format(error);
}

/// The default English explanations for the engine's supported assertions.
///
/// Applications can extend this class and override [format] for selected codes,
/// or implement [ValidationMessages] to provide a separate catalog. JSON values
/// are encoded losslessly, and character counts follow JSON Schema's Unicode
/// code-point semantics. No Flutter, I/O, or third-party dependency is used.
class EnglishValidationMessages extends ValidationMessages {
  /// Creates the default English message catalog.
  const EnglishValidationMessages();

  @override
  String format(ValidationError error) {
    final p = error.parameters;
    final message = _explanation(error, p);
    final propertyName = p['propertyName'];
    return propertyName is String
        ? 'Property name ${_json(propertyName)}: $message'
        : message;
  }

  String _explanation(ValidationError error, Map<String, Object?> p) {
    final limit = p['limit'];
    return switch (error.code) {
      ValidationErrorCodes.type => _typeMessage(p),
      ValidationErrorCodes.enumValue =>
        'Value must be one of ${_json(p['allowedValues'])}.',
      ValidationErrorCodes.constant =>
        'Value must equal ${_json(p['expectedValue'])}.',
      ValidationErrorCodes.minimum || ValidationErrorCodes.exclusiveMinimum =>
        'Number must be ${_exclusive(error, p) ? 'greater than' : 'at least'} '
            '$limit; received ${p['actualValue']}.',
      ValidationErrorCodes.maximum || ValidationErrorCodes.exclusiveMaximum =>
        'Number must be ${_exclusive(error, p) ? 'less than' : 'at most'} '
            '$limit; received ${p['actualValue']}.',
      ValidationErrorCodes.multipleOf || ValidationErrorCodes.divisibleBy =>
        'Number must be a multiple of ${p['divisor']}; '
            'received ${p['actualValue']}.',
      ValidationErrorCodes.maxDecimal =>
        'Number must have at most $limit '
            '${_plural(limit, 'decimal place', 'decimal places')}; '
            'received ${p['decimalPlaces']}.',
      ValidationErrorCodes.minLength =>
        'Text must contain at least $limit '
            '${_plural(limit, 'Unicode character', 'Unicode characters')}; '
            'received ${p['length']}.',
      ValidationErrorCodes.maxLength =>
        'Text must contain at most $limit '
            '${_plural(limit, 'Unicode character', 'Unicode characters')}; '
            'received ${p['length']}.',
      ValidationErrorCodes.pattern =>
        'Text must match the pattern ${_json(p['pattern'])}.',
      ValidationErrorCodes.format =>
        'Text must be a valid ${_json(p['format'])} value.',
      ValidationErrorCodes.contentEncoding =>
        'Text must use the ${_json(p['encoding'])} content encoding.',
      ValidationErrorCodes.contentMediaType =>
        'Text must contain valid ${_json(p['mediaType'])} content'
            '${p['encoding'] == null ? '' : ' after ${p['encoding']} decoding'}.',
      ValidationErrorCodes.minItems =>
        'Array must contain at least $limit ${_plural(limit, 'item', 'items')}; '
            'received ${p['count']}.',
      ValidationErrorCodes.maxItems =>
        'Array must contain at most $limit ${_plural(limit, 'item', 'items')}; '
            'received ${p['count']}.',
      ValidationErrorCodes.minProperties =>
        'Object must contain at least $limit '
            '${_plural(limit, 'property', 'properties')}; '
            'received ${p['count']}.',
      ValidationErrorCodes.maxProperties =>
        'Object must contain at most $limit '
            '${_plural(limit, 'property', 'properties')}; '
            'received ${p['count']}.',
      ValidationErrorCodes.uniqueItems =>
        'Array items must be unique; indexes ${p['firstIndex']} and '
            '${p['secondIndex']} contain equal values.',
      ValidationErrorCodes.required || ValidationErrorCodes.optional =>
        'Property ${_json(p['property'])} is required.',
      ValidationErrorCodes.dependencies ||
      ValidationErrorCodes.dependentRequired ||
      ValidationErrorCodes.requires =>
        'Property ${_json(p['property'])} requires property '
            '${_json(p['missingProperty'])}.',
      ValidationErrorCodes.additionalProperties =>
        'Additional property ${_json(p['property'])} is not allowed.',
      ValidationErrorCodes.unevaluatedProperties =>
        'Unevaluated property ${_json(p['property'])} is not allowed.',
      ValidationErrorCodes.items || ValidationErrorCodes.additionalItems =>
        'Array item at index ${p['index']} is not allowed'
            '${p['limit'] == null ? '' : '; at most ${p['limit']} ${_plural(p['limit'], 'item is', 'items are')} allowed'}.',
      ValidationErrorCodes.unevaluatedItems =>
        'Unevaluated array item at index ${p['index']} is not allowed.',
      ValidationErrorCodes.contains => _containsMessage(p),
      ValidationErrorCodes.anyOf =>
        'Value must match at least one of ${p['branchCount']} schemas; '
            'none matched.',
      ValidationErrorCodes.oneOf =>
        'Value must match exactly one of ${p['branchCount']} schemas; '
            '${p['matches'] == 0 ? 'none matched' : 'more than one matched'}.',
      ValidationErrorCodes.not =>
        'Value must not match the schema specified by "not".',
      ValidationErrorCodes.disallow =>
        p['disallowedTypes'] == null
            ? 'Value must not match disallowed schema ${p['schemaIndex']}.'
            : 'Value must not have type ${_types(p['disallowedTypes'])}; '
                  'received ${p['actualType']}.',
      ValidationErrorCodes.falseSchema =>
        'No value is allowed by this false schema.',
      ValidationErrorCodes.custom =>
        'Value does not satisfy custom keyword ${_json(error.keyword)} '
            'with constraint ${_json(p['constraint'])}.',
      _ => 'Value does not satisfy the ${_json(error.code)} constraint.',
    };
  }
}

bool _exclusive(ValidationError error, Map<String, Object?> p) =>
    error.code == ValidationErrorCodes.exclusiveMinimum ||
    error.code == ValidationErrorCodes.exclusiveMaximum ||
    p['exclusive'] == true;

String _typeMessage(Map<String, Object?> p) {
  final schemas = p['schemaAlternatives'];
  final types = p['expectedTypes'];
  final hasTypes = types is List<Object?> && types.isNotEmpty;
  final expected = schemas is int && schemas > 0
      ? '${hasTypes ? '${_types(types)} or ' : ''}'
            'a value matching one of $schemas alternative schemas'
      : _types(types);
  return 'Expected $expected; received ${p['actualType']}.';
}

String _containsMessage(Map<String, Object?> p) {
  final tooMany = p['reason'] == 'tooMany';
  final bound = tooMany ? p['maximum'] : p['minimum'];
  return 'Array must contain ${tooMany ? 'at most' : 'at least'} $bound '
      '${_plural(bound, 'item', 'items')} matching the "contains" schema; '
      '${tooMany ? 'at least ' : ''}${p['matches']} matched.';
}

String _types(Object? values) => values is List<Object?> && values.isNotEmpty
    ? values.join(' or ')
    : 'a value matching the schema';

String _json(Object? value) => encodeJson(value);

String _plural(Object? count, String singular, String plural) =>
    isJsonNumber(count) && compareNumbers(count!, 1) == 0 ? singular : plural;
