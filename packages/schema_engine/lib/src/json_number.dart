/// An exact finite decimal that cannot be represented by a Dart number.
///
/// `decodeJson` produces this type when a decimal would lose precision or
/// overflow a double. Integers beyond the portable exact range use [BigInt].
/// Use `encodeJson` to serialize either representation as a JSON number.
final class JsonNumber {
  JsonNumber._(this.coefficient, this.scale, this.isIntegerLiteral);

  /// Parses one JSON number without rounding.
  ///
  /// Throws [FormatException] for invalid syntax or an exponent outside Dart's
  /// integer range. The coefficient and scale are normalized by removing zeros.
  factory JsonNumber.parse(String source) {
    if (!_syntax.hasMatch(source)) {
      throw FormatException('Invalid JSON number.', source);
    }
    final parts = source.toLowerCase().split('e');
    final mantissa = parts.first;
    final dot = mantissa.indexOf('.');
    var scale =
        (dot < 0 ? 0 : mantissa.length - dot - 1) -
        (parts.length == 2 ? int.parse(parts.last) : 0);
    var coefficient = BigInt.parse(mantissa.replaceAll('.', ''));
    if (coefficient == BigInt.zero) {
      scale = 0;
    } else {
      while (coefficient % _ten == BigInt.zero) {
        coefficient ~/= _ten;
        scale--;
      }
    }
    return JsonNumber._(coefficient, scale, dot < 0 && parts.length == 1);
  }

  static final _syntax = RegExp(
    r'^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$',
  );
  static final _ten = BigInt.from(10);

  /// The normalized signed significand.
  final BigInt coefficient;

  /// The decimal scale: the value is `coefficient * 10^(-scale)`.
  final int scale;

  /// Whether the source used integer syntax, without a point or exponent.
  ///
  /// Draft 04 and earlier distinguish integer syntax from decimal syntax.
  final bool isIntegerLiteral;

  /// Whether the mathematical value is an integer.
  bool get isInteger => scale <= 0;

  /// Compares exact values, without expanding large powers of ten unnecessarily.
  int compareTo(JsonNumber other) {
    final sign = coefficient.sign.compareTo(other.coefficient.sign);
    if (sign != 0 || coefficient == BigInt.zero) {
      return sign;
    }
    final left = coefficient.abs().toString();
    final right = other.coefficient.abs().toString();
    final magnitude = (left.length - scale).compareTo(
      right.length - other.scale,
    );
    if (magnitude != 0) {
      return magnitude * coefficient.sign;
    }
    final width = left.length > right.length ? left.length : right.length;
    return left.padRight(width, '0').compareTo(right.padRight(width, '0')) *
        coefficient.sign;
  }

  @override
  String toString() {
    if (isIntegerLiteral) {
      return (coefficient * _ten.pow(-scale)).toString();
    }
    return scale == 0 ? '$coefficient.0' : '${coefficient}e${-scale}';
  }
}

/// Whether [value] is a finite JSON number supported by this package.
bool isJsonNumber(Object? value) =>
    value is num ? value.isFinite : value is BigInt || value is JsonNumber;

/// Converts a supported numeric value to its exact decimal representation.
JsonNumber exactNumber(Object value) =>
    value is JsonNumber ? value : JsonNumber.parse(value.toString());

/// Compares supported JSON numbers, preserving the native numeric fast path.
int compareNumbers(Object left, Object right) => left is num && right is num
    ? left.compareTo(right)
    : exactNumber(left).compareTo(exactNumber(right));

/// Whether a supported value is an integer in the selected lexical policy.
bool isJsonInteger(Object? value, {required bool allowDecimal}) =>
    value is int ||
    value is BigInt ||
    (allowDecimal &&
        value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) ||
    value is JsonNumber &&
        (allowDecimal ? value.isInteger : value.isIntegerLiteral);
