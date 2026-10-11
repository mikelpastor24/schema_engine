import 'validation_error_codes.dart';
import 'validation_messages.dart';

/// Formats a structured validation error in an application-selected language.
///
/// Use [ValidationError.code] and [ValidationError.parameters], rather than
/// matching message text. The formatter receives a diagnostic without an active
/// formatter, so [ValidationError.message] provides its base explanation as a
/// fallback without invoking the formatter recursively.
typedef ValidationErrorFormatter = String Function(ValidationError error);

/// A malformed schema or an unsupported required vocabulary.
final class SchemaException implements Exception {
  /// Creates an error at [schemaPath], a JSON Pointer within the schema.
  const SchemaException(this.message, {this.schemaPath = ''});

  /// The explanation of the schema error.
  final String message;

  /// The JSON Pointer at which the problem was found.
  final String schemaPath;

  @override
  String toString() => 'SchemaException at $schemaPath: $message';
}

/// A reference that cannot be resolved from configured schema resources.
final class ReferenceException implements Exception {
  /// Creates an error for the unresolved absolute [reference].
  const ReferenceException(this.reference, this.message);

  /// The absolute reference URI that could not be resolved.
  final Uri reference;

  /// The reason resolution failed.
  final String message;

  @override
  String toString() => 'ReferenceException for $reference: $message';
}

/// A failed instance assertion with locations expressed as JSON Pointers.
final class ValidationError {
  /// Creates a diagnostic for a failed [keyword].
  ///
  /// [code] defaults to [keyword]. Omitting [message] generates an explanation
  /// lazily from [parameters]. An explicit message remains supported for
  /// application-created diagnostics. Engine-produced parameter maps and their
  /// nested values are immutable; callers constructing errors should supply
  /// immutable parameters too. `messageFormatter` controls the displayed
  /// language without altering the structured diagnostic.
  const ValidationError({
    required this.keyword,
    this._message,
    required this.instancePath,
    required this.schemaPath,
    required this.schemaLocation,
    String? code,
    this.parameters = const {},
    this._messageFormatter,
  }) : code = code ?? keyword;

  /// The keyword that failed.
  final String keyword;

  /// A stable message identifier, independent of the displayed language.
  ///
  /// Usually the assertion keyword. A false schema used by an applicator has
  /// that applicator's code, and application keywords use `custom`.
  /// Use [ValidationErrorCodes] for built-in values in catalogs and comparisons.
  final String code;

  /// The constraints and failure details needed to format this diagnostic.
  ///
  /// Values preserve exact JSON numbers. They do not embed or retain the
  /// complete instance. See the diagnostic parameter reference in the README.
  final Map<String, Object?> parameters;

  final String? _message;
  final ValidationErrorFormatter? _messageFormatter;

  /// The human-readable explanation in the configured language.
  ///
  /// English is the default. Text is generated only when requested.
  String get message => _messageFormatter == null
      ? _message ?? const ValidationMessages.english().format(this)
      : _messageFormatter(_withoutMessageFormatter());

  /// Formats this error without validating the instance again.
  ///
  /// With no [formatter], returns [message]. A supplied formatter overrides the
  /// compilation or validation call's selected language for this presentation.
  /// Its diagnostic's [message] provides the base explanation as a fallback.
  String formatMessage([ValidationErrorFormatter? formatter]) =>
      formatter == null ? message : formatter(_withoutMessageFormatter());

  ValidationError _withoutMessageFormatter() => _messageFormatter == null
      ? this
      : ValidationError(
          keyword: keyword,
          code: code,
          parameters: parameters,
          message: _message,
          instancePath: instancePath,
          schemaPath: schemaPath,
          schemaLocation: schemaLocation,
        );

  /// The JSON Pointer within the instance.
  final String instancePath;

  /// The JSON Pointer within the schema resource.
  final String schemaPath;

  /// The absolute location of the failing keyword.
  final Uri schemaLocation;

  /// Serializes this error without embedding the instance itself.
  Map<String, Object?> toJson() => {
    'keyword': keyword,
    'code': code,
    'parameters': parameters,
    'message': message,
    'instancePath': instancePath,
    'schemaPath': schemaPath,
    'schemaLocation': schemaLocation.toString(),
  };

  @override
  String toString() => '$instancePath: $message ($schemaPath)';
}
