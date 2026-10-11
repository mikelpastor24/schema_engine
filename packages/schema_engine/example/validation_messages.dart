import 'package:schema_engine/schema_engine.dart';

/// An application-owned catalog that overrides selected messages.
class ApplicationValidationMessages extends EnglishValidationMessages {
  /// Creates the application's message catalog with an English fallback.
  const ApplicationValidationMessages();

  @override
  String format(ValidationError error) => switch (error.code) {
    ValidationErrorCodes.minLength =>
      'Minimum length: ${error.parameters['limit']}; '
          'current length: ${error.parameters['length']}.',
    _ => super.format(error),
  };
}

/// Demonstrates catalog selection without Flutter or locale dependencies.
void main() {
  final document = JsonSchema.fromJson({'type': 'string', 'minLength': 3});
  const catalog = ApplicationValidationMessages();
  final validator = document.compile(
    options: SchemaOptions(messageFormatter: catalog.format),
  );
  final error = validator.validate('No')!;
  print(error.message);
  print(error.parameters);
  print(error.formatMessage(const ValidationMessages.english().format));

  final templates = ValidationMessages.fromTemplates({
    ValidationErrorCodes.type: (error) =>
        'Expected types: ${error.parameters['expectedTypes']}; '
        'actual type: ${error.parameters['actualType']}.',
  });
  print(validator.validate(12, messageFormatter: templates.format)!.message);
}
