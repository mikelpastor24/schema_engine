import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_ui_example/main.dart';

void main() {
  testWidgets('example edits a custom field, submits JSON, and resets', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Include Biography'));
    await tester.pump();
    final biography = find.ancestor(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Biography',
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
    expect(biography, findsNothing);
  });
}
