part of 'schema_editor.dart';

const _unsetEditorValue = Object();
const _countKeywords = {
  'minLength',
  'maxLength',
  'minItems',
  'maxItems',
  'minProperties',
  'maxProperties',
};
const _numberKeywords = {
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'multipleOf',
};
const _jsonKeywords = {'enum', 'const', 'default', 'examples'};
const _editorInputKeywords = {
  r'$id',
  r'$ref',
  'title',
  'description',
  'pattern',
  'format',
  ..._countKeywords,
  ..._numberKeywords,
  ..._jsonKeywords,
};

enum _InputProblem { number, count, multiple, json, array, name }

bool _isEditorNumber(Object? value) =>
    value is num ? value.isFinite : value is BigInt || value is JsonNumber;

JsonNumber _exactEditorNumber(Object value) =>
    value is JsonNumber ? value : JsonNumber.parse(value.toString());

class _EditorInputIssue implements Exception {
  const _EditorInputIssue(this.problem, this.path);

  final _InputProblem problem;
  final String path;
}

Object? _parseEditorInput(String keyword, String text, String path) {
  if (text.isEmpty) {
    if (keyword == r'$ref') {
      return '';
    }
    return _unsetEditorValue;
  }
  if (!_countKeywords.contains(keyword) &&
      !_numberKeywords.contains(keyword) &&
      !_jsonKeywords.contains(keyword)) {
    return text;
  }
  Object? value;
  try {
    var source = text;
    if (_numberKeywords.contains(keyword)) {
      source = source.replaceAll(',', '.');
      if (source.endsWith('.')) {
        source = '${source}0';
      }
    }
    value = decodeJson(source);
  } on FormatException {
    throw _EditorInputIssue(
      _countKeywords.contains(keyword)
          ? _InputProblem.count
          : _numberKeywords.contains(keyword)
          ? _InputProblem.number
          : _InputProblem.json,
      path,
    );
  }
  if (_countKeywords.contains(keyword) &&
      (!_isEditorNumber(value) ||
          !_exactEditorNumber(value!).isInteger ||
          _exactEditorNumber(value).compareTo(JsonNumber.parse('0')) < 0)) {
    throw _EditorInputIssue(_InputProblem.count, path);
  }
  if (_numberKeywords.contains(keyword) && !_isEditorNumber(value)) {
    throw _EditorInputIssue(_InputProblem.number, path);
  }
  if (keyword == 'multipleOf' &&
      _exactEditorNumber(value!).compareTo(JsonNumber.parse('0')) <= 0) {
    throw _EditorInputIssue(_InputProblem.multiple, path);
  }
  if ((keyword == 'enum' || keyword == 'examples') && value is! List) {
    throw _EditorInputIssue(_InputProblem.array, path);
  }
  return value;
}

class _NamedEditorNode {
  _NamedEditorNode(this.name, this.node) : referenceName = name;

  String name;
  String referenceName;
  bool isRequired = false;
  final _EditorNode node;
}

class _EditorNode {
  _EditorNode(Object value)
    : booleanValue = value is bool ? value : null,
      keywords = value is Map<String, Object?>
          ? Map.of(value)
          : <String, Object?>{} {
    for (final (keyword, target) in [
      ('properties', properties),
      (r'$defs', definitions),
    ]) {
      final entries = keywords[keyword];
      if (entries is Map<String, Object?>) {
        for (final entry in entries.entries) {
          target.add(_NamedEditorNode(entry.key, _EditorNode(entry.value!)));
        }
      }
    }
    for (final keyword in ['items', 'additionalProperties']) {
      final value = keywords[keyword];
      if (value is bool || value is Map<String, Object?>) {
        children[keyword] = _EditorNode(value!);
      }
    }
    final required = keywords['required'];
    if (required is List) {
      for (final property in properties) {
        property.isRequired = required.contains(property.name);
      }
      extraRequired.addAll(
        required.whereType<String>().where(
          (name) => !properties.any((property) => property.name == name),
        ),
      );
    }
  }

  bool? booleanValue;
  String? selectedKind;
  final Map<String, Object?> keywords;
  final Map<String, String> edits = {};
  final Map<String, int> revisions = {};
  final List<_NamedEditorNode> properties = [];
  final List<_NamedEditorNode> definitions = [];
  final List<String> extraRequired = [];
  final Map<String, _EditorNode> children = {};

  void replaceFrom(_EditorNode source) {
    // Keep node identities at unchanged schema locations so widget state survives.
    for (final keyword in _editorInputKeywords) {
      if (inputText(keyword) != source.inputText(keyword)) {
        revisions.update(keyword, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    booleanValue = source.booleanValue;
    selectedKind = null;
    keywords
      ..clear()
      ..addAll(source.keywords);
    edits.clear();
    extraRequired
      ..clear()
      ..addAll(source.extraRequired);

    void replaceEntries(
      List<_NamedEditorNode> target,
      List<_NamedEditorNode> incoming,
    ) {
      final previous = {for (final entry in target) entry.name: entry};
      target.clear();
      for (final entry in incoming) {
        final retained = previous[entry.name];
        if (retained == null) {
          target.add(entry);
        } else {
          retained.referenceName = entry.referenceName;
          retained.isRequired = entry.isRequired;
          retained.node.replaceFrom(entry.node);
          target.add(retained);
        }
      }
    }

    replaceEntries(properties, source.properties);
    replaceEntries(definitions, source.definitions);
    children.removeWhere((keyword, _) => !source.children.containsKey(keyword));
    for (final entry in source.children.entries) {
      final retained = children[entry.key];
      if (retained == null) {
        children[entry.key] = entry.value;
      } else {
        retained.replaceFrom(entry.value);
      }
    }
  }

  String get kind {
    if (selectedKind != null) {
      return selectedKind!;
    }
    if (booleanValue == false) {
      return 'never';
    }
    if (keywords.containsKey(r'$ref')) {
      return 'reference';
    }
    final type = keywords['type'];
    if (type is String) {
      return type;
    }
    if (type is List) {
      final nonNull = type.where((item) => item != 'null').toList();
      if (nonNull.isEmpty) {
        return 'null';
      }
      if (nonNull.length == 1) {
        return nonNull.single! as String;
      }
      return 'multiple';
    }
    // Infer controls, but keep an omitted type absent from the generated JSON.
    if (keywords.containsKey('properties')) {
      return 'object';
    }
    if (keywords.containsKey('items')) {
      return 'array';
    }
    return 'any';
  }

  bool get nullable =>
      keywords['type'] is List && (keywords['type']! as List).contains('null');

  void chooseKind(String kind, String? reference) {
    selectedKind = kind;
    booleanValue = kind == 'never' ? false : null;
    edits.remove(r'$ref');
    keywords.remove(r'$ref');
    if (kind == 'any' || kind == 'never' || kind == 'reference') {
      keywords.remove('type');
      if (kind == 'reference') {
        keywords[r'$ref'] = reference ?? '#';
        edits[r'$ref'] = reference ?? '#';
      }
    } else {
      keywords['type'] = kind;
      if (kind == 'array') {
        children.putIfAbsent('items', () => _EditorNode({'type': 'string'}));
      }
    }
  }

  void setNullable(bool value) {
    keywords['type'] = value ? [kind, 'null'] : kind;
  }

  String inputText(String keyword) {
    if (edits.containsKey(keyword)) {
      return edits[keyword]!;
    }
    final value = keywords[keyword];
    if (!keywords.containsKey(keyword)) {
      return '';
    }
    return _jsonKeywords.contains(keyword) ||
            _numberKeywords.contains(keyword) ||
            _countKeywords.contains(keyword)
        ? encodeJson(value)
        : value.toString();
  }

  Object toJson(String path) {
    if (booleanValue != null) {
      return booleanValue!;
    }
    final result = <String, Object?>{...keywords};
    for (final entry in edits.entries) {
      final value = _parseEditorInput(
        entry.key,
        entry.value,
        '$path/${_editorEscape(entry.key)}',
      );
      if (identical(value, _unsetEditorValue)) {
        result.remove(entry.key);
      } else {
        result[entry.key] = value;
      }
    }
    for (final (keyword, source) in [
      ('properties', properties),
      (r'$defs', definitions),
    ]) {
      if (source.isNotEmpty || keywords.containsKey(keyword)) {
        final names = <String>{};
        final entries = <String, Object?>{};
        for (final entry in source) {
          if (!names.add(entry.name)) {
            throw _EditorInputIssue(_InputProblem.name, '$path/$keyword');
          }
          entries[entry.name] = entry.node.toJson(
            '$path/$keyword/${_editorEscape(entry.name)}',
          );
        }
        result[keyword] = entries;
      }
    }
    for (final entry in children.entries) {
      result[entry.key] = entry.value.toJson('$path/${entry.key}');
    }
    final required = [
      ...extraRequired,
      for (final property in properties)
        if (property.isRequired) property.name,
    ];
    if (required.isNotEmpty || keywords.containsKey('required')) {
      result['required'] = required;
    }
    return result;
  }
}

String _editorEscape(String token) =>
    token.replaceAll('~', '~0').replaceAll('/', '~1');

String _editorReference(String pointer) {
  // Encode literal percent signs before retaining pointer separators.
  final fragment = Uri.encodeComponent(pointer)
      .replaceAll('%2F', '/')
      .replaceAll('%24', r'$');
  return '#$fragment';
}

String _definitionReference(String name) =>
    _editorReference('/\$defs/${_editorEscape(name)}');

// Visit schema positions only: defaults and enum entries are instance data.
void _rewriteEditorReferences(
  Map<String, Object?> schema,
  String oldRef,
  String newRef,
) {
  for (final keyword in [r'$ref', r'$dynamicRef']) {
    final reference = schema[keyword];
    if (reference is! String) {
      continue;
    }
    final uri = Uri.tryParse(reference);
    String fragment;
    try {
      fragment = uri == null ? '' : Uri.decodeComponent(uri.fragment);
    } on FormatException {
      // Keep malformed reference text editable while another field changes.
      continue;
    }
    final oldFragment = Uri.decodeComponent(Uri.parse(oldRef).fragment);
    if (uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        uri.path.isEmpty &&
        !uri.hasQuery &&
        (fragment == oldFragment || fragment.startsWith('$oldFragment/'))) {
      schema[keyword] = _editorReference(
        Uri.decodeComponent(Uri.parse(newRef).fragment) +
            fragment.substring(oldFragment.length),
      );
    }
  }
  Object? visit(Object? value) {
    if (value is Map<String, Object?> && !value.containsKey(r'$id')) {
      final copy = Map<String, Object?>.of(value);
      _rewriteEditorReferences(copy, oldRef, newRef);
      return copy;
    }
    return value;
  }

  for (final keyword in [
    r'$defs',
    'properties',
    'patternProperties',
    'dependentSchemas',
  ]) {
    final values = schema[keyword];
    if (values is Map<String, Object?>) {
      schema[keyword] = {
        for (final entry in values.entries) entry.key: visit(entry.value),
      };
    }
  }
  for (final keyword in ['allOf', 'anyOf', 'oneOf', 'prefixItems']) {
    final values = schema[keyword];
    if (values is List) {
      schema[keyword] = [for (final value in values) visit(value)];
    }
  }
  for (final keyword in [
    'items',
    'contains',
    'additionalProperties',
    'propertyNames',
    'unevaluatedProperties',
    'unevaluatedItems',
    'not',
    'if',
    'then',
    'else',
    'contentSchema',
  ]) {
    if (schema.containsKey(keyword)) {
      schema[keyword] = visit(schema[keyword]);
    }
  }
}
