import 'package:flutter/material.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

import 'schema_builder_screen.dart';

/// Runs a sample schema editor using the surrounding Material theme.
void main() => runApp(const ExampleApp());

/// Demonstrates JSON instance forms and visual JSON Schema authoring.
class ExampleApp extends StatelessWidget {
  /// Creates the sample application.
  const ExampleApp({super.key, this.messages = const SchemaFormMessages()});

  /// Messages shared by generated fields and the customized biography editor.
  final SchemaFormMessages messages;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Schema forms',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      extensions: const [SchemaUiTheme(spacing: 12)],
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      extensions: const [SchemaUiTheme(spacing: 12)],
    ),
    home: _EditorScreen(messages: messages),
  );
}

class _EditorScreen extends StatefulWidget {
  const _EditorScreen({required this.messages});

  final SchemaFormMessages messages;

  @override
  State<_EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<_EditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _options = schema.SchemaOptions(assertFormats: true);
  final _document = schema.object({
    'name': schema.string().min(1).withKeywords({'title': 'Name'}),
    'biography': schema.string().max(500).withKeywords({
      'title': 'Biography',
    }).optional(),
    'age': schema.integer().nonnegative().withKeywords({
      'title': 'Age',
    }).optional(),
    'amount': schema.number().nonnegative().multipleOf(0.01).withKeywords({
      'title': 'Amount',
    }).optional(),
    'email': schema.string().email().withKeywords({
      'title': 'Email',
    }).optional(),
    'website': schema.string().url().withKeywords({
      'title': 'Website',
    }).optional(),
    'active': schema.boolean().withKeywords({'title': 'Active'}),
    'role': schema.enumValues(['reader', 'editor']).withKeywords({
      'title': 'Role',
    }),
    'tags': schema.array(schema.string().min(1)).withKeywords({
      'title': 'Tags',
    }).optional(),
  }).toJsonSchema();
  String? _savedJson;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Schema forms'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SchemaBuilderScreen(),
            ),
          ),
          icon: const Icon(Icons.account_tree_outlined),
          label: const Text('Schema builder'),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(
        Theme.of(context).extension<SchemaUiTheme>()!.spacing,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchemaForm(
              schema: _document,
              messages: widget.messages,
              options: _options,
              initialValue: const {
                'name': 'Example',
                'active': true,
                'role': 'reader',
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              pathBuilders: {'/biography': _biographyEditor},
              onChanged: (_) {
                if (_savedJson != null) {
                  setState(() => _savedJson = null);
                }
              },
              onSaved: (instance) => setState(() {
                _savedJson = schema.encodeJson(instance, indent: '  ');
              }),
            ),
            SizedBox(
              height: Theme.of(context).extension<SchemaUiTheme>()!.spacing,
            ),
            Wrap(
              spacing: Theme.of(context).extension<SchemaUiTheme>()!.spacing,
              children: [
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                    }
                  },
                  child: const Text('Save instance'),
                ),
                TextButton(
                  onPressed: () {
                    _formKey.currentState!.reset();
                    setState(() => _savedJson = null);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            if (_savedJson != null) SelectableText(_savedJson!),
          ],
        ),
      ),
    ),
  );

  Widget _biographyEditor(BuildContext context, SchemaField field) =>
      TextFormField(
        initialValue: field.value as String?,
        enabled: field.enabled,
        autovalidateMode: field.autovalidateMode,
        decoration: InputDecoration(labelText: field.label),
        minLines: 3,
        maxLines: null,
        validator: field.validator,
        onChanged: field.onChanged,
      );
}
