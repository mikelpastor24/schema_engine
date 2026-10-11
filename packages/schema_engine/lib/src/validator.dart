import 'dart:collection';
import 'dart:convert';

import 'draft.dart';
import 'errors.dart';
import 'formats.dart';
import 'json.dart';
import 'json_number.dart';
import 'options.dart';
import 'schema.dart';
import 'validation_error_codes.dart';

part 'compiler.dart';
part 'diagnostics.dart';
part 'meta_schema.dart';
part 'rules.dart';
part 'vocabularies.dart';

/// A compiled, reusable validator whose schema and options are snapshotted.
///
/// [isValid] avoids diagnostic allocations. [validate] returns the first error,
/// and [errors] returns all assertion errors. Validation performs no I/O and
/// never modifies the instance.
final class CompiledSchema {
  CompiledSchema._(
    this._root,
    this.draft,
    this._hasReferences,
    this._messageFormatter,
  );

  /// Compiles [schema] with locally registered resources.
  ///
  /// [baseUri] supplies the retrieval URI for relative references. An explicit
  /// option dialect overrides [JsonSchema.draft]. Invalid schemas throw
  /// [SchemaException]; unresolved references throw [ReferenceException].
  factory CompiledSchema.compile(
    JsonSchema schema, {
    SchemaOptions? options,
    Uri? baseUri,
  }) {
    final compiler = _Compiler(
      options ?? SchemaOptions(),
      schema,
      baseUri ?? Uri.parse('https://schema-engine.invalid/root'),
    );
    return compiler.build();
  }

  /// Loads missing references through [SchemaOptions.resolver] before compiling.
  ///
  /// Each resource is fetched once. A missing resolver or an unresolvable
  /// fragment throws [ReferenceException]. Resolver failures propagate.
  static Future<CompiledSchema> compileAsync(
    JsonSchema schema, {
    SchemaOptions? options,
    Uri? baseUri,
  }) async {
    final selected = options ?? SchemaOptions();
    final resources = Map<Uri, Object?>.of(selected.resources);
    final loaded = <Uri>{...resources.keys};
    while (true) {
      try {
        return CompiledSchema.compile(
          schema,
          baseUri: baseUri,
          options: SchemaOptions(
            draft: selected.draft,
            defaultDraft: selected.defaultDraft,
            assertFormats: selected.assertFormats,
            validateSchema: selected.validateSchema,
            legacyDependencies: selected.legacyDependencies,
            assertContent: selected.assertContent,
            messageFormatter: selected.messageFormatter,
            resources: resources,
            formats: selected.formats,
            keywords: selected.keywords,
            vocabularies: selected.vocabularies,
          ),
        );
      } on ReferenceException catch (error) {
        final uri = error.reference.removeFragment();
        if (selected.resolver == null || !loaded.add(uri)) {
          rethrow;
        }
        resources[uri] = await selected.resolver!(uri);
      }
    }
  }

  final _Node _root;
  final bool _hasReferences;
  final ValidationErrorFormatter? _messageFormatter;

  /// The root schema's effective dialect.
  final SchemaDraft draft;

  /// Checks an instance without constructing diagnostic messages or paths.
  bool isValid(Object? instance) =>
      _root.run(instance, _hasReferences ? _Context() : null);

  /// Returns the first validation error, or null for a valid instance.
  ///
  /// [messageFormatter] overrides the compilation language for this call.
  ValidationError? validate(
    Object? instance, {
    ValidationErrorFormatter? messageFormatter,
  }) {
    final context = _Context(
      firstOnly: true,
      errors: [],
      messageFormatter: messageFormatter ?? _messageFormatter,
    );
    _root.run(instance, context);
    return context.errors!.isEmpty ? null : context.errors!.first;
  }

  /// Returns every failing assertion found during validation.
  ///
  /// Branch alternatives produce a combinator error rather than reporting
  /// failures from branches that the schema does not require to match.
  ///
  /// [messageFormatter] overrides the compilation language for this call.
  List<ValidationError> errors(
    Object? instance, {
    ValidationErrorFormatter? messageFormatter,
  }) {
    final context = _Context(
      errors: [],
      messageFormatter: messageFormatter ?? _messageFormatter,
    );
    _root.run(instance, context);
    return List.unmodifiable(context.errors!);
  }
}

final class _Context {
  _Context({this.errors, this.firstOnly = false, this.messageFormatter});
  final List<ValidationError>? errors;
  final bool firstOnly;
  final ValidationErrorFormatter? messageFormatter;
  String? propertyName;
  final List<(_Node, Object?)> active = [];
  final List<_Resource> scope = [];

  void fail(
    _Entry entry,
    String keyword,
    String path, {
    String? code,
    Object? instance,
    Map<String, Object?> parameters = const {},
  }) {
    if (errors == null) {
      return;
    }
    final pointer = keyword == 'false'
        ? entry.path
        : '${entry.path}/${escapePointer(keyword)}';
    final messageCode = code ?? ValidationErrorCodes.forKeyword(keyword);
    final details = _instanceParameters(
      messageCode,
      instance,
      parameters,
      entry.draft,
    );
    if (propertyName != null) {
      details['propertyName'] = propertyName;
    }
    errors!.add(
      ValidationError(
        keyword: keyword,
        code: messageCode,
        parameters: Map.unmodifiable(details),
        messageFormatter: messageFormatter,
        instancePath: path,
        schemaPath: pointer,
        schemaLocation: entry.resource.uri.replace(fragment: pointer),
      ),
    );
  }
}

final class _Marks {
  final Set<String> properties = {};
  final Set<int> items = {};

  void merge(_Marks other) {
    properties.addAll(other.properties);
    items.addAll(other.items);
  }
}

typedef _Predicate = bool Function(Object? instance);

final class _Test {
  const _Test(
    this.keyword,
    this.predicate,
    this.parameters, {
    required this.code,
  });
  final String keyword;
  final String code;
  final Map<String, Object?> parameters;
  final _Predicate predicate;
}

final class _Resource {
  _Resource(this.uri, this.draft, {this.vocabulary});
  final Uri uri;
  final SchemaDraft draft;
  final Map<String, Object?>? vocabulary;
  final Map<String, _Entry> pointers = {};
  final Map<String, _Entry> anchors = {};
  final Map<String, _Entry> dynamicAnchors = {};
  late _Entry root;
}

final class _Entry {
  _Entry(this.value, this.resource, this.base, this.path, this.draft);
  final Object value;
  final _Resource resource;
  final Uri base;
  final String path;
  final SchemaDraft draft;
}

final class _Node {
  _Node(this.entry);
  final _Entry entry;
  final List<_Test> tests = [];
  final List<_Rule> rules = [];
  _Node? unevaluatedProperties;
  _Node? unevaluatedItems;
  bool alwaysFalse = false;
  _Predicate? _fast;

  void prepareFast() {
    if (unevaluatedProperties != null || unevaluatedItems != null) {
      return;
    }
    if (alwaysFalse) {
      _fast = (_) => false;
      return;
    }
    final predicates = tests.map((test) => test.predicate).toList();
    final _Predicate assertions;
    if (predicates.isEmpty) {
      assertions = (_) => true;
    } else if (predicates.length == 1) {
      assertions = predicates[0];
    } else if (predicates.length == 2) {
      final first = predicates[0];
      final second = predicates[1];
      assertions = (value) => first(value) && second(value);
    } else if (predicates.length == 3) {
      final first = predicates[0];
      final second = predicates[1];
      final third = predicates[2];
      assertions = (value) => first(value) && second(value) && third(value);
    } else {
      assertions = (value) {
        for (final predicate in predicates) {
          if (!predicate(value)) {
            return false;
          }
        }
        return true;
      };
    }
    if (rules.isEmpty) {
      _fast = assertions;
    } else {
      _fast = (value) {
        if (!assertions(value)) {
          return false;
        }
        for (final rule in rules) {
          if (!rule.run(value, null, null, '', false)) {
            return false;
          }
        }
        return true;
      };
    }
  }

  bool run(
    Object? instance,
    _Context? context, {
    _Marks? marks,
    String path = '',
    bool report = true,
  }) {
    if (context == null && marks == null && _fast != null) {
      return _fast!(instance);
    }
    // Only reference-bearing graphs need cycle and dynamic-scope bookkeeping.
    final track =
        context != null && context.errors == null ||
        context != null && rules.any((rule) => rule is _Reference);
    var pushed = false;
    var scopePushed = false;
    if (track) {
      for (final pair in context.active) {
        if (identical(pair.$1, this) && identical(pair.$2, instance)) {
          return true;
        }
      }
      context.active.add((this, instance));
      pushed = true;
    }
    if (context != null &&
        (context.scope.isEmpty || context.scope.last != entry.resource)) {
      context.scope.add(entry.resource);
      scopePushed = true;
    }
    try {
      if (alwaysFalse) {
        if (report && context?.errors != null) {
          context?.fail(
            entry,
            'false',
            path,
            code: ValidationErrorCodes.falseSchema,
          );
        }
        return false;
      }
      var valid = true;
      for (final test in tests) {
        if (!test.predicate(instance)) {
          valid = false;
          if (report && context?.errors != null) {
            context?.fail(
              entry,
              test.keyword,
              path,
              code: test.code,
              instance: instance,
              parameters: test.parameters,
            );
          }
          if (context?.errors == null || !report || context!.firstOnly) {
            return false;
          }
        }
      }
      // An inner unevaluated applicator must not see its caller's annotations.
      final evaluated =
          marks != null ||
              unevaluatedProperties != null ||
              unevaluatedItems != null
          ? _Marks()
          : null;
      for (final rule in rules) {
        if (!rule.run(instance, context, evaluated, path, report)) {
          valid = false;
          if (context?.errors == null || !report || context!.firstOnly) {
            return false;
          }
        }
      }
      if (instance is Map<Object?, Object?> && unevaluatedProperties != null) {
        for (final rawKey in instance.keys) {
          final key = rawKey as String;
          if (!evaluated!.properties.contains(key)) {
            final allowed = unevaluatedProperties!.alwaysFalse
                ? _rejectProperty(
                    unevaluatedProperties!,
                    key,
                    context,
                    _childPath(context, path, key, report),
                    report,
                    code: ValidationErrorCodes.unevaluatedProperties,
                  )
                : unevaluatedProperties!.run(
                    instance[key],
                    context,
                    path: _childPath(context, path, key, report),
                    report: report,
                  );
            if (!allowed) {
              valid = false;
              if (context?.errors == null || !report || context!.firstOnly) {
                return false;
              }
            }
            evaluated.properties.add(key);
          }
        }
      }
      if (instance is List<Object?> && unevaluatedItems != null) {
        for (var i = 0; i < instance.length; i++) {
          if (!evaluated!.items.contains(i)) {
            final allowed = unevaluatedItems!.alwaysFalse
                ? _rejectItem(
                    unevaluatedItems!,
                    i,
                    context,
                    path,
                    report,
                    code: ValidationErrorCodes.unevaluatedItems,
                  )
                : unevaluatedItems!.run(
                    instance[i],
                    context,
                    path: _childPath(context, path, '$i', report),
                    report: report,
                  );
            if (!allowed) {
              valid = false;
              if (context?.errors == null || !report || context!.firstOnly) {
                return false;
              }
            }
            evaluated.items.add(i);
          }
        }
      }
      if (valid && marks != null && evaluated != null) {
        marks.merge(evaluated);
      }
      return valid;
    } finally {
      if (scopePushed) {
        context!.scope.removeLast();
      }
      if (pushed) {
        context!.active.removeLast();
      }
    }
  }
}

String _childPath(_Context? context, String path, String key, bool report) =>
    context?.errors == null || !report ? '' : '$path/${escapePointer(key)}';

abstract class _Rule {
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  );
}
