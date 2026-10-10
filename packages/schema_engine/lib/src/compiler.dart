part of 'validator.dart';

final class _Compiler {
  _Compiler(
    this.options,
    this.schema,
    this.base, {
    this.checkCustomMetaSchemas = true,
  }) : documents = {
         for (final resource in options.resources.entries)
           resource.key.removeFragment(): freezeJson(resource.value),
       };
  final SchemaOptions options;
  final JsonSchema schema;
  final Uri base;
  final bool checkCustomMetaSchemas;
  final Map<Uri, Object?> documents;
  final Map<Uri, _Resource> resources = {};
  final Map<Uri, _Entry> identifiers = {};
  final Map<Object, _Entry> entries = HashMap.identity();
  final Map<_Entry, _Node> nodes = HashMap.identity();
  bool hasReferences = false;

  CompiledSchema build() {
    final rootDraft = options.draft ?? schema.draft;
    final root = index(
      schema.value,
      base.removeFragment(),
      '',
      rootDraft,
      null,
    );
    for (final resource in documents.entries) {
      final value = resource.value;
      if (value is! Map<String, Object?> && value is! bool) {
        throw const SchemaException('A resource must be a schema.');
      }
      index(
        value!,
        resource.key.removeFragment(),
        '',
        options.defaultDraft ?? rootDraft,
        null,
      );
    }
    final node = compile(root);
    if (options.validateSchema && checkCustomMetaSchemas) {
      validateCustomMetaSchemas();
    }
    // Dynamic scope can reach anchors that are not statically referenced.
    for (final resource in resources.values.toSet().toList()) {
      for (final anchor in resource.dynamicAnchors.values) {
        compile(anchor);
      }
      if (_recursiveAnchor(resource)) {
        compile(resource.root);
      }
    }
    final needsContext = hasReferences && _requiresContext(node);
    if (!needsContext) {
      for (final compiled in nodes.values) {
        compiled.prepareFast();
      }
    }
    return CompiledSchema._(node, rootDraft, needsContext);
  }

  _Entry index(
    Object value,
    Uri baseUri,
    String path,
    SchemaDraft inherited,
    _Resource? parent,
  ) {
    var dialect = inherited;
    var resolved = baseUri;
    if (value is Map<String, Object?>) {
      final declared = value[r'$schema'];
      if (options.validateSchema && declared is String) {
        _checkSchemaUri(declared, r'$schema', path, absolute: true);
      }
      if (declared is String &&
          !(parent == null && identical(value, schema.value))) {
        dialect = dialectFor(declared);
      }
      final idKeyword = dialect.index < SchemaDraft.draft6.index
          ? 'id'
          : r'$id';
      final id = value[idKeyword];
      if (id is String &&
          !(dialect.index <= SchemaDraft.draft7.index &&
              value.containsKey(r'$ref'))) {
        if (options.validateSchema) {
          _checkSchemaUri(
            id,
            idKeyword,
            path,
            noFragment: dialect.supportsVocabularies,
          );
        }
        resolved = baseUri.resolve(id);
      }
    }
    var resource = parent;
    var resourcePath = path;
    if (parent == null ||
        resolved.removeFragment() != parent.uri && resolved.fragment.isEmpty) {
      Map<String, Object?>? vocabulary;
      if (value is Map<String, Object?> &&
          value[r'$schema'] is String &&
          !(parent == null &&
              identical(value, schema.value) &&
              options.draft != null)) {
        final meta = registeredMetaSchema(
          Uri.parse(value[r'$schema']! as String).removeFragment(),
        )?.$1;
        if (meta == null) {
          try {
            SchemaDraft.fromUri(value[r'$schema']! as String);
          } on FormatException {
            throw ReferenceException(
              Uri.parse(value[r'$schema']! as String).removeFragment(),
              'No meta-schema is registered for this custom dialect.',
            );
          }
        }
        if (meta is Map<String, Object?> &&
            meta[r'$vocabulary'] is Map<String, Object?>) {
          vocabulary = Map.unmodifiable({
            for (final item
                in (meta[r'$vocabulary']! as Map<String, Object?>).entries)
              Uri.parse(item.key).toString(): item.value,
          });
          for (final item in vocabulary.entries) {
            final uri = Uri.parse(item.key);
            if (item.value == true &&
                !options.vocabularies.contains(uri) &&
                !_knownVocabulary(uri, dialect)) {
              throw SchemaException('Unsupported required vocabulary: $uri.');
            }
          }
        }
      }
      resource = _Resource(
        resolved.removeFragment(),
        dialect,
        vocabulary: vocabulary,
      );
      resources[resource.uri] = resource;
      resourcePath = '';
    }
    if (options.validateSchema &&
        parent != null &&
        resource == parent &&
        (dialect.supportsVocabularies || parent.draft.supportsVocabularies) &&
        value is Map<String, Object?>) {
      for (final keyword in [r'$schema', r'$vocabulary']) {
        if (value.containsKey(keyword)) {
          throw SchemaException(
            '$keyword is only allowed at a resource root.',
            schemaPath: '$path/${escapePointer(keyword)}',
          );
        }
      }
    }
    final entry = _Entry(value, resource!, resolved, resourcePath, dialect);
    if (resourcePath.isEmpty) {
      resource.root = entry;
      if (parent == null) {
        resources[baseUri.removeFragment()] = resource;
      }
    }
    resource.pointers[resourcePath] = entry;
    if (parent != null && parent != resource) {
      parent.pointers[path] = entry;
    }
    if (value is Map<String, Object?>) {
      entries[value] = entry;
      final id =
          value[dialect.index < SchemaDraft.draft6.index ? 'id' : r'$id'];
      if (id is String &&
          !(dialect.index <= SchemaDraft.draft7.index &&
              value.containsKey(r'$ref'))) {
        identifiers[resolved] = entry;
        if (resolved.fragment.isNotEmpty) {
          resource.anchors[resolved.fragment] = entry;
        }
      }
      if (dialect.supportsVocabularies && value[r'$anchor'] is String) {
        resource.anchors[value[r'$anchor']! as String] = entry;
      }
      if (dialect == SchemaDraft.draft202012 &&
          value[r'$dynamicAnchor'] is String) {
        final anchor = value[r'$dynamicAnchor']! as String;
        resource.anchors[anchor] = entry;
        resource.dynamicAnchors[anchor] = entry;
      }
      for (final child in childSchemas(
        _semanticMap(value, resource),
        dialect,
      )) {
        final indexed = index(
          child.$2,
          resolved,
          '$resourcePath/${child.$1}',
          dialect,
          resource,
        );
        if (parent != null && parent != resource) {
          parent.pointers['$path/${child.$1}'] = indexed;
        }
      }
    }
    return entry;
  }

  Iterable<(String, Object)> childSchemas(
    Map<String, Object?> map,
    SchemaDraft draft,
  ) sync* {
    final maps = <String>{
      'properties',
      if (!draft.isLegacy) 'definitions',
      if (draft.index >= SchemaDraft.draft3.index) 'patternProperties',
      if (draft.supportsVocabularies) ...[r'$defs', 'dependentSchemas'],
    };
    for (final keyword in maps) {
      final value = map[keyword];
      if (value is Map<String, Object?>) {
        for (final item in value.entries) {
          if (item.value is Map<String, Object?> || item.value is bool) {
            yield ('$keyword/${escapePointer(item.key)}', item.value!);
          }
        }
      }
    }
    final singles = <String>{
      'additionalProperties',
      'items',
      if (draft.index >= SchemaDraft.draft3.index &&
          draft != SchemaDraft.draft202012)
        'additionalItems',
      if (!draft.isLegacy) 'not',
      if (draft.index >= SchemaDraft.draft6.index) ...[
        'contains',
        'propertyNames',
      ],
      if (draft.index >= SchemaDraft.draft7.index) ...['if', 'then', 'else'],
      if (draft.supportsVocabularies) ...[
        'unevaluatedProperties',
        'unevaluatedItems',
        'contentSchema',
      ],
    };
    for (final keyword in singles) {
      final value = map[keyword];
      if (value is Map<String, Object?> || value is bool) {
        yield (keyword, value!);
      }
    }
    final lists = <String>{
      if (draft != SchemaDraft.draft202012) 'items',
      if (draft == SchemaDraft.draft202012) 'prefixItems',
      if (!draft.isLegacy) ...['allOf', 'anyOf', 'oneOf'],
      if (draft.isLegacy) ...['extends', 'type', 'disallow'],
    };
    for (final keyword in lists) {
      final value = map[keyword];
      if (value is List<Object?>) {
        for (var i = 0; i < value.length; i++) {
          if (value[i] is Map<String, Object?> || value[i] is bool) {
            yield ('$keyword/$i', value[i]!);
          }
        }
      } else if (draft.isLegacy && value is Map<String, Object?>) {
        yield (keyword, value);
      }
    }
    if (draft.index >= SchemaDraft.draft3.index &&
        (!draft.supportsVocabularies || options.legacyDependencies)) {
      final dependencies = map['dependencies'];
      if (dependencies is Map<String, Object?>) {
        for (final item in dependencies.entries) {
          if (item.value is Map<String, Object?> || item.value is bool) {
            yield ('dependencies/${escapePointer(item.key)}', item.value!);
          }
        }
      }
    }
    if (draft.index < SchemaDraft.draft3.index &&
        map['requires'] is Map<String, Object?>) {
      yield ('requires', map['requires']!);
    }
  }

  SchemaDraft dialectFor(String identifier) {
    final seen = <String>{};
    var current = identifier;
    while (seen.add(current)) {
      try {
        return SchemaDraft.fromUri(current);
      } on FormatException {
        final meta = registeredMetaSchema(Uri.parse(current).removeFragment())
            ?.$1;
        if (meta is Map<String, Object?> && meta[r'$schema'] is String) {
          current = meta[r'$schema']! as String;
        } else {
          throw ReferenceException(
            Uri.parse(current),
            'No meta-schema is registered for this custom dialect.',
          );
        }
      }
    }
    throw SchemaException('Cyclic meta-schema declarations: $identifier.');
  }

  (Object?, Uri)? registeredMetaSchema(Uri identifier) {
    if (documents.containsKey(identifier)) {
      return (documents[identifier], identifier);
    }
    for (final document in documents.entries) {
      final value = document.value;
      if (value is Map<String, Object?>) {
        final id = value[r'$id'] ?? value['id'];
        if (id is String &&
            document.key.resolve(id).removeFragment() == identifier) {
          return (value, document.key);
        }
      }
    }
    return null;
  }

  void validateCustomMetaSchemas() {
    final validators = <Uri, CompiledSchema>{};
    for (final resource in resources.values.toSet().toList()) {
      final value = resource.root.value;
      if (value is! Map<String, Object?> ||
          value[r'$schema'] is! String ||
          identical(value, schema.value) && options.draft != null) {
        continue;
      }
      final identifier = value[r'$schema']! as String;
      try {
        SchemaDraft.fromUri(identifier);
        continue;
      } on FormatException {
        // A custom dialect may impose constraints beyond keyword syntax.
      }
      final uri = Uri.parse(identifier).removeFragment();
      final document = registeredMetaSchema(uri);
      if (document == null) {
        throw ReferenceException(uri, 'No custom meta-schema is registered.');
      }
      final metadata = document.$1;
      final metaDraft =
          metadata is Map<String, Object?> && metadata[r'$schema'] is String
          ? dialectFor(metadata[r'$schema']! as String)
          : resource.draft;
      final validator = validators.putIfAbsent(
        uri,
        () => _Compiler(
          SchemaOptions(
            defaultDraft: options.defaultDraft,
            resources: documents,
            formats: options.formats,
            keywords: options.keywords,
            vocabularies: options.vocabularies,
          ),
          JsonSchema.fromJson(metadata, draft: metaDraft),
          document.$2,
          checkCustomMetaSchemas: false,
        ).build(),
      );
      final error = validator.validate(value);
      if (error != null) {
        throw SchemaException(
          'The schema does not conform to $uri: ${error.message}',
          schemaPath: error.instancePath,
        );
      }
    }
  }

  _Entry resolve(_Entry from, String reference) {
    final uri = from.base.resolve(reference);
    final exact = identifiers[uri];
    if (exact != null) {
      return exact;
    }
    if (from.draft.isLegacy) {
      final root = from.resource.root;
      final definitions = root.value is Map<String, Object?>
          ? (root.value as Map<String, Object?>)['definitions']
          : null;
      if (definitions is Map<String, Object?>) {
        for (final definition in definitions.entries) {
          final value = definition.value;
          if (value is Map<String, Object?> &&
              value['id'] is String &&
              root.base.resolve(value['id']! as String) == uri) {
            return index(
              value,
              root.base,
              '/definitions/${escapePointer(definition.key)}',
              root.draft,
              root.resource,
            );
          }
        }
      }
    }
    var resource = resources[uri.removeFragment()];
    if (resource == null) {
      final metadata = _builtInMetaSchema(uri.removeFragment());
      if (metadata != null) {
        final value = freezeJson(metadata)!;
        final indexed = index(
          value,
          uri.removeFragment(),
          '',
          SchemaDraft.draft202012,
          null,
        );
        resource = indexed.resource;
      }
    }
    if (resource == null) {
      throw ReferenceException(uri, 'No resource is registered for this URI.');
    }
    final fragment = Uri.decodeComponent(uri.fragment);
    if (fragment.isEmpty) {
      return resource.root;
    }
    if (!fragment.startsWith('/')) {
      final anchor = resource.anchors[fragment];
      if (anchor != null) {
        return anchor;
      }
      throw ReferenceException(uri, 'The anchor does not exist.');
    }
    final known = resource.pointers[fragment];
    if (known != null) {
      return known;
    }
    Object? value = resource.root.value;
    var pointer = '';
    var nearest = resource.root;
    for (final segment in fragment.substring(1).split('/')) {
      if (_pointerEscapePattern.hasMatch(segment)) {
        throw ReferenceException(uri, 'Invalid JSON Pointer escape.');
      }
      final key = segment.replaceAll('~1', '/').replaceAll('~0', '~');
      if (value is Map<String, Object?> && value.containsKey(key)) {
        value = value[key];
      } else if (value is List<Object?> && _pointerIndexPattern.hasMatch(key)) {
        final i = int.tryParse(key);
        if (i == null || i >= value.length) {
          throw ReferenceException(uri, 'Array index is out of range.');
        }
        value = value[i];
      } else {
        throw ReferenceException(uri, 'JSON Pointer target does not exist.');
      }
      pointer += '/$segment';
      nearest = resource.pointers[pointer] ?? nearest;
    }
    if (value is! Map<String, Object?> && value is! bool) {
      throw ReferenceException(uri, 'JSON Pointer target is not a schema.');
    }
    final entry = _Entry(
      value!,
      resource,
      nearest.base,
      fragment,
      nearest.draft,
    );
    resource.pointers[fragment] = entry;
    return entry;
  }

  _Node child(_Entry parent, String keyword, Object? value, [String? name]) {
    final suffix = name == null ? keyword : '$keyword/${escapePointer(name)}';
    final entry = value is Map<String, Object?> ? entries[value] : null;
    return compile(
      entry ??
          _Entry(
            value!,
            parent.resource,
            parent.base,
            '${parent.path}/$suffix',
            parent.draft,
          ),
    );
  }

  _Node compile(_Entry entry) {
    final previous = nodes[entry];
    if (previous != null) {
      return previous;
    }
    final node = _Node(entry);
    nodes[entry] = node;
    _compiledEntries[entry] = node;
    final source = entry.value;
    final value = source is Map<String, Object?>
        ? _semanticMap(source, entry.resource)
        : source;
    if (value is bool) {
      if (!entry.draft.supportsBooleanSchemas &&
          !(entry.path.endsWith('/additionalProperties') ||
              entry.path.endsWith('/additionalItems'))) {
        throw SchemaException(
          'Boolean schemas are not allowed in this dialect.',
          schemaPath: entry.path,
        );
      }
      node.alwaysFalse = !value;
      return node;
    }
    if (value is! Map<String, Object?>) {
      throw SchemaException(
        'A schema must be an object or boolean.',
        schemaPath: entry.path,
      );
    }
    if (options.validateSchema) {
      checkSyntax(entry, value);
    }
    final draft = entry.draft;
    final ref = value[r'$ref'];
    if (ref is String) {
      hasReferences = true;
      node.rules.add(_Reference(compile(resolve(entry, ref))));
      if (!draft.supportsVocabularies) {
        return node;
      }
    }
    if (draft == SchemaDraft.draft202012 && value[r'$dynamicRef'] is String) {
      hasReferences = true;
      final reference = value[r'$dynamicRef']! as String;
      node.rules.add(
        _Reference(
          compile(resolve(entry, reference)),
          dynamicAnchor: entry.base.resolve(reference).fragment,
        ),
      );
    }
    if (draft == SchemaDraft.draft201909 && value[r'$recursiveRef'] is String) {
      hasReferences = true;
      node.rules.add(
        _Reference(
          compile(resolve(entry, value[r'$recursiveRef']! as String)),
          recursive: true,
        ),
      );
    }
    void test(String keyword, _Predicate predicate, [String? message]) =>
        node.tests.add(
          _Test(keyword, message ?? 'The instance fails $keyword.', predicate),
        );
    final type = value['type'];
    if (type != null) {
      final alternatives = type is List<Object?> ? type : [type];
      final strings = alternatives.whereType<String>().toList();
      final schemas = alternatives.whereType<Map<String, Object?>>().toList();
      if (schemas.isNotEmpty && draft.isLegacy) {
        final branches = <_Node>[];
        for (final name in strings) {
          final branch = _Node(entry)
            ..tests.add(
              _Test(
                'type',
                'Unexpected type.',
                (instance) => _matchesType(instance, name, draft),
              ),
            );
          branches.add(branch);
        }
        for (final schema in schemas) {
          branches.add(child(entry, 'type', schema));
        }
        node.rules.add(_Combination(entry, 'anyOf', branches));
      } else {
        test(
          'type',
          strings.length == 1
              ? _typePredicate(strings.single, draft)
              : (instance) =>
                    strings.any((name) => _matchesType(instance, name, draft)),
          'The instance has an unexpected type.',
        );
      }
    }
    if (value.containsKey('enum')) {
      final choices = value['enum']! as List<Object?>;
      test(
        'enum',
        (instance) => choices.any((choice) => jsonEquals(choice, instance)),
      );
    }
    if (draft.index >= SchemaDraft.draft6.index && value.containsKey('const')) {
      final constant = value['const'];
      test('const', (instance) => jsonEquals(instance, constant));
    }
    for (final keyword in ['minimum', 'maximum']) {
      final bound = value[keyword];
      if (isJsonNumber(bound)) {
        final lower = keyword == 'minimum';
        final exclusive = draft.index < SchemaDraft.draft3.index
            ? value[lower ? 'minimumCanEqual' : 'maximumCanEqual'] == false
            : draft.index < SchemaDraft.draft6.index &&
                  value[lower ? 'exclusiveMinimum' : 'exclusiveMaximum'] ==
                      true;
        test(
          keyword,
          (instance) => (instance is num && bound is num
              ? (lower
                    ? (exclusive ? instance > bound : instance >= bound)
                    : (exclusive ? instance < bound : instance <= bound))
              : !isJsonNumber(instance) ||
                    _boundMatches(
                      instance!,
                      bound!,
                      lower: lower,
                      exclusive: exclusive,
                    )),
        );
      }
    }
    if (draft.index >= SchemaDraft.draft6.index) {
      for (final keyword in ['exclusiveMinimum', 'exclusiveMaximum']) {
        final bound = value[keyword];
        if (isJsonNumber(bound)) {
          test(
            keyword,
            (instance) => (instance is num && bound is num
                ? (keyword == 'exclusiveMinimum'
                      ? instance > bound
                      : instance < bound)
                : !isJsonNumber(instance) ||
                      _boundMatches(
                        instance!,
                        bound!,
                        lower: keyword == 'exclusiveMinimum',
                        exclusive: true,
                      )),
          );
        }
      }
    }
    final multipleKeyword = draft.isLegacy ? 'divisibleBy' : 'multipleOf';
    final multiple = value[multipleKeyword];
    if (isJsonNumber(multiple) && draft.index >= SchemaDraft.draft2.index) {
      final divisor = _Decimal.of(multiple!);
      test(
        multipleKeyword,
        (instance) => !isJsonNumber(instance) || divisor.divides(instance!),
      );
    }
    if (draft.index < SchemaDraft.draft2.index &&
        isJsonNumber(value['maxDecimal'])) {
      final maximum = value['maxDecimal']!;
      test(
        'maxDecimal',
        (instance) =>
            !isJsonNumber(instance) ||
            compareNumbers(_Decimal.of(instance!).scale, maximum) <= 0,
      );
    }
    for (final pair in [('minLength', true), ('maxLength', false)]) {
      final limit = value[pair.$1];
      if (isJsonNumber(limit)) {
        test(
          pair.$1,
          (instance) =>
              instance is! String ||
              (pair.$2
                  ? compareNumbers(instance.runes.length, limit!) >= 0
                  : compareNumbers(instance.runes.length, limit!) <= 0),
        );
      }
    }
    if (value['pattern'] is String) {
      final expression = RegExp(value['pattern']! as String, unicode: true);
      test(
        'pattern',
        (instance) => instance is! String || expression.hasMatch(instance),
      );
    }
    final strictFormats = _requiresFormatAssertion(
      entry.resource.vocabulary,
      draft,
    );
    final assertFormats =
        strictFormats ||
        (options.assertFormats ??
            draft == SchemaDraft.draft201909 &&
                entry
                        .resource
                        .vocabulary?['https://json-schema.org/draft/2019-09/vocab/format'] ==
                    true);
    if (value['format'] is String && assertFormats) {
      final name = value['format']! as String;
      final validator = options.formats[name] ?? formatForDraft(name, draft);
      if (validator == null && strictFormats) {
        throw SchemaException(
          'Unknown format in a Format-Assertion dialect: '
          '$name.',
          schemaPath: '${entry.path}/format',
        );
      }
      if (validator != null) {
        test(
          'format',
          (instance) => instance is! String || validator(instance),
        );
      }
    }
    if (options.assertContent && draft == SchemaDraft.draft7) {
      final encoded = value['contentEncoding'] == 'base64';
      if (encoded) {
        test(
          'contentEncoding',
          (instance) =>
              instance is! String || _base64Content.hasMatch(instance),
        );
      }
      if (value['contentMediaType'] is String &&
          (value['contentMediaType']! as String)
                  .split(';')
                  .first
                  .trim()
                  .toLowerCase() ==
              'application/json') {
        test(
          'contentMediaType',
          (instance) =>
              instance is! String ||
              _validJsonContent(instance, encoded: encoded),
        );
      }
    }
    for (final pair in [
      ('minItems', true),
      ('maxItems', false),
      if (!draft.isLegacy) ...[
        ('minProperties', true),
        ('maxProperties', false),
      ],
    ]) {
      final limit = value[pair.$1];
      if (isJsonNumber(limit)) {
        final array = pair.$1.endsWith('Items');
        test(pair.$1, (instance) {
          final length = array && instance is List<Object?>
              ? instance.length
              : !array && instance is Map<Object?, Object?>
              ? instance.length
              : null;
          return length == null ||
              (pair.$2
                  ? compareNumbers(length, limit!) >= 0
                  : compareNumbers(length, limit!) <= 0);
        });
      }
    }
    if (value['uniqueItems'] == true &&
        draft.index >= SchemaDraft.draft2.index) {
      test('uniqueItems', _uniqueItems);
    }
    final properties = <String, _Node>{};
    final required = <String>[];
    if (value['properties'] is Map<String, Object?>) {
      for (final property
          in (value['properties']! as Map<String, Object?>).entries) {
        properties[property.key] = child(
          entry,
          'properties',
          property.value,
          property.key,
        );
        if (property.value is Map<String, Object?> && draft.isLegacy) {
          final propertySchema = property.value! as Map<String, Object?>;
          if (draft == SchemaDraft.draft3
              ? propertySchema['required'] == true
              : propertySchema['optional'] != true) {
            required.add(property.key);
          }
        }
      }
    }
    if (!draft.isLegacy && value['required'] is List<Object?>) {
      required.addAll((value['required']! as List<Object?>).cast<String>());
    }
    final patterns = <(RegExp, _Node)>[];
    if (draft.index >= SchemaDraft.draft3.index &&
        value['patternProperties'] is Map<String, Object?>) {
      for (final pattern
          in (value['patternProperties']! as Map<String, Object?>).entries) {
        patterns.add((
          RegExp(pattern.key, unicode: true),
          child(entry, 'patternProperties', pattern.value, pattern.key),
        ));
      }
    }
    if (properties.isNotEmpty ||
        patterns.isNotEmpty ||
        required.isNotEmpty ||
        value.containsKey('additionalProperties') ||
        draft.index >= SchemaDraft.draft6.index &&
            value.containsKey('propertyNames')) {
      node.rules.add(
        _Properties(
          entry,
          properties,
          patterns,
          value.containsKey('additionalProperties')
              ? child(
                  entry,
                  'additionalProperties',
                  value['additionalProperties'],
                )
              : null,
          draft.index >= SchemaDraft.draft6.index &&
                  value.containsKey('propertyNames')
              ? child(entry, 'propertyNames', value['propertyNames'])
              : null,
          required,
        ),
      );
    }
    final prefix = <_Node>[];
    final tupleKey = draft == SchemaDraft.draft202012 ? 'prefixItems' : 'items';
    final tuple = value[tupleKey];
    if (tuple is List<Object?>) {
      for (var i = 0; i < tuple.length; i++) {
        prefix.add(child(entry, tupleKey, tuple[i], '$i'));
      }
    }
    final restKey = draft == SchemaDraft.draft202012 || tuple is! List<Object?>
        ? 'items'
        : draft.index < SchemaDraft.draft3.index
        ? 'additionalProperties'
        : 'additionalItems';
    final restValue = value[restKey];
    final rest = restValue is Map<String, Object?> || restValue is bool
        ? child(entry, restKey, restValue)
        : null;
    if (prefix.isNotEmpty || rest != null) {
      node.rules.add(_Items(prefix, rest));
    }
    if (draft.index >= SchemaDraft.draft6.index &&
        value.containsKey('contains')) {
      node.rules.add(
        _Contains(
          entry,
          child(entry, 'contains', value['contains']),
          draft.supportsVocabularies ? value['minContains'] ?? 1 : 1,
          draft.supportsVocabularies ? value['maxContains'] : null,
          draft == SchemaDraft.draft202012,
        ),
      );
    }
    for (final keyword
        in draft.isLegacy ? ['extends'] : ['allOf', 'anyOf', 'oneOf', 'not']) {
      final combined = value[keyword];
      if (combined != null) {
        final list = combined is List<Object?> ? combined : [combined];
        node.rules.add(
          _Combination(entry, keyword, [
            for (var i = 0; i < list.length; i++)
              child(
                entry,
                keyword,
                list[i],
                combined is List<Object?> ? '$i' : null,
              ),
          ]),
        );
      }
    }
    if (draft.index >= SchemaDraft.draft7.index && value.containsKey('if')) {
      node.rules.add(
        _Conditional(
          child(entry, 'if', value['if']),
          value.containsKey('then')
              ? child(entry, 'then', value['then'])
              : null,
          value.containsKey('else')
              ? child(entry, 'else', value['else'])
              : null,
        ),
      );
    }
    if (draft.isLegacy && value.containsKey('disallow')) {
      final disallow = value['disallow'];
      final list = disallow is List<Object?> ? disallow : [disallow];
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is String) {
          test('disallow', (instance) => !_matchesType(instance, item, draft));
        } else {
          node.rules.add(
            _Combination(entry, 'not', [child(entry, 'disallow', item, '$i')]),
          );
        }
      }
    }
    compileDependencies(node, value);
    for (final keyword in options.keywords.entries) {
      if (value.containsKey(keyword.key)) {
        final argument = value[keyword.key];
        test(keyword.key, (instance) => keyword.value(instance, argument));
      }
    }
    if (draft.supportsVocabularies) {
      if (value.containsKey('unevaluatedProperties')) {
        node.unevaluatedProperties = child(
          entry,
          'unevaluatedProperties',
          value['unevaluatedProperties'],
        );
      }
      if (value.containsKey('unevaluatedItems')) {
        node.unevaluatedItems = child(
          entry,
          'unevaluatedItems',
          value['unevaluatedItems'],
        );
      }
    }
    return node;
  }

  void compileDependencies(_Node node, Map<String, Object?> value) {
    final entry = node.entry;
    final draft = entry.draft;
    if (draft.supportsVocabularies &&
        options.legacyDependencies &&
        value['dependencies'] is Map<String, Object?>) {
      final required = <String, List<String>>{};
      final schemas = <String, _Node>{};
      for (final dependency
          in (value['dependencies']! as Map<String, Object?>).entries) {
        if (dependency.value is List<Object?>) {
          required[dependency.key] = (dependency.value! as List<Object?>)
              .cast<String>();
        } else {
          schemas[dependency.key] = child(
            entry,
            'dependencies',
            dependency.value,
            dependency.key,
          );
        }
      }
      node.rules.add(_Dependencies(entry, required, schemas, 'dependencies'));
    }
    final required = <String, List<String>>{};
    final schemas = <String, _Node>{};
    final keyword = draft.supportsVocabularies
        ? 'dependentRequired'
        : 'dependencies';
    final deps = value[keyword];
    if (draft.index >= SchemaDraft.draft3.index &&
        deps is Map<String, Object?>) {
      for (final dep in deps.entries) {
        if (dep.value is List<Object?>) {
          required[dep.key] = (dep.value! as List<Object?>).cast<String>();
        } else if (dep.value is String && draft == SchemaDraft.draft3) {
          required[dep.key] = [dep.value! as String];
        } else if (!draft.supportsVocabularies) {
          schemas[dep.key] = child(entry, keyword, dep.value, dep.key);
        }
      }
    }
    if (draft.supportsVocabularies &&
        value['dependentSchemas'] is Map<String, Object?>) {
      for (final dep
          in (value['dependentSchemas']! as Map<String, Object?>).entries) {
        schemas[dep.key] = child(entry, 'dependentSchemas', dep.value, dep.key);
      }
    }
    if (draft.index < SchemaDraft.draft3.index &&
        value['properties'] is Map<String, Object?>) {
      for (final property
          in (value['properties']! as Map<String, Object?>).entries) {
        if (property.value is Map<String, Object?>) {
          final requires =
              (property.value! as Map<String, Object?>)['requires'];
          if (requires is String) {
            required[property.key] = [requires];
          } else if (requires is Map<String, Object?>) {
            final propertyEntry = entries[property.value]!;
            schemas[property.key] = child(propertyEntry, 'requires', requires);
          }
        }
      }
    }
    if (required.isNotEmpty || schemas.isNotEmpty) {
      node.rules.add(_Dependencies(entry, required, schemas, keyword));
    }
  }

  void checkSyntax(_Entry entry, Map<String, Object?> value) {
    final draft = entry.draft;
    void ensure(String keyword, bool valid, String expected) {
      if (!valid) {
        throw SchemaException(
          '$keyword must be $expected.',
          schemaPath: '${entry.path}/${escapePointer(keyword)}',
        );
      }
    }

    bool schemaValue(Object? item, {bool allowBoolean = false}) =>
        item is Map<String, Object?> ||
        item is bool && (draft.supportsBooleanSchemas || allowBoolean);
    for (final keyword in [
      r'$schema',
      r'$ref',
      draft.index < SchemaDraft.draft6.index ? 'id' : r'$id',
      'title',
      'description',
      'format',
      'pattern',
      if (draft.index >= SchemaDraft.draft7.index) r'$comment',
      if (draft.supportsVocabularies) r'$anchor',
      if (draft == SchemaDraft.draft202012) ...[
        r'$dynamicAnchor',
        r'$dynamicRef',
      ],
      if (draft == SchemaDraft.draft201909) r'$recursiveRef',
    ]) {
      if (value.containsKey(keyword)) {
        ensure(keyword, value[keyword] is String, 'a string');
      }
    }
    for (final keyword in [
      'minimum',
      'maximum',
      if (draft.index >= SchemaDraft.draft6.index) ...[
        'exclusiveMinimum',
        'exclusiveMaximum',
      ],
    ]) {
      if (value.containsKey(keyword)) {
        ensure(keyword, isJsonNumber(value[keyword]), 'a number');
      }
    }
    for (final keyword in [
      r'$ref',
      if (draft == SchemaDraft.draft202012) r'$dynamicRef',
      if (draft == SchemaDraft.draft201909) r'$recursiveRef',
    ]) {
      if (value[keyword] is String) {
        _checkSchemaUri(value[keyword]! as String, keyword, entry.path);
      }
    }
    if (draft.supportsVocabularies) {
      final pattern = draft == SchemaDraft.draft202012
          ? _anchorPattern202012
          : _anchorPattern201909;
      for (final keyword in [
        r'$anchor',
        if (draft == SchemaDraft.draft202012) r'$dynamicAnchor',
      ]) {
        if (value.containsKey(keyword)) {
          final name = value[keyword]! as String;
          ensure(
            keyword,
            pattern.stringMatch(name) == name,
            'a valid plain-name anchor',
          );
        }
      }
    }
    final multipleKey = draft.isLegacy ? 'divisibleBy' : 'multipleOf';
    if (draft == SchemaDraft.draft3 || draft == SchemaDraft.draft4) {
      for (final pair in [
        ('exclusiveMinimum', 'minimum'),
        ('exclusiveMaximum', 'maximum'),
      ]) {
        if (value.containsKey(pair.$1)) {
          ensure(pair.$1, value.containsKey(pair.$2), 'paired with ${pair.$2}');
        }
      }
    }
    if (value.containsKey(multipleKey) &&
        draft.index >= SchemaDraft.draft2.index) {
      ensure(
        multipleKey,
        isJsonNumber(value[multipleKey]) &&
            compareNumbers(value[multipleKey]!, 0) > 0,
        'a positive number',
      );
    }
    for (final keyword in [
      'minLength',
      'maxLength',
      'minItems',
      'maxItems',
      if (!draft.isLegacy) ...['minProperties', 'maxProperties'],
      if (draft.supportsVocabularies) ...['minContains', 'maxContains'],
      if (draft.index < SchemaDraft.draft2.index) 'maxDecimal',
    ]) {
      if (value.containsKey(keyword)) {
        final item = value[keyword];
        ensure(
          keyword,
          isJsonInteger(item, allowDecimal: draft.supportsBooleanSchemas) &&
              compareNumbers(item!, 0) >= 0,
          'a non-negative integer',
        );
      }
    }
    for (final keyword in [
      if (draft.index >= SchemaDraft.draft2.index) 'uniqueItems',
      if (draft == SchemaDraft.draft3) 'required',
      if (draft.index < SchemaDraft.draft3.index) ...[
        'optional',
        'minimumCanEqual',
        'maximumCanEqual',
      ],
      if (draft.index >= SchemaDraft.draft3.index &&
          draft.index < SchemaDraft.draft6.index) ...[
        'exclusiveMinimum',
        'exclusiveMaximum',
      ],
      if (draft == SchemaDraft.draft201909) r'$recursiveAnchor',
      if (draft.index >= SchemaDraft.draft7.index) ...['readOnly', 'writeOnly'],
      if (draft.supportsVocabularies) 'deprecated',
    ]) {
      if (value.containsKey(keyword)) {
        ensure(keyword, value[keyword] is bool, 'a boolean');
      }
    }
    if (value.containsKey('type')) {
      final type = value['type'];
      final list = type is List<Object?> ? type : [type];
      ensure(
        'type',
        (draft.isLegacy || list.isNotEmpty) &&
            (!draft.isLegacy || type is String || type is List<Object?>) &&
            list.every(
              (item) =>
                  item is String &&
                      (SchemaType.values.any((type) => type.jsonName == item) ||
                          draft.isLegacy) ||
                  draft.isLegacy && schemaValue(item),
            ),
        'a primitive type or non-empty type array',
      );
      ensure('type', _uniqueItems(list), 'an array of distinct types');
    }
    if (value.containsKey('enum')) {
      final item = value['enum'];
      ensure(
        'enum',
        item is List<Object?> &&
            (draft.supportsVocabularies ||
                item.isNotEmpty && _uniqueItems(item)),
        'an array of JSON values (non-empty and distinct in older drafts)',
      );
    }
    if (!draft.isLegacy && value.containsKey('required')) {
      final item = value['required'];
      ensure(
        'required',
        item is List<Object?> &&
            item.every((e) => e is String) &&
            _uniqueItems(item) &&
            (draft != SchemaDraft.draft4 || item.isNotEmpty),
        'an array of distinct property names',
      );
    }
    for (final keyword in [
      'properties',
      if (!draft.isLegacy) 'definitions',
      if (draft.index >= SchemaDraft.draft3.index) 'patternProperties',
      if (draft.supportsVocabularies) ...[r'$defs', 'dependentSchemas'],
    ]) {
      if (value.containsKey(keyword)) {
        final item = value[keyword];
        ensure(
          keyword,
          item is Map<String, Object?> && item.values.every(schemaValue),
          'an object of schemas',
        );
      }
    }
    for (final keyword in [
      'additionalProperties',
      if (draft.index >= SchemaDraft.draft3.index &&
          draft != SchemaDraft.draft202012)
        'additionalItems',
      if (!draft.isLegacy) 'not',
      if (draft.index >= SchemaDraft.draft6.index) ...[
        'contains',
        'propertyNames',
      ],
      if (draft.index >= SchemaDraft.draft7.index) ...['if', 'then', 'else'],
      if (draft.supportsVocabularies) ...[
        'unevaluatedProperties',
        'unevaluatedItems',
        'contentSchema',
      ],
    ]) {
      if (value.containsKey(keyword)) {
        ensure(
          keyword,
          schemaValue(
            value[keyword],
            allowBoolean:
                keyword == 'additionalProperties' ||
                keyword == 'additionalItems',
          ),
          'a schema',
        );
      }
    }
    if (value.containsKey('items')) {
      final item = value['items'];
      ensure(
        'items',
        schemaValue(item) ||
            draft != SchemaDraft.draft202012 &&
                item is List<Object?> &&
                (draft.isLegacy || item.isNotEmpty) &&
                item.every(schemaValue),
        'a schema or a supported tuple array',
      );
    }
    for (final keyword in [
      if (!draft.isLegacy) ...['allOf', 'anyOf', 'oneOf'],
      if (draft == SchemaDraft.draft202012) 'prefixItems',
    ]) {
      if (value.containsKey(keyword)) {
        final item = value[keyword];
        ensure(
          keyword,
          item is List<Object?> && item.isNotEmpty && item.every(schemaValue),
          'a non-empty array of schemas',
        );
      }
    }
    if (draft.index >= SchemaDraft.draft3.index &&
            !draft.supportsVocabularies ||
        draft.supportsVocabularies && value.containsKey('dependentRequired')) {
      final keyword = draft.supportsVocabularies
          ? 'dependentRequired'
          : 'dependencies';
      if (value.containsKey(keyword)) {
        final item = value[keyword];
        ensure(
          keyword,
          item is Map<String, Object?>,
          'an object of dependencies',
        );
        for (final dependency in (item! as Map<String, Object?>).values) {
          ensure(
            keyword,
            dependency is List<Object?> &&
                    dependency.every((name) => name is String) &&
                    (draft == SchemaDraft.draft3 || _uniqueItems(dependency)) &&
                    (draft != SchemaDraft.draft4 || dependency.isNotEmpty) ||
                !draft.supportsVocabularies && schemaValue(dependency) ||
                draft == SchemaDraft.draft3 && dependency is String,
            'distinct property names or a supported schema dependency',
          );
        }
      }
    }
    if (draft.supportsVocabularies &&
        options.legacyDependencies &&
        value.containsKey('dependencies')) {
      final item = value['dependencies'];
      ensure('dependencies', item is Map<String, Object?>, 'an object');
      for (final dependency in (item! as Map<String, Object?>).values) {
        ensure(
          'dependencies',
          dependency is List<Object?> &&
                  dependency.every((name) => name is String) &&
                  _uniqueItems(dependency) ||
              schemaValue(dependency),
          'distinct property names or a schema',
        );
      }
    }
    if (draft.isLegacy) {
      final extended = value['extends'];
      if (value.containsKey('extends')) {
        ensure(
          'extends',
          schemaValue(extended) ||
              extended is List<Object?> && extended.every(schemaValue),
          'a schema or schema array',
        );
      }
      if (value.containsKey('disallow')) {
        final disallowed = value['disallow'];
        final alternatives = disallowed is List<Object?>
            ? disallowed
            : [disallowed];
        ensure(
          'disallow',
          (disallowed is String || disallowed is List<Object?>) &&
              _uniqueItems(alternatives) &&
              alternatives.every((item) => item is String || schemaValue(item)),
          'a type or schema union',
        );
      }
    }
    if (draft.index >= SchemaDraft.draft6.index &&
        value.containsKey('examples')) {
      ensure('examples', value['examples'] is List<Object?>, 'an array');
    }
    for (final keyword in ['contentEncoding', 'contentMediaType']) {
      if (draft.index >= SchemaDraft.draft7.index &&
          value.containsKey(keyword)) {
        ensure(keyword, value[keyword] is String, 'a string');
      }
    }
    for (final keyword in [
      'pattern',
      if (draft.index >= SchemaDraft.draft3.index) 'patternProperties',
    ]) {
      final item = value[keyword];
      final patterns = keyword == 'pattern' && item is String
          ? [item]
          : item is Map<String, Object?>
          ? item.keys
          : <String>[];
      for (final pattern in patterns) {
        try {
          RegExp(pattern, unicode: true);
        } on FormatException {
          ensure(keyword, false, 'a valid regular expression');
        }
      }
    }
    if (draft.supportsVocabularies && value.containsKey(r'$vocabulary')) {
      final vocabularies = value[r'$vocabulary'];
      ensure(
        r'$vocabulary',
        vocabularies is Map<String, Object?> &&
            vocabularies.values.every((v) => v is bool),
        'an object of URI/boolean pairs',
      );
      for (final vocabulary
          in (vocabularies! as Map<String, Object?>).entries) {
        final uri = Uri.parse(vocabulary.key);
        ensure(
          r'$vocabulary',
          uri.hasScheme && builtInFormats['uri']!(vocabulary.key),
          'an object with URI keys containing a scheme',
        );
      }
    }
    // Validate definitions and inactive conditional branches during preparation.
    for (final childSchema in childSchemas(value, draft)) {
      final childValue = childSchema.$2;
      if (childValue is Map<String, Object?>) {
        final indexed = entries[childValue];
        if (indexed != null && !nodes.containsKey(indexed)) {
          compile(indexed);
        }
      }
    }
  }
}

final _pointerEscapePattern = RegExp(r'~(?:[^01]|$)');
final _base64Content = RegExp(
  r'^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$',
);

bool _validJsonContent(String value, {required bool encoded}) {
  if (encoded && !_base64Content.hasMatch(value)) {
    return true;
  }
  try {
    jsonDecode(encoded ? utf8.decode(base64.decode(value)) : value);
    return true;
  } on FormatException {
    return false;
  }
}

final _pointerIndexPattern = RegExp(r'^(0|[1-9][0-9]*)$');
final _anchorPattern202012 = RegExp(r'^[A-Za-z_][A-Za-z0-9._-]*$');
final _anchorPattern201909 = RegExp(r'^[A-Za-z][A-Za-z0-9._:-]*$');

void _checkSchemaUri(
  String value,
  String keyword,
  String path, {
  bool absolute = false,
  bool noFragment = false,
}) {
  if (!builtInFormats[absolute ? 'uri' : 'uri-reference']!(value)) {
    throw SchemaException(
      '$keyword must be a valid '
      '${absolute ? 'absolute URI' : 'URI-reference'}.',
      schemaPath: '$path/${escapePointer(keyword)}',
    );
  }
  if (noFragment && Uri.parse(value).fragment.isNotEmpty) {
    throw SchemaException(
      '$keyword cannot contain a non-empty fragment.',
      schemaPath: '$path/${escapePointer(keyword)}',
    );
  }
}

bool _matchesType(Object? value, String name, SchemaDraft draft) =>
    switch (name) {
      'null' => value == null,
      'boolean' => value is bool,
      'string' => value is String,
      'array' => value is List<Object?>,
      'object' => _isJsonObject(value),
      'number' => isJsonNumber(value),
      'integer' => isJsonInteger(
        value,
        allowDecimal: draft.supportsBooleanSchemas,
      ),
      'any' => draft.isLegacy,
      _ => draft.isLegacy,
    };

bool _boundMatches(
  Object value,
  Object bound, {
  required bool lower,
  required bool exclusive,
}) {
  final comparison = compareNumbers(value, bound);
  return lower
      ? (exclusive ? comparison > 0 : comparison >= 0)
      : (exclusive ? comparison < 0 : comparison <= 0);
}

_Predicate _typePredicate(String name, SchemaDraft draft) => switch (name) {
  'null' => (value) => value == null,
  'boolean' => (value) => value is bool,
  'string' => (value) => value is String,
  'array' => (value) => value is List<Object?>,
  'object' => _isJsonObject,
  'number' => isJsonNumber,
  'integer' =>
    draft.supportsBooleanSchemas
        ? (value) =>
              value is int ||
              value is double &&
                  value.isFinite &&
                  value == value.truncateToDouble() ||
              value is BigInt ||
              value is JsonNumber && value.isInteger
        : (value) =>
              value is int ||
              value is BigInt ||
              value is JsonNumber && value.isIntegerLiteral,
  _ => (value) => _matchesType(value, name, draft),
};

bool _isJsonObject(Object? value) =>
    value is Map<String, Object?> ||
    value is Map<Object?, Object?> && value.keys.every((key) => key is String);

bool _requiresContext(_Node root) {
  final active = HashSet<_Node>.identity();
  final done = HashSet<_Node>.identity();
  bool visit(_Node node) {
    if (active.contains(node)) {
      return true;
    }
    if (done.contains(node)) {
      return false;
    }
    active.add(node);
    for (final rule in node.rules) {
      if (rule is _Reference &&
          (rule.dynamicAnchor != null || rule.recursive)) {
        return true;
      }
    }
    for (final child in _children(node)) {
      if (visit(child)) {
        return true;
      }
    }
    active.remove(node);
    done.add(node);
    return false;
  }

  return visit(root);
}

Iterable<_Node> _children(_Node node) sync* {
  if (node.unevaluatedProperties != null) {
    yield node.unevaluatedProperties!;
  }
  if (node.unevaluatedItems != null) {
    yield node.unevaluatedItems!;
  }
  for (final rule in node.rules) {
    if (rule is _Reference) {
      yield rule.target;
    } else if (rule is _Properties) {
      yield* rule.properties.values;
      for (final pattern in rule.patterns) {
        yield pattern.$2;
      }
      if (rule.additional != null) {
        yield rule.additional!;
      }
      if (rule.names != null) {
        yield rule.names!;
      }
    } else if (rule is _Items) {
      yield* rule.prefix;
      if (rule.rest != null) {
        yield rule.rest!;
      }
    } else if (rule is _Contains) {
      yield rule.child;
    } else if (rule is _Combination) {
      yield* rule.children;
    } else if (rule is _Conditional) {
      yield rule.condition;
      if (rule.thenNode != null) {
        yield rule.thenNode!;
      }
      if (rule.elseNode != null) {
        yield rule.elseNode!;
      }
    } else if (rule is _Dependencies) {
      yield* rule.schemas.values;
    }
  }
}

bool _uniqueItems(Object? value) {
  if (value is! List<Object?> || value.length < 2) {
    return true;
  }
  final buckets = <int, List<Object?>>{};
  for (final item in value) {
    final hash = jsonHash(item);
    final bucket = buckets[hash];
    if (bucket != null) {
      if (bucket.any((previous) => jsonEquals(previous, item))) {
        return false;
      }
      bucket.add(item);
    } else {
      buckets[hash] = [item];
    }
  }
  return true;
}

final class _Decimal {
  _Decimal(this.coefficient, this.scale)
    : small = coefficient.bitLength < 53 ? coefficient.toInt() : null;
  factory _Decimal.of(Object value) {
    if (value is JsonNumber) {
      return _Decimal(value.coefficient, value.scale);
    }
    final parts = value.toString().toLowerCase().split('e');
    final mantissa = parts[0];
    final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
    final dot = mantissa.indexOf('.');
    var scale = (dot < 0 ? 0 : mantissa.length - dot - 1) - exponent;
    var coefficient = BigInt.parse(mantissa.replaceAll('.', ''));
    while (scale > 0 && coefficient % BigInt.from(10) == BigInt.zero) {
      coefficient ~/= BigInt.from(10);
      scale--;
    }
    return _Decimal(coefficient, scale);
  }
  final BigInt coefficient;
  final int scale;
  final int? small;

  bool divides(Object value) {
    if (value == 0) {
      return true;
    }
    if (value is num && !value.isFinite || coefficient == BigInt.zero) {
      return false;
    }
    final smallDivisor = small;
    if (smallDivisor != null) {
      final parts = _smallDecimal(value.toString());
      if (parts != null) {
        final difference = scale - parts.$2;
        if (difference.abs() < _powersOfTen.length) {
          final numeratorFactor = difference >= 0
              ? _powersOfTen[difference]
              : 1;
          final denominatorFactor = difference < 0
              ? _powersOfTen[-difference]
              : 1;
          // Keep products exactly representable on both native and web runtimes.
          if (parts.$1.abs() <= _maxExactInteger ~/ numeratorFactor &&
              smallDivisor.abs() <= _maxExactInteger ~/ denominatorFactor) {
            return (parts.$1 * numeratorFactor) %
                    (smallDivisor * denominatorFactor) ==
                0;
          }
        }
      }
    }
    final dividend = _Decimal.of(value);
    final difference = scale - dividend.scale;
    final numerator = difference >= 0
        ? dividend.coefficient * BigInt.from(10).pow(difference)
        : dividend.coefficient;
    final denominator = difference < 0
        ? coefficient * BigInt.from(10).pow(-difference)
        : coefficient;
    return numerator % denominator == BigInt.zero;
  }
}

const _maxExactInteger = 9007199254740991;
const _powersOfTen = [
  1,
  10,
  100,
  1000,
  10000,
  100000,
  1000000,
  10000000,
  100000000,
  1000000000,
  10000000000,
  100000000000,
  1000000000000,
  10000000000000,
  100000000000000,
  1000000000000000,
];

(int, int)? _smallDecimal(String text) {
  var coefficient = 0;
  var scale = 0;
  var fractional = false;
  var sign = 1;
  var i = 0;
  if (text.startsWith('-')) {
    sign = -1;
    i++;
  }
  for (; i < text.length; i++) {
    final digit = text.codeUnitAt(i);
    if (digit == 46) {
      fractional = true;
    } else if (digit == 101 || digit == 69) {
      scale -= int.parse(text.substring(i + 1));
      break;
    } else {
      if (digit < 48 ||
          digit > 57 ||
          coefficient > (_maxExactInteger - 9) ~/ 10) {
        return null;
      }
      coefficient = coefficient * 10 + digit - 48;
      if (fractional) {
        scale++;
      }
    }
  }
  return (coefficient * sign, scale);
}

bool _knownVocabulary(Uri uri, SchemaDraft draft) {
  final prefix = draft == SchemaDraft.draft202012
      ? 'https://json-schema.org/draft/2020-12/vocab/'
      : 'https://json-schema.org/draft/2019-09/vocab/';
  return [
    'core',
    'applicator',
    'validation',
    'meta-data',
    'content',
    if (draft == SchemaDraft.draft201909) 'format',
    if (draft == SchemaDraft.draft202012) ...[
      'format-annotation',
      'format-assertion',
      'unevaluated',
    ],
  ].any((name) => uri.toString() == '$prefix$name');
}

bool _requiresFormatAssertion(
  Map<String, Object?>? vocabulary,
  SchemaDraft draft,
) {
  return draft == SchemaDraft.draft202012 &&
      vocabulary is Map<String, Object?> &&
      vocabulary.containsKey(
        'https://json-schema.org/draft/2020-12/vocab/format-assertion',
      );
}
