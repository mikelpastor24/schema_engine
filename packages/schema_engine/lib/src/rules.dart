part of 'validator.dart';

final class _Reference extends _Rule {
  _Reference(this.target, {this.dynamicAnchor, this.recursive = false});
  final _Node target;
  final String? dynamicAnchor;
  final bool recursive;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    var selected = target;
    if (dynamicAnchor != null &&
        target.entry.resource.dynamicAnchors[dynamicAnchor] == target.entry) {
      for (final resource in context!.scope) {
        final anchor = resource.dynamicAnchors[dynamicAnchor];
        if (anchor != null) {
          selected = _compiledEntries[anchor] ?? target;
          break;
        }
      }
    } else if (recursive && _recursiveAnchor(target.entry.resource)) {
      for (final resource in context!.scope.reversed) {
        if (!_recursiveAnchor(resource)) {
          break;
        }
        selected = _compiledEntries[resource.root] ?? target;
      }
    }
    return selected.run(
      instance,
      context,
      marks: marks,
      path: path,
      report: report,
    );
  }
}

// Expando keys are collected with their owning compiled graph; this is not a
// process-wide retaining cache. Dynamic anchors point to the same graph nodes.
final Expando<_Node> _compiledEntries = Expando<_Node>();

bool _recursiveAnchor(_Resource resource) =>
    resource.root.value is Map<String, Object?> &&
    (resource.root.value as Map<String, Object?>)[r'$recursiveAnchor'] == true;

final class _Properties extends _Rule {
  _Properties(
    this.entry,
    this.properties,
    this.patterns,
    this.additional,
    this.names,
    this.required,
  ) : lookups = properties.entries.toList();
  final _Entry entry;
  final Map<String, _Node> properties;
  final List<MapEntry<String, _Node>> lookups;
  final List<(RegExp, _Node)> patterns;
  final _Node? additional;
  final _Node? names;
  final List<String> required;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    if (instance is! Map<Object?, Object?>) {
      return true;
    }
    var valid = true;
    bool stop() => context?.errors == null || !report || context!.firstOnly;
    for (final key in required) {
      if (!instance.containsKey(key)) {
        valid = false;
        if (report && context?.errors != null) {
          context?.fail(
            entry.draft.isLegacy ? properties[key]!.entry : entry,
            entry.draft.isLegacy && entry.draft != SchemaDraft.draft3
                ? 'optional'
                : 'required',
            path,
            parameters: {'property': key},
          );
        }
        if (stop()) {
          return false;
        }
      }
    }
    // Direct lookups avoid walking unconstrained instance keys on common schemas.
    for (final property in lookups) {
      final value = instance[property.key];
      if (value == null && !instance.containsKey(property.key)) {
        continue;
      }
      if (!property.value.run(
        value,
        context,
        path: _childPath(context, path, property.key, report),
        report: report,
      )) {
        valid = false;
        if (stop()) {
          return false;
        }
      }
      marks?.properties.add(property.key);
    }
    if (patterns.isEmpty && additional == null && names == null) {
      return valid;
    }
    for (final rawKey in instance.keys) {
      final key = rawKey as String;
      final childPath = _childPath(context, path, key, report);
      if (names != null &&
          !_validPropertyName(key, context, childPath, report)) {
        valid = false;
        if (stop()) {
          return false;
        }
      }
      var covered = properties.containsKey(key);
      for (final pattern in patterns) {
        if (pattern.$1.hasMatch(key)) {
          covered = true;
          marks?.properties.add(key);
          if (!pattern.$2.run(
            instance[key],
            context,
            path: childPath,
            report: report,
          )) {
            valid = false;
            if (stop()) {
              return false;
            }
          }
        }
      }
      if (!covered && additional != null) {
        marks?.properties.add(key);
        final allowed = additional!.alwaysFalse
            ? _rejectProperty(additional!, key, context, childPath, report)
            : additional!.run(
                instance[key],
                context,
                path: childPath,
                report: report,
              );
        if (!allowed) {
          valid = false;
          if (stop()) {
            return false;
          }
        }
      }
    }
    return valid;
  }

  bool _validPropertyName(
    String key,
    _Context? context,
    String path,
    bool report,
  ) {
    final previous = context?.propertyName;
    if (report && context?.errors != null) {
      context!.propertyName = key;
    }
    try {
      return names!.run(key, context, path: path, report: report);
    } finally {
      if (context != null) {
        context.propertyName = previous;
      }
    }
  }
}

final class _Items extends _Rule {
  _Items(this.prefix, this.rest);
  final List<_Node> prefix;
  final _Node? rest;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    if (instance is! List<Object?>) {
      return true;
    }
    var valid = true;
    for (var i = 0; i < instance.length; i++) {
      final node = i < prefix.length ? prefix[i] : rest;
      if (node == null) {
        break;
      }
      marks?.items.add(i);
      final allowed = node.alwaysFalse && i >= prefix.length
          ? _rejectItem(node, i, context, path, report, limit: prefix.length)
          : node.run(
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
    }
    return valid;
  }
}

final class _Contains extends _Rule {
  _Contains(this.entry, this.child, this.minimum, this.maximum, this.annotates);
  final _Entry entry;
  final _Node child;
  final Object minimum;
  final Object? maximum;
  final bool annotates;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    if (instance is! List<Object?>) {
      return true;
    }
    var count = 0;
    for (var i = 0; i < instance.length; i++) {
      if (child.run(instance[i], context, report: false)) {
        count++;
        if (annotates) {
          marks?.items.add(i);
        }
        if (maximum == null &&
            compareNumbers(count, minimum) >= 0 &&
            (marks == null || !annotates)) {
          return true;
        }
      }
      if (maximum != null && compareNumbers(count, maximum!) > 0) {
        break;
      }
    }
    final valid =
        compareNumbers(count, minimum) >= 0 &&
        (maximum == null || compareNumbers(count, maximum!) <= 0);
    if (!valid && report && context?.errors != null) {
      context?.fail(
        entry,
        'contains',
        path,
        parameters: {
          'minimum': minimum,
          'maximum': maximum,
          'matches': count,
          'reason': maximum != null && compareNumbers(count, maximum!) > 0
              ? 'tooMany'
              : 'tooFew',
        },
      );
    }
    return valid;
  }
}

final class _Combination extends _Rule {
  _Combination(
    this.entry,
    this.keyword,
    this.children, {
    String? errorKeyword,
    this.parameters = const {},
  }) : errorKeyword = errorKeyword ?? keyword;
  final _Entry entry;
  final String keyword;
  final String errorKeyword;
  final Map<String, Object?> parameters;
  final List<_Node> children;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    if (keyword == 'allOf' || keyword == 'extends') {
      var valid = true;
      for (final child in children) {
        if (!child.run(
          instance,
          context,
          marks: marks,
          path: path,
          report: report,
        )) {
          valid = false;
          if (context?.errors == null || !report || context!.firstOnly) {
            return false;
          }
        }
      }
      return valid;
    }
    var matches = 0;
    _Marks? collected;
    for (final child in children) {
      final branch = marks == null ? null : _Marks();
      if (child.run(instance, context, marks: branch, report: false)) {
        matches++;
        if (branch != null) {
          (collected ??= _Marks()).merge(branch);
        }
        if (keyword == 'anyOf' && marks == null) {
          return true;
        }
        if (keyword == 'oneOf' && matches > 1 || keyword == 'not') {
          break;
        }
      }
    }
    final valid = keyword == 'not'
        ? matches == 0
        : keyword == 'oneOf'
        ? matches == 1
        : matches > 0;
    if (valid && collected != null && keyword != 'not') {
      marks!.merge(collected);
    }
    if (!valid && report && context?.errors != null) {
      context?.fail(
        entry,
        errorKeyword,
        path,
        instance: instance,
        parameters: {
          ...parameters,
          'branchCount': children.length,
          'matches': matches,
        },
      );
    }
    return valid;
  }
}

final class _Conditional extends _Rule {
  _Conditional(this.condition, this.thenNode, this.elseNode);
  final _Node condition;
  final _Node? thenNode;
  final _Node? elseNode;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    final conditionMarks = marks == null ? null : _Marks();
    final matched = condition.run(
      instance,
      context,
      marks: conditionMarks,
      report: false,
    );
    if (matched && conditionMarks != null) {
      marks!.merge(conditionMarks);
    }
    final branch = matched ? thenNode : elseNode;
    return branch == null ||
        branch.run(instance, context, marks: marks, path: path, report: report);
  }
}

final class _Dependencies extends _Rule {
  _Dependencies(
    this.entry,
    this.required,
    this.schemas,
    this.keyword, {
    this.requiredEntries = const {},
  });
  final _Entry entry;
  final Map<String, List<String>> required;
  final Map<String, _Node> schemas;
  final String keyword;
  final Map<String, _Entry> requiredEntries;

  @override
  bool run(
    Object? instance,
    _Context? context,
    _Marks? marks,
    String path,
    bool report,
  ) {
    if (instance is! Map<Object?, Object?>) {
      return true;
    }
    var valid = true;
    for (final dependency in required.entries) {
      if (!instance.containsKey(dependency.key)) {
        continue;
      }
      for (final name in dependency.value) {
        if (!instance.containsKey(name)) {
          valid = false;
          if (report && context?.errors != null) {
            context?.fail(
              requiredEntries[dependency.key] ?? entry,
              keyword,
              path,
              parameters: {'property': dependency.key, 'missingProperty': name},
            );
          }
          if (context?.errors == null || !report || context!.firstOnly) {
            return false;
          }
        }
      }
    }
    for (final dependency in schemas.entries) {
      if (instance.containsKey(dependency.key) &&
          !dependency.value.run(
            instance,
            context,
            marks: marks,
            path: path,
            report: report,
          )) {
        valid = false;
        if (context?.errors == null || !report || context!.firstOnly) {
          return false;
        }
      }
    }
    return valid;
  }
}
