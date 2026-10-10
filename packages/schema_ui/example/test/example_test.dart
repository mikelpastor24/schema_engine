import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';
import 'package:schema_ui_example/main.dart';

Finder _textField(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

String? _fieldError(WidgetTester tester, String label) => tester
    .widget<InputDecorator>(
      find.descendant(
        of: _textField(label),
        matching: find.byType(InputDecorator),
      ),
    )
    .decoration
    .errorText;

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save instance'));
  await tester.tap(find.text('Save instance'));
  await tester.pump();
}

void main() {
  testWidgets('invalid email and website show schema errors and cannot save', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.enterText(_textField('Email (optional)'), '12231312312');
    await tester.enterText(_textField('Website (optional)'), '12231312312');
    await _save(tester);

    expect(find.byType(SelectableText), findsNothing);
    final form = tester.widget<SchemaForm>(find.byType(SchemaForm));
    final errors = form.schema
        .compile(options: schema.SchemaOptions(assertFormats: true))
        .errors({
          'name': 'Example',
          'active': true,
          'role': 'reader',
          'email': '12231312312',
          'website': '12231312312',
        });
    expect(errors.map((error) => error.instancePath), ['/email', '/website']);
    for (final error in errors) {
      expect(error.keyword, 'format');
      final label = error.instancePath == '/email' ? 'Email' : 'Website';
      expect(_fieldError(tester, '$label (optional)'), error.message);
      expect(find.text(error.message), findsWidgets);
    }

    await tester.enterText(
      _textField('Email (optional)'),
      'reader@example.com',
    );
    await _save(tester);
    expect(find.byType(SelectableText), findsNothing);
    expect(_fieldError(tester, 'Email (optional)'), isNull);
    expect(_fieldError(tester, 'Website (optional)'), isNotNull);

    await tester.enterText(
      _textField('Website (optional)'),
      'https://example.com',
    );
    await _save(tester);
    expect(_fieldError(tester, 'Website (optional)'), isNull);
    expect(
      schema.decodeJson(
        tester.widget<SelectableText>(find.byType(SelectableText)).data!,
      ),
      {
        'name': 'Example',
        'active': true,
        'role': 'reader',
        'email': 'reader@example.com',
        'website': 'https://example.com',
      },
    );

    await tester.enterText(_textField('Email (optional)'), '12231312312');
    await tester.pump();
    expect(find.byType(SelectableText), findsNothing);
    await _save(tester);
    expect(find.byType(SelectableText), findsNothing);
    expect(_fieldError(tester, 'Email (optional)'), isNotNull);
    expect(_fieldError(tester, 'Website (optional)'), isNull);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: _textField('Website (optional)'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'https://example.com',
    );

    await tester.enterText(_textField('Email (optional)'), '');
    await tester.enterText(_textField('Website (optional)'), '');
    await _save(tester);
    expect(_fieldError(tester, 'Email (optional)'), isNull);
    expect(_fieldError(tester, 'Website (optional)'), isNull);
    expect(
      schema.decodeJson(
        tester.widget<SelectableText>(find.byType(SelectableText)).data!,
      ),
      {'name': 'Example', 'active': true, 'role': 'reader'},
    );
  });

  testWidgets('example edits a custom field, submits JSON, and resets', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(CheckboxListTile), findsNothing);
    final biography = find.ancestor(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Biography (optional)',
      ),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(biography, 'A custom multiline editor.');
    await tester.ensureVisible(find.text('Save instance'));
    await tester.tap(find.text('Save instance'));
    await tester.pump();
    final output = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(output.data, contains('"biography": "A custom multiline editor."'));
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.byType(SelectableText), findsNothing);
    expect(biography, findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: biography, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      isEmpty,
    );
  });
}
