import 'package:schema_engine/schema_engine.dart';

/// Application-owned labels and explanations for the visual schema editor.
///
/// Extend this class and override getters or methods with your application's
/// localization methods. The default messages are English; no locale selection
/// or translation dependency is required.
class SchemaEditorMessages {
  /// Creates the default English messages.
  const SchemaEditorMessages();

  /// The root section heading.
  String get schema => 'Schema';

  /// The property section heading.
  String get properties => 'Properties';

  /// The reusable definition section heading.
  String get definitions => 'Definitions';

  /// The property creation action.
  String get addProperty => 'Add property';

  /// The definition creation action.
  String get addDefinition => 'Add definition';

  /// The property name input label.
  String get propertyName => 'Property name';

  /// The definition name input label.
  String get definitionName => 'Definition name';

  /// The schema type selector label.
  String get type => 'Type';

  /// The required property switch label.
  String get required => 'Required';

  /// The nullable type switch label.
  String get nullable => 'Allow null';

  /// The constraints and annotations section heading.
  String get settings => 'Constraints and annotations';

  /// The array item schema heading.
  String get items => 'Item schema';

  /// The action for assigning an array item schema.
  String get setItems => 'Set item schema';

  /// The additional property policy selector label.
  String get additionalProperties => 'Additional properties';

  /// The policy that accepts any additional property.
  String get allow => 'Allow';

  /// The policy that rejects additional properties.
  String get forbid => 'Forbid';

  /// The policy that validates additional properties against a schema.
  String get useSchema => 'Use a schema';

  /// The additional property schema heading.
  String get additionalPropertySchema => 'Additional property schema';

  /// The unique array items switch label.
  String get uniqueItems => 'Unique items';

  /// The reusable definition selector label.
  String get useDefinition => 'Use definition';

  /// The label for unrestricted schemas.
  String get anyType => 'Any value';

  /// The label for schemas that reject every instance.
  String get neverType => 'No values';

  /// The label for references.
  String get referenceType => 'Reference';

  /// The label for imported unions with multiple non-null types.
  String get multipleTypes => 'Multiple types';

  /// Explains that a number is required.
  String get invalidNumber => 'Enter a valid number.';

  /// Explains that a nonnegative integral count is required.
  String get invalidCount => 'Enter a nonnegative integer.';

  /// Explains that a multiple must be positive.
  String get invalidMultiple => 'Enter a number greater than zero.';

  /// Explains that a JSON annotation or value could not be decoded.
  String get invalidJson => 'Enter valid JSON.';

  /// Explains the array shape required by enum values and examples.
  String get invalidArray => 'Enter a JSON array.';

  /// Explains the valid empty URI reference.
  String get referenceHint =>
      'An empty reference targets this schema resource.';

  /// Explains that two entries have the same name.
  String get duplicateName => 'This name is already used in this section.';

  /// Labels an actual JSON Schema type.
  String typeLabel(SchemaType type) => switch (type) {
    SchemaType.nullValue => 'Null',
    SchemaType.boolean => 'Boolean',
    SchemaType.object => 'Object',
    SchemaType.array => 'Array',
    SchemaType.number => 'Number',
    SchemaType.integer => 'Integer',
    SchemaType.string => 'String',
  };

  /// Labels a keyword configuration field.
  ///
  /// Unknown extension identifiers remain unchanged.
  String keywordLabel(String keyword) =>
      const {
        r'$id': 'Schema ID',
        r'$ref': 'Reference',
        'title': 'Title',
        'description': 'Description',
        'minLength': 'Minimum length',
        'maxLength': 'Maximum length',
        'pattern': 'Pattern',
        'format': 'Format',
        'minimum': 'Minimum',
        'maximum': 'Maximum',
        'exclusiveMinimum': 'Exclusive minimum',
        'exclusiveMaximum': 'Exclusive maximum',
        'multipleOf': 'Multiple of',
        'minItems': 'Minimum items',
        'maxItems': 'Maximum items',
        'minProperties': 'Minimum properties',
        'maxProperties': 'Maximum properties',
        'enum': 'Allowed values (JSON array)',
        'const': 'Constant value (JSON)',
        'default': 'Default value (JSON)',
        'examples': 'Examples (JSON array)',
      }[keyword] ??
      keyword;

  /// Formats the removal tooltip for an entry.
  String remove(String name) => 'Remove $name';

  /// Formats an editor input error with its JSON Pointer.
  String inputError(String path, String message) => '$path: $message';

  /// Formats a compilation error without assuming a particular locale.
  ///
  /// Override this when your application supplies localized schema diagnostics.
  String schemaError(Object error) => switch (error) {
    SchemaException() => inputError(error.schemaPath, error.message),
    ReferenceException() => error.message,
    FormatException() => error.message,
    _ => error.toString(),
  };
}
