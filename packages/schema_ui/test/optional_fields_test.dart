import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Finder _field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            widget.decoration?.labelText == '$label (optional)'),
  ),
  matching: find.byType(TextFormField),
);

Future<void> _edit(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all optional types are visible without creating JSON properties',
    (tester) async {
      final key = GlobalKey<FormState>();
      var changes = 0;
      Object? saved;
      final document = schema.object({
        'note': schema.string().min(1).optional(),
        'count': schema.integer().min(1).optional(),
        'flag': schema.boolean().optional(),
        'role': schema.enumValues(['reader', 'editor']).optional(),
        'details': schema.object({'name': schema.string().min(1)}).optional(),
        'tags': schema.array(schema.string()).min(1).optional(),
        'suggestion': schema.string().defaultValue('Example').optional(),
      }).toJsonSchema();
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: document,
              autovalidateMode: AutovalidateMode.always,
              onChanged: (_) => changes++,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(_field('note'), findsOneWidget);
      expect(_field('count'), findsOneWidget);
      expect(_field('name'), findsOneWidget);
      expect(find.text('details (optional)'), findsOneWidget);
      expect(find.text('tags (optional)'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'flag (optional)'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: _field('suggestion'),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(key.currentState!.validate(), isTrue);
      key.currentState!.save();
      expect(saved, <String, Object?>{});
      expect(changes, 0);
    },
  );

  testWidgets(
    'clearing optional text removes the property and keeps editor focus',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.object({
                'note': schema.string().min(1).optional(),
              }).toJsonSchema(),
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await _edit(tester, 'note', 'Example');
      expect(changed, {'note': 'Example'});
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(focus.hasFocus, isTrue);
      await _edit(tester, 'note', '');
      expect(changed, <String, Object?>{});
      expect(key.currentState!.validate(), isTrue);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode,
        same(focus),
      );
      expect(focus.hasFocus, isTrue);
      await _edit(tester, 'note', 'Updated');
      expect(changed, {'note': 'Updated'});
    },
  );

  testWidgets(
    'empty optional numeric input omits it and clears pending diagnostics',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? saved;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.object({
                'count': schema.integer().min(1).optional(),
              }).toJsonSchema(),
              initialValue: {'count': 7},
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      await _edit(tester, 'count', '-');
      expect(key.currentState!.validate(), isFalse);
      await _edit(tester, 'count', '');
      expect(key.currentState!.validate(), isTrue);
      key.currentState!.save();
      expect(saved, <String, Object?>{});
      await _edit(tester, 'count', '0');
      expect(key.currentState!.validate(), isFalse);
      key.currentState!.save();
      expect(saved, {'count': 0});
    },
  );

  testWidgets(
    'an explicitly selected false boolean is kept and can be cleared',
    (tester) async {
      Object? changed;
      await tester.pumpWidget(
        _host(
          SchemaForm(
            schema: schema.object({
              'flag': schema.boolean().optional(),
            }).toJsonSchema(),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      final toggle = find.descendant(
        of: find.widgetWithText(SwitchListTile, 'flag (optional)'),
        matching: find.byType(Switch),
      );
      expect(changed, isNull);
      await _tap(tester, toggle);
      expect(changed, {'flag': true});
      await _tap(tester, toggle);
      expect(changed, {'flag': false});
      await _tap(tester, find.byTooltip('Clear flag'));
      expect(changed, <String, Object?>{});
    },
  );

  testWidgets(
    'explicit null is kept and switching it off omits the optional field',
    (tester) async {
      Object? changed;
      await tester.pumpWidget(
        _host(
          SchemaForm(
            schema: schema.object({
              'note': schema.string().nullable().optional(),
            }).toJsonSchema(),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      final toggle = find.text('Use null for note (optional)');
      await _tap(tester, toggle);
      expect(changed, {'note': null});
      await _tap(tester, toggle);
      expect(changed, <String, Object?>{});
      expect(_field('note'), findsOneWidget);
    },
  );

  testWidgets('an empty string enum choice is an explicit value', (
    tester,
  ) async {
    Object? changed;
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema.object({
            'role': schema.enumValues(['', 'reader']).optional(),
          }).toJsonSchema(),
          onChanged: (value) => changed = value,
        ),
      ),
    );
    final dropdown = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(dropdown.initialValue, isNull);
    dropdown.onChanged!(0);
    await tester.pump();
    expect(changed, {'role': ''});
    await _tap(tester, find.byTooltip('Clear role'));
    expect(changed, <String, Object?>{});
  });

  testWidgets(
    'clearing a nested optional child removes empty optional ancestors',
    (tester) async {
      Object? changed;
      await tester.pumpWidget(
        _host(
          SchemaForm(
            schema: schema.object({
              'details': schema.object({
                'note': schema.string().optional(),
              }).optional(),
            }).toJsonSchema(),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await _edit(tester, 'note', 'Example');
      expect(changed, {
        'details': {'note': 'Example'},
      });
      await _edit(tester, 'note', '');
      expect(changed, <String, Object?>{});
      expect(find.text('details (optional)'), findsOneWidget);
    },
  );

  testWidgets(
    'clearing pending nested input never creates absent parent objects',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.object({
                'details': schema.object({
                  'count': schema.integer().optional(),
                }).optional(),
              }).toJsonSchema(),
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await _edit(tester, 'count', '-');
      expect(key.currentState!.validate(), isFalse);
      await _edit(tester, 'count', '');
      expect(changed, <String, Object?>{});
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets('removing the last optional array item omits the array', (
    tester,
  ) async {
    Object? changed;
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema.object({
            'tags': schema.array(schema.string()).optional(),
          }).toJsonSchema(),
          onChanged: (value) => changed = value,
        ),
      ),
    );
    await _tap(tester, find.text('Add item'));
    expect(changed, {
      'tags': [''],
    });
    await _edit(tester, '0', 'Example');
    expect(changed, {
      'tags': ['Example'],
    });
    await _tap(tester, find.byTooltip('Remove item 1'));
    expect(changed, <String, Object?>{});
    expect(find.text('Add item'), findsOneWidget);
  });

  testWidgets(
    'initial empty and default-looking values remain intact on save',
    (tester) async {
      final key = GlobalKey<FormState>();
      const initial = <String, Object?>{
        'note': '',
        'count': 0,
        'flag': false,
        'details': <String, Object?>{},
        'tags': <Object?>[],
        'nullable': null,
      };
      Object? saved;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.object({
                'note': schema.string().optional(),
                'count': schema.integer().optional(),
                'flag': schema.boolean().optional(),
                'details': schema.object({}).optional(),
                'tags': schema.array(schema.string()).optional(),
                'nullable': schema.string().nullable().optional(),
              }).toJsonSchema(),
              initialValue: initial,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isTrue);
      key.currentState!.save();
      expect(saved, initial);
      expect(initial, containsPair('note', ''));
    },
  );

  testWidgets('custom optional widgets can assign and clear values', (
    tester,
  ) async {
    SchemaField? selected;
    Object? changed;
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema.object({
            'flag': schema.boolean().optional(),
          }).toJsonSchema(),
          onChanged: (value) => changed = value,
          pathBuilders: {
            '/flag': (_, field) {
              selected = field;
              return const Text('Custom optional flag');
            },
          },
        ),
      ),
    );
    expect(selected!.isRequired, isFalse);
    expect(selected!.isPresent, isFalse);
    selected!.onChanged(false);
    await tester.pump();
    expect(changed, {'flag': false});
    expect(selected!.isPresent, isTrue);
    selected!.clear();
    await tester.pump();
    expect(changed, <String, Object?>{});
    expect(selected!.isPresent, isFalse);
  });

  testWidgets(
    'required fields cannot be omitted through the custom clear API',
    (tester) async {
      SchemaField? selected;
      await tester.pumpWidget(
        _host(
          SchemaForm(
            schema: schema.string().toJsonSchema(),
            initialValue: 'Example',
            pathBuilders: {
              '': (_, field) {
                selected = field;
                return const Text('Custom required root');
              },
            },
          ),
        ),
      );
      expect(selected!.clear, throwsStateError);
      expect(selected!.value, 'Example');
    },
  );

  testWidgets('read-only optional values cannot be cleared', (tester) async {
    var changes = 0;
    SchemaField? selected;
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema.JsonSchema.fromJson({
            'type': 'object',
            'properties': {
              'note': {'type': 'string', 'readOnly': true},
            },
            'additionalProperties': false,
          }),
          initialValue: {'note': 'Example'},
          onChanged: (_) => changes++,
          pathBuilders: {
            '/note': (_, field) {
              selected = field;
              return const Text('Read-only note');
            },
          },
        ),
      ),
    );
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Clear note',
      ),
    );
    expect(button.onPressed, isNull);
    selected!.clear();
    expect(changes, 0);
  });

  testWidgets('reset restores absence and keeps optional controls visible', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Object? changed;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'note': schema.string().optional(),
            }).toJsonSchema(),
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    await _edit(tester, 'note', 'Example');
    key.currentState!.reset();
    await tester.pump();
    expect(changed, <String, Object?>{});
    expect(_field('note'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: _field('note'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('optional JSON values can be assigned explicitly and cleared', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Object? changed;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.JsonSchema.fromJson({
              'type': 'object',
              'properties': {'payload': true},
              'additionalProperties': false,
            }),
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    expect(_field('payload'), findsOneWidget);
    expect(key.currentState!.validate(), isTrue);
    await _edit(tester, 'payload', '""');
    expect(changed, {'payload': ''});
    await _edit(tester, 'payload', 'null');
    expect(changed, {'payload': null});
    await _edit(tester, 'payload', '[');
    expect(key.currentState!.validate(), isFalse);
    await _edit(tester, 'payload', '');
    expect(changed, <String, Object?>{});
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets(
    'clearing optional children keeps required parents and array items',
    (tester) async {
      Object? changed;
      await tester.pumpWidget(
        _host(
          SchemaForm(
            schema: schema.object({
              'details': schema.object({'note': schema.string().optional()}),
              'tags': schema.array(
                schema.object({'tag': schema.string().optional()}),
              ),
            }).toJsonSchema(),
            initialValue: {
              'details': {'note': 'Example'},
              'tags': [
                {'tag': 'Example'},
              ],
            },
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await _edit(tester, 'note', '');
      expect(changed, {
        'details': <String, Object?>{},
        'tags': [
          {'tag': 'Example'},
        ],
      });
      await _edit(tester, 'tag', '');
      expect(changed, {
        'details': <String, Object?>{},
        'tags': [<String, Object?>{}],
      });
    },
  );

  testWidgets(
    'an optional object enforces required children once it has a value',
    (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.object({
                'details': schema.object({
                  'name': schema.string().min(1),
                  'note': schema.string().optional(),
                }).optional(),
              }).toJsonSchema(),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isTrue);
      await _edit(tester, 'note', 'Example');
      expect(key.currentState!.validate(), isFalse);
      await _edit(tester, 'name', 'Required value');
      expect(key.currentState!.validate(), isTrue);
      await _tap(tester, find.byTooltip('Clear details'));
      expect(key.currentState!.validate(), isTrue);
    },
  );
}
