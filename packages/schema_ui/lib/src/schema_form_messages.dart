import 'package:schema_engine/schema_engine.dart';

/// Localizable text and message formatters for a schema form.
///
/// Override only the messages your application needs. Defaults preserve the
/// English UI and the engine's original diagnostics. Callbacks accept complete
/// labels or structured errors so translations can control word order without
/// parsing English messages. Schema titles, descriptions, and enum values are
/// supplied by the application and are not translated automatically.
///
/// ```dart
/// final messages = SchemaFormMessages(
///   optionalLabel: (label) => '$label (not required)',
///   addItemLabel: 'Add another item',
/// );
/// ```
final class SchemaFormMessages {
  /// Creates messages with English defaults and optional application overrides.
  ///
  /// Values and callbacks can come from the application's localization system;
  /// no localization delegate or additional dependency is required.
  const SchemaFormMessages({
    this.valueLabel = 'Value',
    this.additionalPropertiesLabel = 'Additional properties (JSON)',
    this.addItemLabel = 'Add item',
    this.requiredPropertyError,
    this.invalidJsonError = 'Enter valid JSON.',
    this.invalidAdditionalPropertiesError =
        'Enter a JSON object with additional keys only.',
    this.optionalLabel = _optionalLabel,
    this.clearValueTooltip = _clearValueTooltip,
    this.useNullLabel = _useNullLabel,
    this.removeItemTooltip = _removeItemTooltip,
    this.validationError = _validationError,
    this.numberInputError = _numberInputError,
    this.errorSummary = _errorSummary,
  });

  /// The root label when the schema does not supply a title.
  final String valueLabel;

  /// The label of the JSON editor for additional object properties.
  final String additionalPropertiesLabel;

  /// The text on array item addition buttons.
  final String addItemLabel;

  /// The field error for an absent required object property.
  ///
  /// Null uses the engine's property-specific diagnostic via [validationError].
  /// Supply text to override missing-property errors in generated fields.
  final String? requiredPropertyError;

  /// The error for JSON text that cannot be decoded.
  final String invalidJsonError;

  /// The error for additional-property JSON with an invalid object shape.
  final String invalidAdditionalPropertiesError;

  /// Formats the complete label of an optional property.
  final String Function(String label) optionalLabel;

  /// Formats a clear button's tooltip using the undecorated field label.
  final String Function(String label) clearValueTooltip;

  /// Formats the nullable switch label using the displayed field label.
  final String Function(String label) useNullLabel;

  /// Formats an array removal tooltip using a one-based item number.
  final String Function(int itemNumber) removeItemTooltip;

  /// Formats a structured engine diagnostic for field and root errors.
  ///
  /// The default returns [ValidationError.message]. Changing its presentation
  /// does not change validity or the diagnostics exposed to custom editors.
  final String Function(ValidationError error) validationError;

  /// Formats a numeric decoding error when no schema assertion rejects input.
  ///
  /// Schema diagnostics take precedence. The default returns the decoder's
  /// [FormatException.message], preserving its explanation of the failure.
  final String Function(FormatException error) numberInputError;

  /// Formats the root summary from a JSON Pointer and an already formatted error.
  ///
  /// An empty `instancePath` identifies the root. The default displays `/` for
  /// that pointer. Custom editor input errors are passed through as supplied.
  final String Function(String instancePath, String message) errorSummary;
}

String _optionalLabel(String label) => '$label (optional)';

String _clearValueTooltip(String label) => 'Clear $label';

String _useNullLabel(String label) => 'Use null for $label';

String _removeItemTooltip(int itemNumber) => 'Remove item $itemNumber';

String _validationError(ValidationError error) => error.message;

String _numberInputError(FormatException error) => error.message;

String _errorSummary(String instancePath, String message) =>
    '${instancePath.isEmpty ? '/' : instancePath}: $message';
