part of 'schema_form.dart';

class _SchemaNumberField extends StatefulWidget {
  const _SchemaNumberField({
    super.key,
    required this.field,
    required this.decoration,
    required this.integer,
  });

  final SchemaField field;
  final InputDecoration decoration;
  final bool integer;

  @override
  State<_SchemaNumberField> createState() => _SchemaNumberFieldState();
}

class _SchemaNumberFieldState extends State<_SchemaNumberField> {
  late _NumberInputFormatter _formatter;

  @override
  void initState() {
    super.initState();
    _formatter = _NumberInputFormatter(integer: widget.integer);
  }

  @override
  void didUpdateWidget(covariant _SchemaNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.integer != oldWidget.integer) {
      _formatter = _NumberInputFormatter(integer: widget.integer);
    }
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: widget.field.isPresent ? encodeJson(widget.field.value) : '',
    enabled: widget.field.enabled,
    autovalidateMode: widget.field.autovalidateMode,
    decoration: widget.decoration,
    keyboardType: TextInputType.numberWithOptions(
      signed: true,
      decimal: !widget.integer,
    ),
    inputFormatters: [_formatter],
    autocorrect: false,
    enableSuggestions: false,
    validator: widget.field.validator,
    onChanged: _onChanged,
  );

  void _onChanged(String text) {
    var source = text.replaceAll(',', '.');
    // Decimal keyboards can start a fraction with its separator. Add the
    // required JSON zero only when decoding; keep the user's caret unchanged.
    if (source.startsWith('.')) {
      source = '0$source';
    } else if (source.startsWith('-.')) {
      source = '-0${source.substring(1)}';
    }
    try {
      final decoded = decodeJson(source);
      if (_isNumber(decoded)) {
        widget.field.onChanged(decoded);
      } else {
        widget.field.setInputError('Enter a JSON number.');
      }
    } on FormatException {
      widget.field.setInputError('Enter a JSON number.');
    }
  }
}

class _NumberInputFormatter extends TextInputFormatter {
  _NumberInputFormatter({required this.integer});

  final bool integer;
  TextEditingValue? _beforeComposition;

  static final _integerInput = RegExp(r'-?(?:0|[1-9][0-9]*)?');
  static final _decimalInput = RegExp(
    r'-?(?:(?:0|[1-9][0-9]*)(?:[.,][0-9]*)?(?:[eE][+-]?[0-9]*)?'
    r'|[.,][0-9]*(?:[eE][+-]?[0-9]*)?)?',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) {
      _beforeComposition ??= oldValue;
      return newValue;
    }
    final beforeComposition = _beforeComposition;
    _beforeComposition = null;
    if (oldValue.composing.isCollapsed && oldValue.text == newValue.text) {
      return newValue;
    }
    final pattern = integer ? _integerInput : _decimalInput;
    final match = pattern.matchAsPrefix(newValue.text);
    // Accept incomplete numeric edits without stripping characters. Bounds
    // and complete-value checks belong to decoding and schema validation.
    return match != null && match.end == newValue.text.length
        ? newValue
        : beforeComposition ?? oldValue;
  }
}
