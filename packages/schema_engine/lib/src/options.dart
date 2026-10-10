import 'draft.dart';

/// Checks a string against a configured JSON Schema format.
typedef FormatValidator = bool Function(String value);

/// Retrieves a schema resource during asynchronous compilation.
///
/// Return decoded JSON. Instance validation never invokes this callback.
typedef SchemaResolver = Future<Object?> Function(Uri uri);

/// Checks an instance against an application-defined keyword value.
typedef KeywordValidator = bool Function(
  Object? instance,
  Object? keywordValue,
);

/// Immutable configuration for schema compilation.
final class SchemaOptions {
  /// Creates options with offline resolution and dialect format defaults.
  ///
  /// [draft] overrides the root `$schema` declaration when provided. Nested
  /// resources may declare their own dialect. [defaultDraft] applies to loaded
  /// resources without a declaration; otherwise they inherit the root dialect.
  /// Enable [assertFormats] to check known formats.
  SchemaOptions({
    this.draft,
    this.defaultDraft,
    this.assertFormats,
    this.validateSchema = true,
    this.legacyDependencies = false,
    this.assertContent = false,
    this.resolver,
    Map<Uri, Object?> resources = const {},
    Map<String, FormatValidator> formats = const {},
    Map<String, KeywordValidator> keywords = const {},
    Set<Uri> vocabularies = const {},
  }) : resources = Map.unmodifiable(resources),
       formats = Map.unmodifiable(formats),
       keywords = Map.unmodifiable(keywords),
       vocabularies = Set.unmodifiable(vocabularies);

  /// An explicit override for the root dialect.
  final SchemaDraft? draft;

  /// The fallback for loaded resources, or null to inherit the root dialect.
  final SchemaDraft? defaultDraft;

  /// Overrides optional format assertions, or null to use dialect defaults.
  ///
  /// Standard dialects default to annotations. A required Draft 2019-09 Format
  /// vocabulary defaults to assertions; false explicitly disables them.
  /// Draft 2020-12 Format-Assertion always asserts, regardless of this option.
  final bool? assertFormats;

  /// Whether keyword syntax and registered custom meta-schemas are checked.
  ///
  /// Checks run during compilation, never during instance validation. Built-in
  /// dialects use their keyword grammars; custom meta-schemas may add stricter
  /// constraints. Set this to false only for already trusted schemas.
  final bool validateSchema;

  /// Enables the retired `dependencies` keyword in modern dialects.
  ///
  /// This compatibility extension is disabled by default. Modern schemas should
  /// use `dependentRequired` and `dependentSchemas` instead.
  final bool legacyDependencies;

  /// Enables optional Draft 07 JSON and base64 content assertions.
  ///
  /// Content keywords in 2019-09 and 2020-12 remain annotations as specified.
  final bool assertContent;

  /// The optional asynchronous resource loader.
  final SchemaResolver? resolver;

  /// Locally available resources, keyed by retrieval URI.
  final Map<Uri, Object?> resources;

  /// Additional formats, overriding built-in validators with the same name.
  final Map<String, FormatValidator> formats;

  /// Additional assertion keywords, compiled outside the instance traversal.
  final Map<String, KeywordValidator> keywords;

  /// Application-supported required vocabulary URIs.
  final Set<Uri> vocabularies;
}
