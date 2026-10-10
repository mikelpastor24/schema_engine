part of 'schema_form.dart';

class _SchemaJsonField extends StatelessWidget {
  const _SchemaJsonField({
    super.key,
    required this.field,
    required this.decoration,
  });

  final SchemaField field;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: field.isPresent ? encodeJson(field.value) : '',
    enabled: field.enabled,
    autovalidateMode: field.autovalidateMode,
    decoration: decoration,
    keyboardType: TextInputType.multiline,
    minLines: 3,
    maxLines: null,
    autocorrect: false,
    enableSuggestions: false,
    validator: field.validator,
    onChanged: (text) {
      if (text.isEmpty && !field.isRequired) {
        field._clearValue(resetEditor: false);
        return;
      }
      try {
        field.onChanged(decodeJson(text));
      } on FormatException {
        field._setInputMessage((messages) => messages.invalidJsonError);
      }
    },
  );
}
