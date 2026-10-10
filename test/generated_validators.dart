// Generated test fixtures. Run tool/generate_validators.dart.
import 'package:schema_engine/schema_engine.dart' as engine;

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDeclarative {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDeclarative({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "additionalProperties": false,
    "\$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string", "minLength": 1},
      "age": <String, Object?>{"type": "integer", "minimum": 0},
      "note": <String, Object?>{
        "type": <Object?>["string", "null"],
        "minLength": 1,
      },
    },
    "required": <Object?>["name", "note"],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  engine.CompiledSchema? _exact2;
  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (!value.containsKey("note")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    if (value.containsKey("age") && !_check2(value["age"])) {
      return false;
    }
    if (value.containsKey("note") && !_check3(value["note"])) {
      return false;
    }
    for (final key in value.keys) {
      final covered = key == "name" || key == "age" || key == "note";
      if (!covered && !_check4(value[key])) {
        return false;
      }
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    if (!(value.isNotEmpty)) {
      return false;
    }
    return true;
  }

  bool _check2(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact2 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
        "minimum": 0,
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    if (!(value >= 0)) {
      return false;
    }
    return true;
  }

  bool _check3(Object? value) {
    if (!(value is String || value == null)) {
      return false;
    }
    if (!(value is! String || (value.isNotEmpty))) {
      return false;
    }
    return true;
  }

  bool _check4(Object? value) => false;
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedBigNumber {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedBigNumber({this.options}) : isSpecialized = false;

  static final _document = engine.decodeJson(
    "{\"type\":\"integer\",\"minimum\":9007199254740993}",
  );

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) => _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedInteger {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedInteger({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "type": "integer",
    "minimum": 0,
    "maximum": 1000,
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  engine.CompiledSchema? _exact0;
  bool _check0(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact0 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
        "minimum": 0,
        "maximum": 1000,
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    if (!(value >= 0 && value <= 1000)) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedObject {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedObject({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "type": "object",
    "required": <Object?>["id", "name"],
    "properties": <String, Object?>{
      "id": <String, Object?>{"type": "integer", "minimum": 0},
      "name": <String, Object?>{
        "type": "string",
        "minLength": 1,
        "maxLength": 64,
      },
      "active": <String, Object?>{"type": "boolean"},
    },
    "additionalProperties": false,
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  engine.CompiledSchema? _exact1;
  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("id")) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("id") && !_check1(value["id"])) {
      return false;
    }
    if (value.containsKey("name") && !_check2(value["name"])) {
      return false;
    }
    if (value.containsKey("active") && !_check3(value["active"])) {
      return false;
    }
    for (final key in value.keys) {
      final covered = key == "id" || key == "name" || key == "active";
      if (!covered && !_check4(value[key])) {
        return false;
      }
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact1 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
        "minimum": 0,
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    if (!(value >= 0)) {
      return false;
    }
    return true;
  }

  bool _check2(Object? value) {
    if (value is! String) {
      return false;
    }
    if (!(value.isNotEmpty && value.runes.length <= 64)) {
      return false;
    }
    return true;
  }

  bool _check3(Object? value) {
    if (value is! bool) {
      return false;
    }
    return true;
  }

  bool _check4(Object? value) => false;
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedArray {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedArray({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "type": "array",
    "minItems": 1,
    "items": <String, Object?>{"type": "integer", "minimum": 0},
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  engine.CompiledSchema? _exact1;
  bool _check0(Object? value) {
    if (value is! List<Object?>) {
      return false;
    }
    if (value.isEmpty) {
      return false;
    }
    for (var i = 0; i < value.length; i++) {
      if (!_check1(value[i])) {
        return false;
      }
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact1 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
        "minimum": 0,
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    if (!(value >= 0)) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedConditional {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedConditional({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "if": <String, Object?>{"type": "string"},
    "then": <String, Object?>{"minLength": 2},
    "else": <String, Object?>{"type": "integer", "minimum": 0},
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  engine.CompiledSchema? _exact3;
  bool _check0(Object? value) {
    if (!(_check1(value) ? _check2(value) : _check3(value))) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }

  bool _check2(Object? value) {
    if (!(value is! String || (value.runes.length >= 2))) {
      return false;
    }
    return true;
  }

  bool _check3(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact3 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
        "minimum": 0,
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    if (!(value >= 0)) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedAlternatives {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedAlternatives({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "oneOf": <Object?>[
      <String, Object?>{"type": "string"},
      <String, Object?>{"type": "integer"},
    ],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  engine.CompiledSchema? _exact2;
  bool _check0(Object? value) {
    if (!(((_check1(value) ? 1 : 0) + (_check2(value) ? 1 : 0)) == 1)) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }

  bool _check2(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact2 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedPatterns {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedPatterns({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "patternProperties": <String, Object?>{
      "^x\\\$": <String, Object?>{"type": "integer"},
    },
    "additionalProperties": false,
    "x-description": "Text containing \$ and quotes \" safely.",
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  final _pattern0 = RegExp("^x\\\$", unicode: true);
  engine.CompiledSchema? _exact1;
  bool _check0(Object? value) {
    if (value is Map<Object?, Object?>) {
      for (final key in value.keys) {
        var covered = false;
        if (_pattern0.hasMatch(key as String)) {
          covered = true;
          if (!_check1(value[key])) {
            return false;
          }
        }
        if (!covered && !_check2(value[key])) {
          return false;
        }
      }
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! num && (value is BigInt || value is engine.JsonNumber)) {
      return (_exact1 ??= engine.JsonSchema.fromJson(<String, Object?>{
        "type": "integer",
      }, draft: engine.SchemaDraft.draft202012).compile()).isValid(value);
    }
    if (!((value is num &&
        (value is int ||
            value.isFinite && value == value.truncateToDouble())))) {
      return false;
    }
    return true;
  }

  bool _check2(Object? value) => false;
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedFallback {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedFallback({this.options}) : isSpecialized = false;

  static const _document = <String, Object?>{"multipleOf": 0.1};

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) => _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedEmpty {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedEmpty({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{};

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedFalse {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedFalse({this.options}) : isSpecialized = options == null;

  static const _document = false;

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) => false;
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedEmptyCollection {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedEmptyCollection({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "oneOf": <Object?>[
      <String, Object?>{"type": "array", "minItems": 0, "maxItems": 0},
      <String, Object?>{
        "type": "object",
        "minProperties": 0,
        "maxProperties": 0,
      },
    ],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!(((_check1(value) ? 1 : 0) + (_check2(value) ? 1 : 0)) == 1)) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! List<Object?>) {
      return false;
    }
    if (value.isNotEmpty) {
      return false;
    }
    return true;
  }

  bool _check2(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (value.isNotEmpty) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedUnicodeString {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedUnicodeString({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "type": "string",
    "minLength": 1,
    "maxLength": 1,
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (value is! String) {
      return false;
    }
    if (!(value.isNotEmpty && value.runes.length <= 1)) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft0 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft0({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-00/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string", "optional": false},
    },
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft0,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft1 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft1({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-01/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string", "optional": false},
    },
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft1,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft2 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft2({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-02/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string", "optional": false},
    },
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft2,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft3 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft3({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-03/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string", "required": true},
    },
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft3,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft4 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft4({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-04/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string"},
    },
    "required": <Object?>["name"],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft4,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft6 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft6({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-06/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string"},
    },
    "required": <Object?>["name"],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft6,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft7 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft7({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string"},
    },
    "required": <Object?>["name"],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft7,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft201909 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft201909({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "https://json-schema.org/draft/2019-09/schema",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string"},
    },
    "required": <Object?>["name"],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft201909,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}

/// Validates the embedded schema with generated boolean checks and diagnostics.
final class GeneratedDraft202012 {
  /// Creates a reusable validator with a lazily compiled diagnostic fallback.
  GeneratedDraft202012({this.options}) : isSpecialized = options == null;

  static const _document = <String, Object?>{
    "\$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "properties": <String, Object?>{
      "name": <String, Object?>{"type": "string"},
    },
    "required": <Object?>["name"],
  };

  /// Options for the runtime backend, or null to use dialect defaults.
  final engine.SchemaOptions? options;
  engine.CompiledSchema? _compiled;
  engine.CompiledSchema get _runtime =>
      _compiled ??= engine.JsonSchema.fromJson(
        _document,
        draft: engine.SchemaDraft.draft202012,
      ).compile(options: options);

  /// Whether the generated boolean backend is active for this instance.
  final bool isSpecialized;

  /// Checks an instance, without constructing diagnostics.
  bool isValid(Object? value) =>
      isSpecialized ? _check0(value) : _runtime.isValid(value);

  /// Returns the first assertion error, or null for a valid instance.
  engine.ValidationError? validate(Object? value) => _runtime.validate(value);

  /// Returns all assertion errors for the instance.
  List<engine.ValidationError> errors(Object? value) => _runtime.errors(value);

  bool _check0(Object? value) {
    if (!((value is Map<Object?, Object?> &&
        (value is Map<String, Object?> ||
            value.keys.every((key) => key is String))))) {
      return false;
    }
    if (!value.containsKey("name")) {
      return false;
    }
    if (value.containsKey("name") && !_check1(value["name"])) {
      return false;
    }
    return true;
  }

  bool _check1(Object? value) {
    if (value is! String) {
      return false;
    }
    return true;
  }
}
