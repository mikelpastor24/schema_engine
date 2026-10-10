import 'dart:convert';

import 'json.dart';
import 'json_number.dart';

/// Decodes JSON while preserving large integers and precise decimals.
///
/// Ordinary numbers use [int] or [double]. Values that would round use [BigInt]
/// or [JsonNumber]. Throws [FormatException] for malformed JSON. Unlike
/// `dart:convert`, decoding does not round large integer literals to doubles.
Object? decodeJson(String source) => _Parser(source).parse();

/// Encodes JSON values, including [BigInt] and [JsonNumber], without rounding.
///
/// [indent] enables pretty printing. Throws a schema exception for values
/// outside the supported JSON model, including cycles and non-finite doubles.
String encodeJson(Object? value, {String? indent}) {
  final frozen = freezeJson(value);
  final output = StringBuffer();
  void write(Object? item, int depth) {
    if (item is BigInt || item is JsonNumber) {
      output.write(item);
      return;
    }
    if (item is! Map<String, Object?> && item is! List<Object?>) {
      output.write(jsonEncode(item));
      return;
    }
    final object = item is Map<String, Object?>;
    final entries = object
        ? item.entries.map((entry) => (entry.key, entry.value)).toList()
        : (item as List<Object?>).map((entry) => (null, entry)).toList();
    output.write(object ? '{' : '[');
    for (var i = 0; i < entries.length; i++) {
      if (i != 0) {
        output.write(',');
      }
      if (indent != null) {
        output.write('\n${indent * (depth + 1)}');
      }
      if (object) {
        output.write(
          '${jsonEncode(entries[i].$1)}:${indent == null ? '' : ' '}',
        );
      }
      write(entries[i].$2, depth + 1);
    }
    if (indent != null && entries.isNotEmpty) {
      output.write('\n${indent * depth}');
    }
    output.write(object ? '}' : ']');
  }

  write(frozen, 0);
  return output.toString();
}

final class _Parser {
  _Parser(this.source);
  final String source;
  int offset = 0;

  Object? parse() {
    final result = value();
    whitespace();
    if (offset != source.length) {
      fail();
    }
    return result;
  }

  Never fail() => throw FormatException('Malformed JSON.', source, offset);

  void whitespace() {
    while (offset < source.length) {
      final unit = source.codeUnitAt(offset);
      if (unit != 32 && unit != 9 && unit != 10 && unit != 13) {
        break;
      }
      offset++;
    }
  }

  bool take(int unit) {
    whitespace();
    if (offset < source.length && source.codeUnitAt(offset) == unit) {
      offset++;
      return true;
    }
    return false;
  }

  Object? value() {
    whitespace();
    if (offset == source.length) {
      fail();
    }
    switch (source.codeUnitAt(offset)) {
      case 34:
        return string();
      case 123:
        offset++;
        final result = <String, Object?>{};
        if (take(125)) {
          return result;
        }
        do {
          whitespace();
          if (offset == source.length || source.codeUnitAt(offset) != 34) {
            fail();
          }
          final key = string();
          if (!take(58)) {
            fail();
          }
          result[key] = value();
        } while (take(44));
        if (!take(125)) {
          fail();
        }
        return result;
      case 91:
        offset++;
        final result = <Object?>[];
        if (take(93)) {
          return result;
        }
        do {
          result.add(value());
        } while (take(44));
        if (!take(93)) {
          fail();
        }
        return result;
      case 116:
        return literal('true', true);
      case 102:
        return literal('false', false);
      case 110:
        return literal('null', null);
      default:
        return number();
    }
  }

  Object? literal(String text, Object? result) {
    if (!source.startsWith(text, offset)) {
      fail();
    }
    offset += text.length;
    return result;
  }

  String string() {
    final start = offset++;
    while (offset < source.length) {
      final unit = source.codeUnitAt(offset++);
      if (unit == 92) {
        offset++;
      } else if (unit == 34) {
        return jsonDecode(source.substring(start, offset)) as String;
      }
    }
    fail();
  }

  Object number() {
    final start = offset;
    while (offset < source.length) {
      final unit = source.codeUnitAt(offset);
      if (!(unit >= 48 && unit <= 57 ||
          unit == 45 ||
          unit == 43 ||
          unit == 46 ||
          unit == 101 ||
          unit == 69)) {
        break;
      }
      offset++;
    }
    final text = source.substring(start, offset);
    final exact = JsonNumber.parse(text);
    if (exact.isIntegerLiteral) {
      final integer = int.tryParse(text);
      if (integer != null &&
          integer >= -9007199254740991 &&
          integer <= 9007199254740991) {
        return integer;
      }
      return BigInt.parse(text);
    }
    final approximate = double.tryParse(text);
    // JavaScript uses one numeric representation. Preserve decimal syntax for
    // integral values so that legacy integer validation remains accurate.
    if (identical(1, 1.0) && exact.isInteger) {
      return exact;
    }
    if (approximate != null &&
        approximate.isFinite &&
        exact.compareTo(JsonNumber.parse(approximate.toString())) == 0) {
      return approximate;
    }
    return exact;
  }
}
