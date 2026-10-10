part of 'schema_form.dart';

class _SchemaTextField extends StatelessWidget {
  const _SchemaTextField({
    super.key,
    required this.field,
    required this.decoration,
    this.format,
  });

  final SchemaField field;
  final InputDecoration decoration;
  final String? format;

  TextInputType get _keyboardType => switch (format) {
    'email' || 'idn-email' => TextInputType.emailAddress,
    'uri' ||
    'uri-reference' ||
    'iri' ||
    'iri-reference' ||
    'url' => TextInputType.url,
    'date' || 'time' || 'date-time' => TextInputType.datetime,
    _ => TextInputType.text,
  };

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: field.isPresent ? field.value as String : '',
    enabled: field.enabled,
    autovalidateMode: field.autovalidateMode,
    decoration: decoration,
    keyboardType: _keyboardType,
    inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
    autocorrect: _keyboardType == TextInputType.text,
    enableSuggestions: _keyboardType == TextInputType.text,
    validator: field.validator,
    onChanged: field.onChanged,
  );
}
