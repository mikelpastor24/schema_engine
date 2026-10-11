import 'package:flutter/material.dart';
import 'package:schema_engine/schema_engine.dart';

import 'schema_editor_messages.dart';
import 'schema_ui_theme.dart';

part 'schema_editor_model.dart';
part 'schema_editor_options.dart';

/// Creates or edits a Draft 2020-12 JSON Schema through Material form controls.
///
/// Properties, nested objects, array items, definitions, references, and common
/// constraints are edited visually. Keywords without dedicated controls are
/// preserved when loading an existing document.
///
/// Place the editor inside a [Form] to validate, save, and reset the schema.
/// It also works without a Form through [onChanged]. It adds no nested Form.
///
///     SchemaEditor(
///       onChanged: (schema) => print(schema.toJsonString()),
///     )
final class SchemaEditor extends StatefulWidget {
  /// Creates a visual schema editor, initially an empty object schema.
  ///
  /// A different [schema] replaces the current document while keeping expanded
  /// sections at unchanged schema locations. Feeding the exact [onChanged]
  /// result back into [schema] also preserves pending text and focus. Other drafts
  /// are rejected rather than implicitly migrated. Invalid initial documents
  /// propagate the engine's schema or reference exception.
  const SchemaEditor({
    super.key,
    this.schema,
    this.onChanged,
    this.onSaved,
    this.onValidityChanged,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.messages = const SchemaEditorMessages(),
    this.formats = const [
      'email',
      'uri',
      'uuid',
      'date',
      'time',
      'date-time',
      'duration',
      'hostname',
      'ipv4',
      'ipv6',
      'regex',
      'json-pointer',
      'uri-reference',
      'uri-template',
      'relative-json-pointer',
      'idn-email',
      'idn-hostname',
      'iri',
      'iri-reference',
    ],
    this.resources = const {},
    this.baseUri,
  });

  /// The initial or externally supplied immutable schema document.
  final JsonSchema? schema;

  /// Receives immutable, compilable schemas after valid edits and reset.
  ///
  /// Invalid text stays visible and does not emit a replacement schema.
  final ValueChanged<JsonSchema>? onChanged;

  /// Receives a valid schema when the ancestor Form is saved.
  ///
  /// Invalid editor configurations are never submitted, even if save is called
  /// without validating first.
  final ValueChanged<JsonSchema>? onSaved;

  /// Receives changes in whether the current editor configuration is valid.
  final ValueChanged<bool>? onValidityChanged;

  /// Whether controls accept edits.
  final bool enabled;

  /// The validation policy for the root and keyword fields.
  final AutovalidateMode autovalidateMode;

  /// Application-supplied labels and error explanations.
  final SchemaEditorMessages messages;

  /// Format suggestions; arbitrary custom format strings remain editable.
  ///
  /// Formats are emitted as annotations. Applications decide whether to enable
  /// format assertions when validating instances.
  final List<String> formats;

  /// Offline schema resources used to verify external references.
  final Map<Uri, Object?> resources;

  /// The retrieval URI used during reference resolution.
  final Uri? baseUri;

  @override
  State<SchemaEditor> createState() => _SchemaEditorState();
}

class _SchemaEditorState extends State<SchemaEditor> {
  final _rootKey = GlobalKey<FormFieldState<JsonSchema>>();
  late _EditorNode _root;
  late JsonSchema _initial;
  JsonSchema? _candidate;
  Object? _problem;
  var _resetting = false;

  SchemaEditorMessages get _messages => widget.messages;
  double get _spacing =>
      Theme.of(context).extension<SchemaUiTheme>()?.spacing ?? 16;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool preserveState = false}) {
    _initial = widget.schema ?? JsonSchema.build(type: SchemaType.object);
    if (_initial.draft != SchemaDraft.draft202012) {
      throw ArgumentError.value(
        _initial.draft,
        'schema',
        'SchemaEditor supports Draft 2020-12 only.',
      );
    }
    final source = _initial.value;
    if (source is Map<String, Object?> &&
        source[r'$schema'] is String &&
        SchemaDraft.fromUri(source[r'$schema']! as String) !=
            SchemaDraft.draft202012) {
      throw ArgumentError.value(
        source[r'$schema'],
        'schema',
        'SchemaEditor does not migrate older dialect declarations.',
      );
    }
    _initial.compile(
      options: SchemaOptions(resources: widget.resources),
      baseUri: widget.baseUri,
    );
    final replacement = _EditorNode(_initial.value);
    if (preserveState) {
      _root.replaceFrom(replacement);
    } else {
      _root = replacement;
    }
    _calculate();
  }

  @override
  void didUpdateWidget(covariant SchemaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.schema != oldWidget.schema &&
            !identical(widget.schema, _candidate)) ||
        widget.resources != oldWidget.resources ||
        widget.baseUri != oldWidget.baseUri) {
      _load(preserveState: true);
    }
  }

  void _calculate() {
    try {
      var value = _root.toJson('');
      if (value is Map<String, Object?>) {
        value = {...value, r'$schema': SchemaDraft.draft202012.metaSchemaUri};
      }
      final schema = JsonSchema.fromJson(value, draft: SchemaDraft.draft202012);
      schema.compile(
        options: SchemaOptions(resources: widget.resources),
        baseUri: widget.baseUri,
      );
      _candidate = schema;
      _problem = null;
    } on _EditorInputIssue catch (error) {
      _candidate = null;
      _problem = error;
    } on SchemaException catch (error) {
      _candidate = null;
      _problem = error;
    } on ReferenceException catch (error) {
      _candidate = null;
      _problem = error;
    } on FormatException catch (error) {
      _candidate = null;
      _problem = error;
    }
  }

  void _change(VoidCallback edit) {
    if (!widget.enabled || _resetting) {
      return;
    }
    final wasValid = _candidate != null;
    setState(() {
      edit();
      _calculate();
    });
    _rootKey.currentState?.didChange(_candidate);
    if (wasValid != (_candidate != null)) {
      widget.onValidityChanged?.call(_candidate != null);
    }
    if (_candidate case final schema?) {
      widget.onChanged?.call(schema);
    }
  }

  void _reset() {
    _resetting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetting = false);
    final wasValid = _candidate != null;
    setState(() {
      _root = _EditorNode(_initial.value);
      _calculate();
    });
    if (!wasValid) {
      widget.onValidityChanged?.call(true);
    }
    widget.onChanged?.call(_candidate!);
  }

  String _inputMessage(_InputProblem problem) => switch (problem) {
    _InputProblem.number => _messages.invalidNumber,
    _InputProblem.count => _messages.invalidCount,
    _InputProblem.multiple => _messages.invalidMultiple,
    _InputProblem.json => _messages.invalidJson,
    _InputProblem.array => _messages.invalidArray,
    _InputProblem.name => _messages.duplicateName,
  };

  String? _rootError() => switch (_problem) {
    null => null,
    _EditorInputIssue(:final problem, :final path) => _messages.inputError(
      path,
      _inputMessage(problem),
    ),
    final error => _messages.schemaError(error),
  };

  String? _fieldError(String keyword, String? text) {
    try {
      _parseEditorInput(keyword, text ?? '', '');
    } on _EditorInputIssue catch (error) {
      return _inputMessage(error.problem);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => FormField<JsonSchema>(
    key: _rootKey,
    initialValue: _candidate,
    enabled: widget.enabled,
    autovalidateMode: widget.autovalidateMode,
    validator: (_) => _rootError(),
    onReset: _reset,
    onSaved: (_) {
      if (_candidate case final schema?) {
        widget.onSaved?.call(schema);
      }
    },
    builder: (state) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nodeEditor(_root, '', _messages.schema, root: true),
        if (state.errorText case final error?)
          Padding(
            padding: EdgeInsets.only(top: _spacing),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );

  String _kindLabel(String kind) => switch (kind) {
    'any' => _messages.anyType,
    'never' => _messages.neverType,
    'reference' => _messages.referenceType,
    'multiple' => _messages.multipleTypes,
    _ => _messages.typeLabel(
      SchemaType.values.firstWhere((type) => type.jsonName == kind),
    ),
  };

  Widget _typeSelector(_EditorNode node) {
    final kind = node.kind;
    return DropdownButtonFormField<String>(
      key: ValueKey((node, 'type', kind)),
      initialValue: kind,
      isExpanded: true,
      decoration: InputDecoration(labelText: _messages.type),
      items: [
        for (final value in [
          'object',
          'string',
          'integer',
          'number',
          'boolean',
          'array',
          'null',
          'any',
          'reference',
          'never',
          if (kind == 'multiple') 'multiple',
        ])
          DropdownMenuItem(value: value, child: Text(_kindLabel(value))),
      ],
      onChanged: widget.enabled
          ? (value) => _change(() {
              node.chooseKind(
                value!,
                _root.definitions.isEmpty
                    ? null
                    : _definitionReference(_root.definitions.first.name),
              );
            })
          : null,
    );
  }

  Widget _nodeHeader(
    _EditorNode node,
    String? title,
    Widget? nameField,
    Widget? removeButton,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final type = _typeSelector(node);
      final name =
          nameField ??
          Text(title!, style: Theme.of(context).textTheme.titleMedium);
      if (constraints.maxWidth >= 480) {
        return Row(
          children: [
            Expanded(flex: 2, child: name),
            SizedBox(width: _spacing),
            Expanded(child: type),
            ?removeButton,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: name),
              ?removeButton,
            ],
          ),
          SizedBox(height: _spacing),
          type,
        ],
      );
    },
  );

  Widget _option(String label, bool value, ValueChanged<bool> onChanged) =>
      FilterChip(
        label: Text(label),
        selected: value,
        onSelected: widget.enabled ? onChanged : null,
      );

  Widget _nodeEditor(
    _EditorNode node,
    String path,
    String? title, {
    bool root = false,
    Widget? nameField,
    Widget? removeButton,
    _NamedEditorNode? property,
  }) {
    final kind = node.kind;
    final primaryKeywords = switch (kind) {
      'string' => ['minLength', 'maxLength', 'format'],
      'integer' || 'number' => ['minimum', 'maximum'],
      _ => <String>[],
    };
    final nullable =
        SchemaType.values.any((type) => type.jsonName == kind) &&
        kind != 'null';
    final fields = <Widget>[
      _nodeHeader(node, title, nameField, removeButton),
      if (property != null || nullable || kind == 'array')
        Wrap(
          spacing: _spacing / 2,
          runSpacing: _spacing / 2,
          children: [
            if (property != null)
              _option(
                _messages.required,
                property.isRequired,
                (value) => _change(() => property.isRequired = value),
              ),
            if (nullable)
              _option(
                _messages.nullable,
                node.nullable,
                (value) => _change(() => node.setNullable(value)),
              ),
            if (kind == 'array')
              _option(
                _messages.uniqueItems,
                node.keywords['uniqueItems'] == true,
                (value) => _change(() => node.keywords['uniqueItems'] = value),
              ),
          ],
        ),
      if (primaryKeywords.isNotEmpty) _keywordGrid(node, primaryKeywords),
      if (kind == 'reference') ...[
        if (_root.definitions.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey((
              node,
              'definition',
              node.inputText(r'$ref'),
              _root.definitions.map((entry) => entry.name).join('\u0000'),
            )),
            initialValue:
                _root.definitions.any(
                  (entry) =>
                      _root.definitions
                              .where((other) => other.name == entry.name)
                              .length ==
                          1 &&
                      _definitionReference(entry.name) ==
                          node.inputText(r'$ref'),
                )
                ? node.inputText(r'$ref')
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: _messages.useDefinition),
            items: [
              for (final entry in _root.definitions)
                if (_root.definitions
                        .where((item) => item.name == entry.name)
                        .length ==
                    1)
                  DropdownMenuItem(
                    value: _definitionReference(entry.name),
                    child: Text(entry.name),
                  ),
            ],
            onChanged: widget.enabled
                ? (value) => _change(() {
                    node.edits[r'$ref'] = value!;
                    node.revisions.update(
                      r'$ref',
                      (value) => value + 1,
                      ifAbsent: () => 1,
                    );
                  })
                : null,
          ),
        _keyword(node, r'$ref'),
      ],
      if (node.booleanValue == null)
        _SchemaEditorOptions(
          key: ValueKey((node, 'settings')),
          messages: _messages,
          spacing: _spacing,
          validation: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _keywordGrid(node, [
                if (kind == 'string') 'pattern',
                if (kind == 'integer' || kind == 'number') ...[
                  'exclusiveMinimum',
                  'exclusiveMaximum',
                  'multipleOf',
                ],
                if (kind == 'object') ...['minProperties', 'maxProperties'],
                if (kind == 'array') ...['minItems', 'maxItems'],
                'enum',
                'const',
              ]),
              if (kind == 'object') ...[
                SizedBox(height: _spacing),
                _additionalProperties(node, path),
              ],
            ],
          ),
          annotations: _keywordGrid(node, [
            if (root) r'$id',
            'title',
            'description',
            'default',
            'examples',
          ]),
        ),
      if (kind == 'object') _namedSection(node, path, definitions: false),
      if (kind == 'array') ...[
        if (node.children['items'] case final items?)
          _nodeEditor(items, '$path/items', _messages.items)
        else
          TextButton.icon(
            onPressed: widget.enabled
                ? () => _change(
                    () => node.children['items'] = _EditorNode({
                      'type': 'string',
                    }),
                  )
                : null,
            icon: const Icon(Icons.add),
            label: Text(_messages.setItems),
          ),
      ],
      if (node.booleanValue == null && (root || node.definitions.isNotEmpty))
        _namedSection(node, path, definitions: true),
    ];
    final content = Padding(
      padding: EdgeInsets.all(_spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            if (index > 0) SizedBox(height: _spacing),
            fields[index],
          ],
        ],
      ),
    );
    return root ? content : Card.outlined(key: ObjectKey(node), child: content);
  }

  Widget _keywordGrid(_EditorNode node, List<String> keywords) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 480
          ? (constraints.maxWidth - _spacing) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        children: [
          for (final keyword in keywords)
            SizedBox(width: width, child: _keyword(node, keyword)),
        ],
      );
    },
  );

  Widget _keyword(_EditorNode node, String keyword) {
    final key = ValueKey((node, keyword, node.revisions[keyword] ?? 0));
    InputDecoration decoration() => InputDecoration(
      labelText: _messages.keywordLabel(keyword),
      helperText: keyword == r'$ref' ? _messages.referenceHint : null,
      helperMaxLines: 2,
    );
    if (keyword == 'format') {
      return Autocomplete<String>(
        key: key,
        initialValue: TextEditingValue(text: node.inputText(keyword)),
        optionsBuilder: (value) => widget.formats.where(
          (format) => format.toLowerCase().contains(value.text.toLowerCase()),
        ),
        onSelected: (value) => _change(() => node.edits[keyword] = value),
        fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
          controller: controller,
          focusNode: focus,
          enabled: widget.enabled,
          autocorrect: false,
          enableSuggestions: false,
          decoration: decoration(),
          onFieldSubmitted: (_) => submit(),
          onChanged: (value) => _change(() => node.edits[keyword] = value),
        ),
      );
    }
    return TextFormField(
      key: key,
      initialValue: node.inputText(keyword),
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      decoration: decoration(),
      autocorrect: keyword == 'title' || keyword == 'description',
      enableSuggestions: keyword == 'title' || keyword == 'description',
      minLines: 1,
      maxLines: keyword == 'description' || _jsonKeywords.contains(keyword)
          ? 3
          : 1,
      keyboardType: _countKeywords.contains(keyword)
          ? TextInputType.number
          : _numberKeywords.contains(keyword)
          ? const TextInputType.numberWithOptions(signed: true, decimal: true)
          : keyword == r'$id' || keyword == r'$ref'
          ? TextInputType.url
          : _jsonKeywords.contains(keyword) || keyword == 'description'
          ? TextInputType.multiline
          : TextInputType.text,
      validator: (value) => _fieldError(keyword, value),
      onChanged: (value) => _change(() => node.edits[keyword] = value),
    );
  }

  Widget _namedSection(
    _EditorNode parent,
    String path, {
    required bool definitions,
  }) {
    final entries = definitions ? parent.definitions : parent.properties;
    final keyword = definitions ? r'$defs' : 'properties';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                definitions ? _messages.definitions : _messages.properties,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            _addEntry(entries, definitions: definitions),
          ],
        ),
        for (final entry in entries)
          Padding(
            key: ObjectKey(entry),
            padding: EdgeInsets.only(top: _spacing / 2),
            child: _nodeEditor(
              entry.node,
              '$path/$keyword/${_editorEscape(entry.name)}',
              null,
              property: definitions ? null : entry,
              nameField: TextFormField(
                initialValue: entry.name,
                enabled: widget.enabled,
                autocorrect: false,
                enableSuggestions: false,
                autovalidateMode: widget.autovalidateMode,
                decoration: InputDecoration(
                  labelText: definitions
                      ? _messages.definitionName
                      : _messages.propertyName,
                ),
                validator: (_) =>
                    entries.where((other) => other.name == entry.name).length >
                        1
                    ? _messages.duplicateName
                    : null,
                onChanged: (value) => _change(() {
                  entry.name = value;
                  if (definitions &&
                      identical(parent, _root) &&
                      entries.where((other) => other.name == value).length ==
                          1) {
                    _renameDefinition(entry.referenceName, value);
                    entry.referenceName = value;
                  }
                }),
              ),
              removeButton: IconButton(
                tooltip: _messages.remove(entry.name),
                onPressed: widget.enabled
                    ? () => _change(() {
                        entries.remove(entry);
                      })
                    : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
      ],
    );
  }

  Widget _addEntry(
    List<_NamedEditorNode> entries, {
    required bool definitions,
  }) => TextButton.icon(
    onPressed: widget.enabled
        ? () => _change(() {
            var index = 1;
            final prefix = definitions ? 'definition' : 'property';
            while (entries.any((entry) => entry.name == '$prefix$index')) {
              index++;
            }
            entries.add(
              _NamedEditorNode(
                '$prefix$index',
                _EditorNode({'type': definitions ? 'object' : 'string'}),
              ),
            );
          })
        : null,
    icon: const Icon(Icons.add),
    label: Text(definitions ? _messages.addDefinition : _messages.addProperty),
  );

  Widget _additionalProperties(_EditorNode node, String path) {
    final child = node.children['additionalProperties'];
    final policy = child?.booleanValue == false
        ? 'forbid'
        : child == null || child.booleanValue == true
        ? 'allow'
        : 'schema';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey((node, 'additionalProperties', policy)),
          initialValue: policy,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _messages.additionalProperties,
          ),
          items: [
            DropdownMenuItem(value: 'allow', child: Text(_messages.allow)),
            DropdownMenuItem(value: 'forbid', child: Text(_messages.forbid)),
            DropdownMenuItem(value: 'schema', child: Text(_messages.useSchema)),
          ],
          onChanged: widget.enabled
              ? (value) => _change(() {
                  node.children['additionalProperties'] = _EditorNode(
                    value == 'allow'
                        ? true
                        : value == 'forbid'
                        ? false
                        : <String, Object?>{'type': 'string'},
                  );
                })
              : null,
        ),
        if (policy == 'schema')
          _nodeEditor(
            child!,
            '$path/additionalProperties',
            _messages.additionalPropertySchema,
          ),
      ],
    );
  }

  void _renameDefinition(String oldName, String newName) {
    final oldRef = _definitionReference(oldName);
    final newRef = _definitionReference(newName);
    void visit(_EditorNode node, {bool root = false}) {
      if (!root && node.keywords.containsKey(r'$id')) {
        return;
      }
      _rewriteEditorReferences(node.keywords, oldRef, newRef);
      if (node.edits[r'$ref'] case final reference?) {
        final holder = <String, Object?>{r'$ref': reference};
        _rewriteEditorReferences(holder, oldRef, newRef);
        node.edits[r'$ref'] = holder[r'$ref']! as String;
      }
      node.revisions.update(r'$ref', (value) => value + 1, ifAbsent: () => 1);
      for (final entry in [...node.properties, ...node.definitions]) {
        visit(entry.node);
      }
      for (final child in node.children.values) {
        visit(child);
      }
    }

    visit(_root, root: true);
  }
}
