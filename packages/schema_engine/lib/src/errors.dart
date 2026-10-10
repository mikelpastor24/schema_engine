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
  const ValidationError({
    required this.keyword,
    required this.message,
    required this.instancePath,
    required this.schemaPath,
    required this.schemaLocation,
  });

  /// The keyword that failed.
  final String keyword;

  /// A human-readable English explanation.
  final String message;

  /// The JSON Pointer within the instance.
  final String instancePath;

  /// The JSON Pointer within the schema resource.
  final String schemaPath;

  /// The absolute location of the failing keyword.
  final Uri schemaLocation;

  /// Serializes this error without embedding the instance itself.
  Map<String, Object?> toJson() => {
    'keyword': keyword,
    'message': message,
    'instancePath': instancePath,
    'schemaPath': schemaPath,
    'schemaLocation': schemaLocation.toString(),
  };

  @override
  String toString() => '$instancePath: $message ($schemaPath)';
}
