import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';
import 'package:schema_ui_example/main.dart';
import 'package:schema_ui_example/schema_builder_screen.dart';

final _json = find.byKey(const ValueKey('schema-json'));

Finder _field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

String _source(WidgetTester tester) =>
    tester.widget<TextField>(_json).controller!.text;

Future<void> _open(WidgetTester tester, {double width = 1280}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const ExampleApp());
  await tester.tap(find.text('Schema builder'));
  await tester.pumpAndSettle();
}

Future<void> _annotations(WidgetTester tester, Finder options) async {
  final bar = find.descendant(of: options, matching: find.byType(TabBar)).first;
  final tab = find.descendant(
    of: bar,
    matching: find.widgetWithText(Tab, 'Annotations'),
  );
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'visual editor and JSON appear side by side and stay synchronized',
    (tester) async {
      await _open(tester);
      expect(find.byType(SchemaBuilderScreen), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(SchemaEditor)).dx,
        lessThan(tester.getTopLeft(_json).dx),
      );
      final field = _field('Property name').last;
      await tester.ensureVisible(field);
      final before = tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .controller;
      await tester.enterText(field, 'replyTo');
      await tester.pump();
      final after = tester
          .widget<TextField>(
            find.descendant(
              of: _field('Property name').last,
              matching: find.byType(TextField),
            ),
          )
          .controller;
      expect(after, same(before));
      expect(after!.text, 'replyTo');
      final document = schema.JsonSchema.parse(_source(tester));
      expect((document.toJson() as Map)['properties'], contains('replyTo'));
      expect(document.compile().isValid({'name': 'Example'}), isTrue);
    },
  );

  testWidgets('pasted JSON replaces properties and reusable definitions', (
    tester,
  ) async {
    await _open(tester);
    final document = schema.JsonSchema.fromJson({
      r'$schema': schema.SchemaDraft.draft202012.metaSchemaUri,
      'type': 'object',
      'properties': {
        'enabled': {r'$ref': r'#/$defs/flag'},
      },
      r'$defs': {
        'flag': {'type': 'boolean'},
      },
      'required': ['enabled'],
      'additionalProperties': false,
      'x-annotation': {'source': 'pasted'},
    });
    final text = document.toJsonString(indent: '  ');
    await tester.enterText(_json, text);
    await tester.pumpAndSettle();
    expect(_source(tester), text);
    final editor = tester.widget<SchemaEditor>(find.byType(SchemaEditor));
    expect(editor.schema!.toJson(), document.toJson());
    expect(_field('Property name'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: _field('Property name'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'enabled',
    );
    await tester.ensureVisible(_field('Definition name'));
    await tester.enterText(_field('Definition name'), 'toggle');
    await tester.pump();
    final result = schema.JsonSchema.parse(_source(tester));
    expect((result.toJson() as Map)['x-annotation'], {'source': 'pasted'});
    expect((result.toJson() as Map)[r'$defs'], {
      'toggle': {'type': 'boolean'},
    });
    expect(result.compile().isValid({'enabled': true}), isTrue);
    expect(result.compile().isValid({'enabled': 'yes'}), isFalse);
    expect(result.compile().isValid({'enabled': true, 'extra': 1}), isFalse);
  });

  testWidgets('JSON edits preserve visual scroll and expanded options', (
    tester,
  ) async {
    await _open(tester);
    await tester.ensureVisible(find.text('More options').first);
    await tester.tap(find.text('More options').first);
    await tester.pumpAndSettle();
    await _annotations(tester, find.byType(ExpansionTile).first);
    await tester.ensureVisible(find.text('More options').at(1));
    await tester.tap(find.text('More options').at(1));
    await tester.pumpAndSettle();
    await _annotations(tester, find.byType(ExpansionTile).at(1));
    expect(_field('Title'), findsNWidgets(2));
    final scroll = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('schema-visual-scroll')),
        )
        .controller!;
    scroll.jumpTo(250);
    await tester.tap(_json);
    await tester.pumpAndSettle();
    final offset = scroll.offset;
    expect(offset, greaterThan(0));

    final document =
        schema.decodeJson(_source(tester))! as Map<String, Object?>;
    document['title'] = 'Account';
    (document['properties']! as Map)['name'] = {
      'type': 'string',
      'minLength': 4,
      'title': 'Full name',
    };
    final code = schema.encodeJson(document, indent: '  ');
    await tester.enterText(_json, code);
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(offset, 0.01));
    expect(_field('Title'), findsNWidgets(2));
    final titles = tester
        .widgetList<TextField>(
          find.descendant(
            of: _field('Title'),
            matching: find.byType(TextField),
          ),
        )
        .map((field) => field.controller!.text);
    expect(titles, ['Account', 'Full name']);
    expect(_source(tester), code);

    await tester.enterText(_json, '{"type":');
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(offset, 0.01));
    await tester.enterText(_json, code);
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(offset, 0.01));
    expect(_field('Title'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed JSON and invalid schemas preserve the active editor', (
    tester,
  ) async {
    await _open(tester);
    final original = tester
        .widget<SchemaEditor>(find.byType(SchemaEditor))
        .schema;
    for (final text in [
      '{"type":',
      '{"type":"string","minLength":-1}',
      r'{"$ref":"#/$defs/missing"}',
      r'{"$schema":"http://json-schema.org/draft-07/schema#","type":"string"}',
    ]) {
      await tester.enterText(_json, text);
      await tester.pump();
      expect(_source(tester), text);
      expect(tester.widget<TextField>(_json).decoration!.errorText, isNotNull);
      expect(
        tester.widget<SchemaEditor>(find.byType(SchemaEditor)).schema,
        same(original),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Copy JSON'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(_json, '{"type":"integer","minimum":1}');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_json).decoration!.errorText, isNull);
    expect(
      tester
          .widget<SchemaEditor>(find.byType(SchemaEditor))
          .schema!
          .compile()
          .isValid(0),
      isFalse,
    );
    expect(_field('Property name'), findsNothing);
  });

  testWidgets('invalid visual constraints preserve JSON until corrected', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(_json, '{"type":"number"}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_field('Minimum'));
    await tester.enterText(_field('Minimum'), '-');
    await tester.pump();
    expect(_source(tester), '{"type":"number"}');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Copy JSON'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(_json).decoration!.helperText,
      contains('errors'),
    );
    await tester.enterText(_field('Minimum'), '12');
    await tester.pump();
    expect((schema.decodeJson(_source(tester)) as Map)['minimum'], 12);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Copy JSON'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Reset schema'));
    await tester.pumpAndSettle();
    expect((schema.decodeJson(_source(tester)) as Map)['title'], 'Contact');
    expect(_field('Property name'), findsNWidgets(2));
    await tester.ensureVisible(find.text('More options').first);
    await tester.tap(find.text('More options').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_field('Minimum properties'));
    await tester.enterText(_field('Minimum properties'), '-');
    await tester.pump();
    expect(
      tester.widget<TextField>(_json).decoration!.helperText,
      contains('errors'),
    );
    await tester.tap(find.text('Reset schema'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_json).decoration!.helperText,
      'Draft 2020-12',
    );
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isTrue);
  });

  testWidgets('formats and copies the schema currently displayed in JSON', (
    tester,
  ) async {
    await _open(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.enterText(_json, '{"type":"string","minLength":2}');
    await tester.pump();
    await tester.tap(find.text('Format JSON'));
    await tester.pump();
    expect(_source(tester), contains('\n'));
    expect((schema.decodeJson(_source(tester)) as Map)['minLength'], 2);
    await tester.tap(find.text('Copy JSON'));
    await tester.pump();
    expect(copied, _source(tester));
    expect(find.text('Schema JSON copied'), findsOneWidget);
  });

  testWidgets('boolean schemas and narrow layouts remain editable', (
    tester,
  ) async {
    await _open(tester, width: 400);
    expect(
      tester.getTopLeft(_json).dy,
      greaterThan(tester.getTopLeft(find.byType(SchemaEditor)).dy),
    );
    await tester.enterText(_json, 'false');
    await tester.pumpAndSettle();
    expect(
      tester.widget<SchemaEditor>(find.byType(SchemaEditor)).schema!.toJson(),
      false,
    );
    expect(find.text('No values'), findsOneWidget);
    expect(_source(tester), 'false');
    await tester.enterText(_json, 'true');
    await tester.pumpAndSettle();
    expect(find.text('Any value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
