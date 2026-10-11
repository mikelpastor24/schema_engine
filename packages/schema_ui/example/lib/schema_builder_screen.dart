import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

/// Demonstrates synchronized visual and JSON editing of a schema document.
class SchemaBuilderScreen extends StatefulWidget {
  /// Creates the interactive schema authoring example.
  const SchemaBuilderScreen({super.key});

  @override
  State<SchemaBuilderScreen> createState() => _SchemaBuilderScreenState();
}

class _SchemaBuilderScreenState extends State<SchemaBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visualScrollController = ScrollController();
  final _initial = schema.JsonSchema.build(
    type: schema.SchemaType.object,
    title: 'Contact',
    properties: {
      'name': schema.JsonSchema.build(
        type: schema.SchemaType.string,
        minLength: 1,
      ),
      'email': schema.JsonSchema.build(
        type: schema.SchemaType.string,
        format: 'email',
      ),
    },
    required: ['name'],
  );
  late schema.JsonSchema _schema;
  late TextEditingController _jsonController;
  String? _jsonError;
  var _visualValid = true;
  var _editorRevision = 0;

  double get _spacing =>
      Theme.of(context).extension<SchemaUiTheme>()?.spacing ?? 16;

  @override
  void initState() {
    super.initState();
    _schema = _initial;
    _jsonController = TextEditingController(
      text: _schema.toJsonString(indent: '  '),
    );
  }

  @override
  void dispose() {
    _visualScrollController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  void _fromVisual(schema.JsonSchema document) {
    setState(() {
      _schema = document;
      _jsonError = null;
      _visualValid = true;
      final text = document.toJsonString(indent: '  ');
      if (_jsonController.text != text) {
        _jsonController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
  }

  void _fromJson(String source) {
    try {
      final document = schema.JsonSchema.parse(source);
      if (document.draft != schema.SchemaDraft.draft202012) {
        throw const FormatException(
          'This editor supports Draft 2020-12. Select a 2020-12 schema.',
        );
      }
      document.compile();
      setState(() {
        _schema = document;
        _jsonError = null;
        _visualValid = true;
      });
    } on FormatException catch (error) {
      setState(() => _jsonError = error.message);
    } on schema.SchemaException catch (error) {
      setState(() => _jsonError = '${error.schemaPath}: ${error.message}');
    } on schema.ReferenceException catch (error) {
      setState(() => _jsonError = error.message);
    }
  }

  void _reset() {
    if (_visualScrollController.hasClients) {
      _visualScrollController.jumpTo(0);
    }
    setState(() {
      _editorRevision++;
      _schema = _initial;
      _jsonController.text = _initial.toJsonString(indent: '  ');
      _jsonError = null;
      _visualValid = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Schema builder')),
    body: Padding(
      padding: EdgeInsets.all(_spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: _spacing,
            children: [
              FilledButton.icon(
                onPressed: _jsonError == null && _visualValid
                    ? () {
                        if (_formKey.currentState!.validate()) {
                          Clipboard.setData(
                            ClipboardData(text: _jsonController.text),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Schema JSON copied')),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.copy),
                label: const Text('Copy JSON'),
              ),
              TextButton(
                onPressed: _jsonError == null && _visualValid
                    ? () => _fromVisual(_schema)
                    : null,
                child: const Text('Format JSON'),
              ),
              TextButton(onPressed: _reset, child: const Text('Reset schema')),
            ],
          ),
          SizedBox(height: _spacing),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('schema-visual-scroll'),
                        controller: _visualScrollController,
                        primary: false,
                        child: Form(
                          key: _formKey,
                          child: SchemaEditor(
                            key: ValueKey(_editorRevision),
                            schema: _schema,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: _fromVisual,
                            onValidityChanged: (valid) =>
                                setState(() => _visualValid = valid),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: wide ? _spacing : 0,
                      height: wide ? 0 : _spacing,
                    ),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('schema-json'),
                        controller: _jsonController,
                        keyboardType: TextInputType.multiline,
                        minLines: null,
                        maxLines: null,
                        expands: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          labelText: 'JSON Schema',
                          alignLabelWithHint: true,
                          errorText: _jsonError,
                          helperText: _visualValid ? 'Draft 2020-12' : 'Correct the visual editor errors to update JSON.',
                        ),
                        onChanged: _fromJson,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
