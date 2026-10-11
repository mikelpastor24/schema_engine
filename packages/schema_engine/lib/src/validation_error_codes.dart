/// Stable string identifiers for the engine's built-in validation messages.
///
/// Use these constants in message catalogs and diagnostic comparisons. Values
/// remain ordinary strings, so serialized errors and application-defined codes
/// use the same open representation. Reserved Dart words have descriptive
/// member names: [enumValue], [constant], and [falseSchema].
///
/// The namespace makes related string keys discoverable through autocompletion
/// while allowing application-defined codes and compatible serialized messages.
abstract final class ValidationErrorCodes {
  /// The instance does not match its expected JSON type.
  static const type = 'type';

  /// The instance is outside the schema's allowed values.
  static const enumValue = 'enum';

  /// The instance differs from the schema's constant.
  static const constant = 'const';

  /// The number is below its lower bound.
  static const minimum = 'minimum';

  /// The number exceeds its upper bound.
  static const maximum = 'maximum';

  /// The number does not exceed its exclusive lower bound.
  static const exclusiveMinimum = 'exclusiveMinimum';

  /// The number is not below its exclusive upper bound.
  static const exclusiveMaximum = 'exclusiveMaximum';

  /// The number is not a multiple of the schema's divisor.
  static const multipleOf = 'multipleOf';

  /// The historical divisibleBy assertion failed.
  static const divisibleBy = 'divisibleBy';

  /// The historical decimal-place limit was exceeded.
  static const maxDecimal = 'maxDecimal';

  /// The string is shorter than its minimum Unicode length.
  static const minLength = 'minLength';

  /// The string exceeds its maximum Unicode length.
  static const maxLength = 'maxLength';

  /// The string does not match the schema's regular expression.
  static const pattern = 'pattern';

  /// The string does not satisfy the asserted format.
  static const format = 'format';

  /// The string does not use the asserted content encoding.
  static const contentEncoding = 'contentEncoding';

  /// The string does not contain valid content of the asserted media type.
  static const contentMediaType = 'contentMediaType';

  /// The array contains too few items.
  static const minItems = 'minItems';

  /// The array contains too many items.
  static const maxItems = 'maxItems';

  /// The object contains too few properties.
  static const minProperties = 'minProperties';

  /// The object contains too many properties.
  static const maxProperties = 'maxProperties';

  /// The array contains equal items at different indexes.
  static const uniqueItems = 'uniqueItems';

  /// A required object property is missing.
  static const required = 'required';

  /// A historical implicitly required property is missing.
  static const optional = 'optional';

  /// A property dependency from an earlier draft is missing.
  static const dependencies = 'dependencies';

  /// A required property dependency is missing.
  static const dependentRequired = 'dependentRequired';

  /// A historical requires property dependency is missing.
  static const requires = 'requires';

  /// An additional object property is forbidden.
  static const additionalProperties = 'additionalProperties';

  /// An unevaluated object property is forbidden.
  static const unevaluatedProperties = 'unevaluatedProperties';

  /// An array item is forbidden by the items applicator.
  static const items = 'items';

  /// An array item beyond a tuple's prefix is forbidden.
  static const additionalItems = 'additionalItems';

  /// An unevaluated array item is forbidden.
  static const unevaluatedItems = 'unevaluatedItems';

  /// The number of items matching contains is outside its allowed bounds.
  static const contains = 'contains';

  /// No alternative schema matched.
  static const anyOf = 'anyOf';

  /// Exactly one alternative schema was required to match.
  static const oneOf = 'oneOf';

  /// The instance matched a forbidden schema.
  static const not = 'not';

  /// A historical forbidden type or schema matched.
  static const disallow = 'disallow';

  /// A false schema rejects the instance.
  static const falseSchema = 'false';

  /// An application-defined assertion failed.
  static const custom = 'custom';

  /// Maps assertion keywords to their canonical message codes.
  ///
  /// Includes the synthetic `false` and `custom` identifiers. The immutable
  /// registry can also enumerate built-in codes for catalog coverage checks.
  static const byKeyword = <String, String>{
    'type': type,
    'enum': enumValue,
    'const': constant,
    'minimum': minimum,
    'maximum': maximum,
    'exclusiveMinimum': exclusiveMinimum,
    'exclusiveMaximum': exclusiveMaximum,
    'multipleOf': multipleOf,
    'divisibleBy': divisibleBy,
    'maxDecimal': maxDecimal,
    'minLength': minLength,
    'maxLength': maxLength,
    'pattern': pattern,
    'format': format,
    'contentEncoding': contentEncoding,
    'contentMediaType': contentMediaType,
    'minItems': minItems,
    'maxItems': maxItems,
    'minProperties': minProperties,
    'maxProperties': maxProperties,
    'uniqueItems': uniqueItems,
    'required': required,
    'optional': optional,
    'dependencies': dependencies,
    'dependentRequired': dependentRequired,
    'requires': requires,
    'additionalProperties': additionalProperties,
    'unevaluatedProperties': unevaluatedProperties,
    'items': items,
    'additionalItems': additionalItems,
    'unevaluatedItems': unevaluatedItems,
    'contains': contains,
    'anyOf': anyOf,
    'oneOf': oneOf,
    'not': not,
    'disallow': disallow,
    'false': falseSchema,
    'custom': custom,
  };

  /// Returns the built-in code for [keyword], or preserves an extension name.
  ///
  /// The compiler uses [custom] for application assertions. This method also
  /// allows diagnostic producers to map keywords without repeating wire values.
  static String forKeyword(String keyword) => byKeyword[keyword] ?? keyword;
}
