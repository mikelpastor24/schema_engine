import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:schema_engine/schema_engine.dart';

import 'schema_ui_theme.dart';

part 'schema_json_field.dart';
part 'schema_number_field.dart';
part 'schema_text_field.dart';

const _absent = Object();

/// Builds an editor for a schema field.
///
/// Call [SchemaField.onChanged] with decoded JSON. A custom [FormField] can use
/// [SchemaField.validator] to display engine diagnostics. Return a widget that
/// inherits the surrounding theme, and honor [SchemaField.enabled].
typedef SchemaWidgetBuilder = Widget Function(
  BuildContext context,
  SchemaField field,
);

/// Information and callbacks supplied to a custom schema widget builder.
final class SchemaField {
  SchemaField._(
    this._errorText,
    this._errors,
    this._setInvalidInput,
    this._clearValue, {
    required this.schema,
    required this.instancePath,
    required this.value,
    required this.isPresent,
    required this.isRequired,
    required this.enabled,
    required this.autovalidateMode,
    required this.onChanged,
    required this.setInputError,
  });

  /// The immutable schema fragment used to choose this editor.
  ///
  /// References remain relative to the original document. Validation uses the
  /// compiled root document rather than compiling this fragment in isolation.
  final JsonSchema schema;

  /// The field's escaped JSON Pointer; an empty string identifies the root.
  final String instancePath;

  /// The immutable decoded JSON value, or null when the property is absent.
  ///
  /// Use [isPresent] to distinguish an absent property from an explicit null.
  final Object? value;

  /// Whether the instance contains this field.
  final bool isPresent;

  /// Whether this property is required by its containing object schema.
  final bool isRequired;

  /// Whether the editor should accept changes.
  final bool enabled;

  /// The validation policy selected for generated fields.
  final AutovalidateMode autovalidateMode;

  /// Replaces this value with decoded JSON and clears its input error.
  ///
  /// An empty string omits an optional free-text property. Other assignments,
  /// including zero, false, null, enum choices, and JSON values, are preserved.
  /// Values are snapshotted. Unsupported values and cycles throw [ArgumentError].
  final ValueChanged<Object?> onChanged;

  /// Records an editor parsing error, or clears it with null.
  ///
  /// Invalid text can stay in the editor without corrupting the JSON instance.
  /// The containing form remains invalid until this error is cleared.
  final ValueChanged<String?> setInputError;

  final String? Function() _errorText;
  final List<ValidationError> Function() _errors;
  final void Function(String text, String parsingMessage) _setInvalidInput;
  final void Function({required bool resetEditor}) _clearValue;

  /// Omits this optional property and resets its editor to the empty state.
  ///
  /// Use this in custom editors for values that do not have an empty text
  /// representation. Throws [StateError] for required properties, root values,
  /// and array items. Disabled and read-only fields cannot be cleared.
  ///
  /// ```dart
  /// IconButton(
  ///   onPressed: field.enabled && !field.isRequired ? field.clear : null,
  ///   icon: const Icon(Icons.clear),
  /// );
  /// ```
  void clear() {
    if (isRequired) {
      throw StateError('Only optional properties can be omitted.');
    }
    _clearValue(resetEditor: true);
  }

  /// Current engine diagnostics located exactly at [instancePath].
  ///
  /// Temporary invalid editor input participates in validation while [value]
  /// retains the last successfully decoded JSON value.
  List<ValidationError> get errors => _errors();

  /// A validator suitable for a custom Flutter [FormField].
  ///
  /// The candidate is ignored: call [onChanged] before validating so checks
  /// include the current document and constraints involving other fields.
  String? validator(Object? candidate) => _errorText();
}

/// Edits a JSON instance using form fields generated from [schema].
///
/// Place this widget inside a Flutter [Form]. Its ancestor's validate, save,
/// and reset operations include the complete schema, even with custom widgets.
/// Without an ancestor, editing and [onChanged] still work.
///
/// ```dart
/// final document = object({'name': string().min(1)}).toJsonSchema();
/// final formKey = GlobalKey<FormState>();
/// final editor = Form(
///   key: formKey,
///   child: SchemaForm(schema: document, onSaved: (value) => print(value)),
/// );
/// ```
final class SchemaForm extends StatefulWidget {
  /// Creates an editor and compiles its schema once per configuration.
  ///
  /// [initialValue] is copied on initialization and reset. If omitted, an empty
  /// value matching the root editor is used. Explicit null stays null. Defaults
  /// are annotations; array item additions can use them as suggestions. Visible
  /// optional fields stay absent until assigned. [initialValue] changes alone
  /// follow Flutter's usual form
  /// behavior: they take effect on reset, not on every parent rebuild.
  ///
  /// [pathBuilders] take precedence over [typeBuilders] and default editors.
  /// [options] and [baseUri] are forwarded to offline schema compilation.
  /// Invalid schemas or missing references propagate the engine's exceptions.
  const SchemaForm({
    super.key,
    required this.schema,
    this.initialValue = _absent,
    this.onChanged,
    this.onSaved,
    this.options,
    this.baseUri,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.typeBuilders = const {},
    this.pathBuilders = const {},
  });

  /// The schema document used for presentation and validation.
  final JsonSchema schema;

  /// The initial decoded JSON instance, copied without modifying the caller.
  final Object? initialValue;

  /// Receives immutable JSON snapshots after successfully parsed edits or reset.
  final ValueChanged<Object?>? onChanged;

  /// Receives the current instance when the ancestor [Form] is saved.
  ///
  /// Call the ancestor's validate method before saving; Flutter save does not
  /// validate automatically.
  final FormFieldSetter<Object?>? onSaved;

  /// The dialect, formats, resources, and other engine compilation settings.
  final SchemaOptions? options;

  /// The retrieval URI used to resolve relative schema references.
  final Uri? baseUri;

  /// Whether the generated controls accept edits.
  final bool enabled;

  /// The automatic validation policy for the root and generated fields.
  final AutovalidateMode autovalidateMode;

  /// Custom editors by JSON type, including all nested fields of that type.
  final Map<SchemaType, SchemaWidgetBuilder> typeBuilders;

  /// Custom editors by escaped instance JSON Pointer, including the root `''`.
  final Map<String, SchemaWidgetBuilder> pathBuilders;

  @override
  State<SchemaForm> createState() => _SchemaFormState();
}

class _SchemaFormState extends State<SchemaForm> {
  var _rootKey = GlobalKey<FormFieldState<Object?>>();
  late CompiledSchema _validator;
  late _Plan _plan;
  Object? _value;
  Object? _initial;
  List<ValidationError>? _errors;
  final _inputErrors = <String, String>{};
  final _invalidInputs = <String, ({String text, String parsingMessage})>{};
  final _versions = <String, int>{};
  var _generation = 0;
  var _resetting = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    _validator = widget.schema.compile(
      options: widget.options,
      baseUri: widget.baseUri,
    );
    _plan = _Plan(widget.schema.value, _validator.draft);
    _initial = _initialValue();
    _value = _initial;
    _errors = null;
    _inputErrors.clear();
    _invalidInputs.clear();
    _versions.clear();
  }

  Object? _initialValue() => _snapshot(
    identical(widget.initialValue, _absent)
        ? _emptyValue(_plan, useDefault: false)
        : widget.initialValue,
  );

  @override
  void didUpdateWidget(covariant SchemaForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schema != oldWidget.schema ||
        widget.options != oldWidget.options ||
        widget.baseUri != oldWidget.baseUri) {
      _prepare();
      _generation++;
      _rootKey = GlobalKey<FormFieldState<Object?>>();
    } else if (!identical(widget.initialValue, oldWidget.initialValue)) {
      _initial = _initialValue();
    }
  }

  List<ValidationError> get _diagnostics {
    if (_errors case final List<ValidationError> errors) {
      return errors;
    }
    var candidate = _value;
    for (final entry in _invalidInputs.entries) {
      candidate = _replace(candidate, _segments(entry.key), entry.value.text);
    }
    return _errors = _validator.errors(candidate);
  }

  String? _rootError() {
    if (_inputErrors.isNotEmpty) {
      final entry = _inputErrors.entries.first;
      return '${entry.key.isEmpty ? '/' : entry.key}: ${entry.value}';
    }
    final errors = _diagnostics;
    if (errors.isEmpty) {
      if (_invalidInputs.isNotEmpty) {
        final entry = _invalidInputs.entries.first;
        return '${entry.key.isEmpty ? '/' : entry.key}: '
            '${entry.value.parsingMessage}';
      }
      return null;
    }
    final first = errors.first;
    return '${first.instancePath.isEmpty ? '/' : first.instancePath}: '
        '${first.message}';
  }

  String? _fieldError(String path, {required bool isRequired}) {
    final inputError = _inputErrors[path];
    if (inputError != null) {
      return inputError;
    }
    if (isRequired && identical(_at(_value, path), _absent)) {
      final parent = path.substring(0, path.lastIndexOf('/'));
      if (_diagnostics.any(
        (error) =>
            error.instancePath == parent &&
            (error.keyword == 'required' || error.keyword == 'optional'),
      )) {
        return 'This property is required.';
      }
    }
    for (final error in _diagnostics) {
      if (error.instancePath == path) {
        return error.message;
      }
    }
    return _invalidInputs[path]?.parsingMessage;
  }

  void _change(
    String path,
    Object? value, {
    bool structure = false,
    bool clearDescendantErrors = true,
  }) {
    if (!widget.enabled || _resetting) {
      return;
    }
    final frozen = identical(value, _absent) ? value : _snapshot(value);
    setState(() {
      final wasPresent = !identical(_at(_value, path), _absent);
      _value = _replace(_value, _segments(path), frozen);
      if (wasPresent && identical(frozen, _absent)) {
        _removeEmptyOptionalAncestors(path);
      }
      _errors = null;
      _inputErrors.removeWhere(
        (key, _) =>
            key == path || clearDescendantErrors && key.startsWith('$path/'),
      );
      _invalidInputs.removeWhere(
        (key, _) =>
            key == path || clearDescendantErrors && key.startsWith('$path/'),
      );
      if (structure) {
        _versions[path] = (_versions[path] ?? 0) + 1;
      }
    });
    _rootKey.currentState?.didChange(_value);
    widget.onChanged?.call(_value);
  }

  void _removeEmptyOptionalAncestors(String path) {
    final segments = _segments(path);
    var plan = _plan;
    var pointer = '';
    final parents = <({String path, bool optional})>[];
    for (final segment in segments.take(segments.length - 1)) {
      pointer = '$pointer/${_escape(segment)}';
      if (plan.properties[segment] case final _Plan child) {
        parents.add((
          path: pointer,
          optional: !plan.required.contains(segment),
        ));
        plan = child;
      } else if (plan.type == SchemaType.array) {
        final index = int.tryParse(segment);
        if (index == null) {
          break;
        }
        parents.add((path: pointer, optional: false));
        plan = plan.itemAt(index);
      } else {
        break;
      }
    }
    for (final parent in parents.reversed) {
      final current = _at(_value, parent.path);
      if (parent.optional &&
          current is Map<String, Object?> &&
          current.isEmpty) {
        _value = _replace(_value, _segments(parent.path), _absent);
      }
    }
  }

  void _setInputError(String path, String? error) {
    if (!widget.enabled || _resetting) {
      return;
    }
    setState(() {
      if (_invalidInputs.remove(path) != null) {
        _errors = null;
      }
      if (error == null) {
        _inputErrors.remove(path);
      } else {
        _inputErrors[path] = error;
      }
    });
    _rootKey.currentState?.didChange(_value);
  }

  void _setInvalidInput(String path, String text, String parsingMessage) {
    if (!widget.enabled || _resetting) {
      return;
    }
    setState(() {
      _invalidInputs[path] = (text: text, parsingMessage: parsingMessage);
      _inputErrors.remove(path);
      _errors = null;
    });
    _rootKey.currentState?.didChange(_value);
  }

  void _reset() {
    // TextFormField.reset invokes onChanged with its old initial text after
    // the root reset. Ignore these callbacks until fresh editors are mounted.
    _resetting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetting = false);
    setState(() {
      _value = _initial;
      _inputErrors.clear();
      _invalidInputs.clear();
      _errors = null;
      _generation++;
    });
    widget.onChanged?.call(_value);
  }

  @override
  Widget build(BuildContext context) => FormField<Object?>(
    key: _rootKey,
    initialValue: _initial,
    enabled: widget.enabled,
    autovalidateMode: widget.autovalidateMode,
    validator: (_) => _rootError(),
    onSaved: (_) => widget.onSaved?.call(_value),
    onReset: _reset,
    builder: (state) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: ValueKey(_generation),
          child: _editor(context, _plan, '', isRequired: true),
        ),
        if (state.errorText != null) ...[
          SizedBox(height: _spacing(context)),
          Text(
            state.errorText!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );

  Widget _editor(
    BuildContext context,
    _Plan plan,
    String path, {
    required bool isRequired,
    bool parentEnabled = true,
  }) => KeyedSubtree(
    key: ValueKey((path, _versions[path] ?? 0)),
    child: _buildEditor(
      context,
      plan,
      path,
      isRequired: isRequired,
      parentEnabled: parentEnabled,
    ),
  );

  Widget _buildEditor(
    BuildContext context,
    _Plan plan,
    String path, {
    required bool isRequired,
    required bool parentEnabled,
  }) {
    final current = _at(_value, path);
    final present = !identical(current, _absent);
    final value = present ? current : null;
    final enabled =
        widget.enabled && parentEnabled && plan.attributes['readOnly'] != true;
    final field = SchemaField._(
      () => _fieldError(path, isRequired: isRequired),
      () => List.unmodifiable(
        _diagnostics.where((error) => error.instancePath == path),
      ),
      (text, parsingMessage) {
        if (enabled) {
          _setInvalidInput(path, text, parsingMessage);
        }
      },
      ({required bool resetEditor}) {
        if (enabled && !isRequired) {
          _change(path, _absent, structure: resetEditor);
        }
      },
      schema: plan.schema,
      instancePath: path,
      value: value,
      isPresent: present,
      isRequired: isRequired,
      enabled: enabled,
      autovalidateMode: widget.autovalidateMode,
      onChanged: (value) {
        if (enabled) {
          final emptyText =
              !isRequired &&
              value is String &&
              value.isEmpty &&
              plan.type == SchemaType.string &&
              !plan.fallback &&
              plan.choices == null;
          _change(path, emptyText ? _absent : value);
        }
      },
      setInputError: (error) {
        if (enabled) {
          _setInputError(path, error);
        }
      },
    );
    final custom = widget.pathBuilders[path] ?? widget.typeBuilders[plan.type];
    if (custom != null) {
      return custom(context, field);
    }
    if (plan.fallback) {
      return _jsonEditor(plan, field);
    }
    if (plan.choices != null) {
      return _enumEditor(plan, field);
    }
    if (plan.nullable && present && value == null) {
      return _nullableEditor(context, plan, field, null);
    }
    final editor = switch (plan.type) {
      SchemaType.string when !present || value is String => _textEditor(
        plan,
        field,
      ),
      SchemaType.number || SchemaType.integer
          when !present || _isNumber(value) =>
        _numberEditor(plan, field),
      SchemaType.boolean when !present || value is bool => _booleanEditor(
        plan,
        field,
      ),
      SchemaType.object when !present || value is Map<String, Object?> =>
        _objectEditor(context, plan, field),
      SchemaType.array when !present || value is List<Object?> => _arrayEditor(
        context,
        plan,
        field,
      ),
      _ => _jsonEditor(plan, field),
    };
    return plan.nullable
        ? _nullableEditor(context, plan, field, editor)
        : editor;
  }

  String _label(_Plan plan, String path) =>
      plan.attributes['title'] as String? ??
      (path.isEmpty ? 'Value' : _segments(path).last);

  String _fieldLabel(_Plan plan, SchemaField field) =>
      '${_label(plan, field.instancePath)}'
      '${field.isRequired ? '' : ' (optional)'}';

  InputDecoration _decoration(_Plan plan, SchemaField field) => InputDecoration(
    labelText: _fieldLabel(plan, field),
    helperText: plan.attributes['description'] as String?,
  );

  Widget _textEditor(_Plan plan, SchemaField field) => _SchemaTextField(
    key: ValueKey(('text', field.instancePath)),
    field: field,
    decoration: _decoration(plan, field),
    format: plan.attributes['format'] as String?,
  );

  Widget _numberEditor(_Plan plan, SchemaField field) => _SchemaNumberField(
    key: ValueKey(('number', field.instancePath)),
    field: field,
    decoration: _decoration(plan, field),
    integer: plan.type == SchemaType.integer,
  );

  Widget _jsonEditor(_Plan plan, SchemaField field) => _SchemaJsonField(
    key: ValueKey(('json', field.instancePath)),
    field: field,
    decoration: _decoration(plan, field),
  );

  Widget _booleanEditor(_Plan plan, SchemaField field) => FormField<bool>(
    initialValue: field.value as bool?,
    enabled: field.enabled,
    autovalidateMode: field.autovalidateMode,
    validator: field.validator,
    builder: (state) => InputDecorator(
      decoration: _decoration(plan, field).copyWith(errorText: state.errorText),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_fieldLabel(plan, field)),
        value: field.value == true,
        onChanged: field.enabled
            ? (value) {
                field.onChanged(value);
                state.didChange(value);
              }
            : null,
      ),
    ),
  );

  Widget _enumEditor(_Plan plan, SchemaField field) {
    final choices = plan.choices!;
    final index = field.isPresent
        ? choices.indexWhere((choice) => _equalJson(choice, field.value))
        : -1;
    return DropdownButtonFormField<int>(
      key: ValueKey((field.instancePath, index)),
      initialValue: index < 0 ? null : index,
      isExpanded: true,
      decoration: _decoration(plan, field),
      autovalidateMode: field.autovalidateMode,
      validator: field.validator,
      items: [
        for (var i = 0; i < choices.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(
              choices[i] is String
                  ? choices[i]! as String
                  : encodeJson(choices[i]),
            ),
          ),
      ],
      onChanged: field.enabled
          ? (index) {
              if (index != null) {
                field.onChanged(choices[index]);
              }
            }
          : null,
    );
  }

  Widget _nullableEditor(
    BuildContext context,
    _Plan plan,
    SchemaField field,
    Widget? editor,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Use null for ${_fieldLabel(plan, field)}'),
        value: field.isPresent && field.value == null,
        onChanged: field.enabled
            ? (useNull) => _change(
                field.instancePath,
                useNull
                    ? null
                    : field.isRequired
                    ? _emptyValue(plan, useDefault: false)
                    : _absent,
                structure: true,
              )
            : null,
      ),
      ?editor,
    ],
  );

  Widget _group(
    BuildContext context,
    _Plan plan,
    SchemaField field,
    List<Widget> children,
  ) => FormField<Object?>(
    initialValue: field.value,
    enabled: field.enabled,
    autovalidateMode: field.autovalidateMode,
    validator: field.validator,
    builder: (state) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _fieldLabel(plan, field),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (plan.attributes['description'] case final String description)
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        for (final child in children)
          Padding(
            padding: EdgeInsets.only(top: _spacing(context)),
            child: child,
          ),
        if (state.errorText != null)
          Padding(
            padding: EdgeInsets.only(top: _spacing(context)),
            child: Text(
              state.errorText!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );

  Widget _objectEditor(BuildContext context, _Plan plan, SchemaField field) =>
      _group(context, plan, field, [
        for (final entry in plan.properties.entries)
          _propertyEditor(context, plan, field, entry.key, entry.value),
        if (plan.attributes['additionalProperties'] != false ||
            field.value is Map<String, Object?> &&
                (field.value! as Map<String, Object?>).keys.any(
                  (name) => !plan.properties.containsKey(name),
                ))
          _additionalEditor(plan, field),
      ]);

  Widget _propertyEditor(
    BuildContext context,
    _Plan parent,
    SchemaField field,
    String name,
    _Plan plan,
  ) {
    final path = '${field.instancePath}/${_escape(name)}';
    final required = parent.required.contains(name);
    final present = !identical(_at(_value, path), _absent);
    final editor = _editor(
      context,
      plan,
      path,
      isRequired: required,
      parentEnabled: field.enabled,
    );
    if (required) {
      return editor;
    }
    final hasInput =
        present ||
        _inputErrors.keys.any(
          (key) => key == path || key.startsWith('$path/'),
        ) ||
        _invalidInputs.keys.any(
          (key) => key == path || key.startsWith('$path/'),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: editor),
        if (hasInput)
          IconButton(
            tooltip: 'Clear ${_label(plan, path)}',
            icon: const Icon(Icons.clear),
            onPressed: field.enabled && plan.attributes['readOnly'] != true
                ? () => _change(path, _absent, structure: true)
                : null,
          ),
      ],
    );
  }

  Widget _additionalEditor(_Plan plan, SchemaField field) {
    final additional = <String, Object?>{
      for (final entry
          in (field.value as Map<String, Object?>? ?? const <String, Object?>{})
              .entries)
        if (!plan.properties.containsKey(entry.key)) entry.key: entry.value,
    };
    return TextFormField(
      initialValue: encodeJson(additional, indent: '  '),
      enabled: field.enabled,
      decoration: const InputDecoration(
        labelText: 'Additional properties (JSON)',
      ),
      minLines: 3,
      maxLines: null,
      autovalidateMode: field.autovalidateMode,
      validator: field.validator,
      onChanged: (text) {
        if (text.isEmpty && !field.isRequired && plan.properties.isEmpty) {
          field._clearValue(resetEditor: false);
          return;
        }
        try {
          final decoded = text.isEmpty
              ? const <String, Object?>{}
              : decodeJson(text);
          if (decoded is! Map<String, Object?> ||
              decoded.keys.any(plan.properties.containsKey)) {
            field.setInputError(
              'Enter a JSON object with additional keys only.',
            );
            return;
          }
          final value = <String, Object?>{
            for (final entry
                in (_at(_value, field.instancePath) is Map<String, Object?>
                        ? _at(_value, field.instancePath)!
                              as Map<String, Object?>
                        : const <String, Object?>{})
                    .entries)
              if (plan.properties.containsKey(entry.key))
                entry.key: entry.value,
            ...decoded,
          };
          _change(
            field.instancePath,
            value.isEmpty && !field.isRequired ? _absent : value,
            clearDescendantErrors: false,
          );
        } on FormatException {
          field.setInputError('Enter valid JSON.');
        }
      },
    );
  }

  Widget _arrayEditor(BuildContext context, _Plan plan, SchemaField field) {
    final items = field.value as List<Object?>? ?? const <Object?>[];
    return _group(context, plan, field, [
      for (var index = 0; index < items.length; index++)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _editor(
              context,
              plan.itemAt(index),
              '${field.instancePath}/$index',
              isRequired: true,
              parentEnabled: field.enabled,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                tooltip: 'Remove item ${index + 1}',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: field.enabled
                    ? () => _change(
                        field.instancePath,
                        items.length == 1 && !field.isRequired
                            ? _absent
                            : [...items.take(index), ...items.skip(index + 1)],
                        structure: true,
                      )
                    : null,
              ),
            ),
          ],
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
          onPressed: field.enabled
              ? () => _change(field.instancePath, [
                  ...items,
                  _emptyValue(plan.itemAt(items.length)),
                ], structure: true)
              : null,
        ),
      ),
    ]);
  }
}

double _spacing(BuildContext context) =>
    Theme.of(context).extension<SchemaUiTheme>()?.spacing ??
    const SchemaUiTheme().spacing;

class _Plan {
  _Plan(Object value, SchemaDraft draft) {
    schema = JsonSchema.fromJson(value, draft: draft);
    attributes = value is Map<String, Object?> ? value : const {};
    final complex = [
      r'$ref',
      r'$dynamicRef',
      r'$recursiveRef',
      'allOf',
      'anyOf',
      'oneOf',
      'if',
      'extends',
    ].any(attributes.containsKey);
    final declared = attributes['type'];
    if (declared is String) {
      type = _type(declared);
    } else if (declared is List<Object?>) {
      final nonNull = declared.where((item) => item != 'null').toList();
      nullable = declared.contains('null') && nonNull.length == 1;
      if (nonNull.length == 1 && nonNull.first is String) {
        type = _type(nonNull.first! as String);
      }
    }
    fallback = complex || value is bool;
    if (fallback) {
      return;
    }
    if (declared == null && attributes.containsKey('properties')) {
      type = SchemaType.object;
    } else if (declared == null &&
        (attributes.containsKey('items') ||
            attributes.containsKey('prefixItems'))) {
      type = SchemaType.array;
    }
    if (attributes['enum'] case final List<Object?> enumeration) {
      choices = enumeration;
    } else if (draft.index >= SchemaDraft.draft6.index &&
        attributes.containsKey('const')) {
      choices = [attributes['const']];
    }
    if (attributes['properties'] case final Map<String, Object?> props) {
      for (final entry in props.entries) {
        properties[entry.key] = _Plan(entry.value!, draft);
      }
    }
    if (draft.isLegacy) {
      for (final entry in properties.entries) {
        final child = entry.value.attributes;
        if (draft == SchemaDraft.draft3
            ? child['required'] == true
            : child['optional'] != true) {
          required.add(entry.key);
        }
      }
    } else if (attributes['required'] case final List<Object?> names) {
      required.addAll(names.cast<String>());
    }
    final prefix = draft == SchemaDraft.draft202012
        ? attributes['prefixItems']
        : attributes['items'];
    if (prefix is List<Object?>) {
      prefixItems.addAll(prefix.map((item) => _Plan(item!, draft)));
      final rest = draft == SchemaDraft.draft202012
          ? attributes['items']
          : draft.index < SchemaDraft.draft3.index
          ? attributes['additionalProperties']
          : attributes['additionalItems'];
      items = _Plan(rest ?? <String, Object?>{}, draft);
    } else if (attributes['items'] case final Object itemSchema) {
      items = _Plan(itemSchema, draft);
    }
  }

  late final JsonSchema schema;
  late final Map<String, Object?> attributes;
  SchemaType? type;
  var nullable = false;
  var fallback = false;
  List<Object?>? choices;
  final properties = <String, _Plan>{};
  final required = <String>{};
  final prefixItems = <_Plan>[];
  _Plan? items;

  _Plan itemAt(int index) => index < prefixItems.length
      ? prefixItems[index]
      : items ?? _Plan(<String, Object?>{}, schema.draft);
}

SchemaType? _type(String name) {
  for (final type in SchemaType.values) {
    if (type.jsonName == name) {
      return type;
    }
  }
  return null;
}

Object? _emptyValue(_Plan plan, {bool useDefault = true}) {
  if (useDefault && plan.attributes.containsKey('default')) {
    return plan.attributes['default'];
  }
  if (plan.choices?.isNotEmpty == true) {
    return plan.choices!.first;
  }
  return switch (plan.type) {
    SchemaType.object => <String, Object?>{},
    SchemaType.array => <Object?>[],
    SchemaType.string => '',
    SchemaType.number || SchemaType.integer => 0,
    SchemaType.boolean => false,
    _ => null,
  };
}

bool _isNumber(Object? value) =>
    value is num && value.isFinite || value is BigInt || value is JsonNumber;

bool _equalJson(Object? left, Object? right) {
  if (_isNumber(left) && _isNumber(right)) {
    return JsonNumber.parse(encodeJson(left))
            .compareTo(JsonNumber.parse(encodeJson(right))) ==
        0;
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_equalJson(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _equalJson(left[key], right[key]),
        );
  }
  return left == right;
}

Object? _snapshot(Object? value, [Set<Object>? ancestors]) {
  if (value == null || value is String || value is bool || _isNumber(value)) {
    return value;
  }
  final active = ancestors ?? Set<Object>.identity();
  if (!active.add(value)) {
    throw ArgumentError.value(value, 'value', 'JSON cannot contain cycles.');
  }
  try {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(
        value.map((key, item) => MapEntry(key, _snapshot(item, active))),
      );
    }
    if (value is List<Object?>) {
      return List<Object?>.unmodifiable(
        value.map((item) => _snapshot(item, active)),
      );
    }
    throw ArgumentError.value(value, 'value', 'Expected a decoded JSON value.');
  } finally {
    active.remove(value);
  }
}

String _escape(String segment) =>
    segment.replaceAll('~', '~0').replaceAll('/', '~1');

List<String> _segments(String path) => path.isEmpty
    ? const []
    : path
          .substring(1)
          .split('/')
          .map((segment) => segment.replaceAll('~1', '/').replaceAll('~0', '~'))
          .toList();

Object? _at(Object? value, String path) {
  for (final segment in _segments(path)) {
    if (value is Map<String, Object?> && value.containsKey(segment)) {
      value = value[segment];
    } else if (value is List<Object?>) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= value.length) {
        return _absent;
      }
      value = value[index];
    } else {
      return _absent;
    }
  }
  return value;
}

Object? _replace(Object? value, List<String> path, Object? replacement) {
  if (path.isEmpty) {
    return replacement;
  }
  final segment = path.first;
  final tail = path.sublist(1);
  if (value is List<Object?>) {
    final result = List<Object?>.of(value);
    final index = int.parse(segment);
    result[index] = _replace(result[index], tail, replacement);
    return List<Object?>.unmodifiable(result);
  }
  final result = value is Map<String, Object?>
      ? Map<String, Object?>.of(value)
      : <String, Object?>{};
  if (identical(replacement, _absent) && !result.containsKey(segment)) {
    return value;
  }
  if (tail.isEmpty && identical(replacement, _absent)) {
    result.remove(segment);
  } else {
    result[segment] = _replace(result[segment], tail, replacement);
  }
  return Map<String, Object?>.unmodifiable(result);
}
