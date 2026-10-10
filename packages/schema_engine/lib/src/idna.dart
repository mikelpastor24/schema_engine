part 'unicode_data.dart';

final _greek = RegExp(r'^\p{Script=Greek}$', unicode: true);
final _hebrew = RegExp(r'^\p{Script=Hebrew}$', unicode: true);
final _japanese = RegExp(
  r'^[\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Han}]$',
  unicode: true,
);

/// Checks DNS labels with normalization, IDNA context rules, and Punycode.
bool validHostname(String value, {required bool international}) {
  if (value.isEmpty ||
      value.endsWith('.') ||
      !international && value.codeUnits.any((point) => point > 127)) {
    return false;
  }
  final normalized = international
      ? _normalize(
          value
              .replaceAll('\u200b', '')
              .replaceAll('\u3002', '.')
              .replaceAll('\uff0e', '.')
              .replaceAll('\uff61', '.'),
        )
      : value.toLowerCase();
  var length = 0;
  final decodedLabels = <List<int>>[];
  for (final label in normalized.split('.')) {
    if (label.isEmpty || label.startsWith('-') || label.endsWith('-')) {
      return false;
    }
    String decoded;
    String encoded;
    if (label.startsWith('xn--')) {
      final unicode = _decode(label.substring(4));
      if (unicode == null ||
          unicode.runes.every((point) => point < 128) ||
          _normalize(unicode) != unicode) {
        return false;
      }
      decoded = unicode;
      encoded = 'xn--${_encode(unicode)}';
      if (encoded != label) {
        return false;
      }
    } else {
      decoded = label;
      encoded = label.runes.any((point) => point > 127)
          ? 'xn--${_encode(label)}'
          : label;
    }
    if (encoded.length > 63 || !_validLabel(decoded)) {
      return false;
    }
    decodedLabels.add(decoded.runes.toList());
    length += encoded.length + (length == 0 ? 0 : 1);
    if (length > 253) {
      return false;
    }
  }
  final bidiDomain = decodedLabels.any(
    (points) => points.any((point) {
      final direction = _property(point, _bidiRanges, 3);
      return direction == 2 || direction == 3 || direction == 4;
    }),
  );
  return !bidiDomain ||
      decodedLabels.every((points) => _validBidi(points, force: true));
}

int _property(int point, List<int> ranges, int stride) {
  var lower = 0;
  var upper = ranges.length ~/ stride - 1;
  while (lower <= upper) {
    final middle = (lower + upper) ~/ 2;
    final index = middle * stride;
    if (point < ranges[index]) {
      upper = middle - 1;
    } else if (point > ranges[index + 1]) {
      lower = middle + 1;
    } else {
      return stride == 2 ? 1 : ranges[index + 2];
    }
  }
  return 0;
}

bool _validLabel(String label) {
  final points = label.runes.toList();
  if (points.isEmpty ||
      points.first == 45 ||
      points.last == 45 ||
      points.length >= 4 && points[2] == 45 && points[3] == 45 ||
      _property(points.first, _markRanges, 2) != 0) {
    return false;
  }
  var arabic = false;
  var extended = false;
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    if (point >= 0x660 && point <= 0x669) {
      arabic = true;
    } else if (point >= 0x6f0 && point <= 0x6f9) {
      extended = true;
    } else if (point == 0xb7) {
      if (i == 0 ||
          i == points.length - 1 ||
          points[i - 1] != 108 ||
          points[i + 1] != 108) {
        return false;
      }
    } else if (point == 0x375) {
      if (i == points.length - 1 ||
          !_greek.hasMatch(String.fromCharCode(points[i + 1]))) {
        return false;
      }
    } else if (point == 0x5f3 || point == 0x5f4) {
      if (i == 0 || !_hebrew.hasMatch(String.fromCharCode(points[i - 1]))) {
        return false;
      }
    } else if (point == 0x30fb) {
      if (!points.any(
        (other) =>
            other != 0x30fb && _japanese.hasMatch(String.fromCharCode(other)),
      )) {
        return false;
      }
    } else if (point == 0x200c || point == 0x200d) {
      if (i != 0 && _combining[points[i - 1]] == 9) {
        continue;
      }
      if (point == 0x200d) {
        return false;
      }
      var before = i - 1;
      var after = i + 1;
      while (before >= 0 && _property(points[before], _joiningRanges, 3) == 4) {
        before--;
      }
      while (after < points.length &&
          _property(points[after], _joiningRanges, 3) == 4) {
        after++;
      }
      if (before < 0 || after >= points.length) {
        return false;
      }
      final left = _property(points[before], _joiningRanges, 3);
      final right = _property(points[after], _joiningRanges, 3);
      if ((left != 1 && left != 3) || (right != 1 && right != 2)) {
        return false;
      }
    } else if (point != 45 && _property(point, _validRanges, 2) == 0) {
      return false;
    }
  }
  return !(arabic && extended) && _validBidi(points);
}

bool _validBidi(List<int> points, {bool force = false}) {
  final directions = points
      .map((point) => _property(point, _bidiRanges, 3))
      .toList();
  if (!force &&
      !directions.any(
        (direction) => direction == 2 || direction == 3 || direction == 4,
      )) {
    return true;
  }
  final first = directions.first;
  if (first != 1 && first != 2 && first != 3) {
    return false;
  }
  final rtl = first == 2 || first == 3;
  if (rtl && directions.contains(4) && directions.contains(5)) {
    return false;
  }
  for (final direction in directions) {
    if (direction == 0 ||
        (rtl
            ? direction == 1
            : direction == 2 || direction == 3 || direction == 4)) {
      return false;
    }
  }
  final last = directions.lastWhere(
    (direction) => direction != 6,
    orElse: () => 0,
  );
  return rtl
      ? last == 2 || last == 3 || last == 4 || last == 5
      : last == 1 || last == 5;
}

String _normalize(String value) {
  final points = <int>[];
  for (final point in value.runes) {
    if (point >= 0xac00 && point <= 0xd7a3) {
      final syllable = point - 0xac00;
      points.add(0x1100 + syllable ~/ 588);
      points.add(0x1161 + syllable % 588 ~/ 28);
      if (syllable % 28 != 0) {
        points.add(0x11a7 + syllable % 28);
      }
    } else {
      points.addAll((_mappings[point] ?? String.fromCharCode(point)).runes);
    }
  }
  for (var i = 1; i < points.length; i++) {
    final order = _combining[points[i]] ?? 0;
    if (order == 0) {
      continue;
    }
    var j = i;
    while (j > 0 && (_combining[points[j - 1]] ?? 0) > order) {
      final previous = points[j - 1];
      points[j - 1] = points[j];
      points[j] = previous;
      j--;
    }
  }
  final result = <int>[];
  var starter = -1;
  var lastOrder = 0;
  for (final point in points) {
    final order = _combining[point] ?? 0;
    final composite = starter < 0 ? null : _compose(result[starter], point);
    if (composite != null && (lastOrder < order || lastOrder == 0)) {
      result[starter] = composite;
    } else {
      if (order == 0) {
        starter = result.length;
      }
      result.add(point);
      lastOrder = order;
    }
  }
  return String.fromCharCodes(result);
}

int? _compose(int left, int right) {
  if (left >= 0x1100 && left <= 0x1112 && right >= 0x1161 && right <= 0x1175) {
    return 0xac00 + (left - 0x1100) * 588 + (right - 0x1161) * 28;
  }
  if (left >= 0xac00 &&
      left <= 0xd7a3 &&
      (left - 0xac00) % 28 == 0 &&
      right >= 0x11a8 &&
      right <= 0x11c2) {
    return left + right - 0x11a7;
  }
  return _compositions[(left << 21) | right];
}

int _adapt(int delta, int count, bool first) {
  var adjusted = first ? delta ~/ 700 : delta ~/ 2;
  adjusted += adjusted ~/ count;
  var bias = 0;
  while (adjusted > 455) {
    adjusted ~/= 35;
    bias += 36;
  }
  return bias + 36 * adjusted ~/ (adjusted + 38);
}

int _digit(int code) => code >= 97 && code <= 122
    ? code - 97
    : code >= 48 && code <= 57
    ? code - 22
    : -1;

String? _decode(String value) {
  final output = <int>[];
  final delimiter = value.lastIndexOf('-');
  var position = 0;
  if (delimiter >= 0) {
    output.addAll(value.substring(0, delimiter).codeUnits);
    position = delimiter + 1;
  }
  var point = 128;
  var index = 0;
  var bias = 72;
  while (position < value.length) {
    final previous = index;
    var weight = 1;
    for (var k = 36; ; k += 36) {
      if (position >= value.length) {
        return null;
      }
      final digit = _digit(value.codeUnitAt(position++));
      if (digit < 0 || digit > (0x7fffffff - index) ~/ weight) {
        return null;
      }
      index += digit * weight;
      final threshold = k <= bias
          ? 1
          : k >= bias + 26
          ? 26
          : k - bias;
      if (digit < threshold) {
        break;
      }
      if (weight > 0x7fffffff ~/ (36 - threshold)) {
        return null;
      }
      weight *= 36 - threshold;
    }
    final count = output.length + 1;
    bias = _adapt(index - previous, count, previous == 0);
    point += index ~/ count;
    index %= count;
    if (point > 0x10ffff || point >= 0xd800 && point <= 0xdfff) {
      return null;
    }
    output.insert(index, point);
    index++;
  }
  return output.isEmpty ? null : String.fromCharCodes(output);
}

String _encode(String value) {
  final points = value.runes.toList();
  final output = StringBuffer();
  var count = 0;
  for (final point in points) {
    if (point < 128) {
      output.writeCharCode(point);
      count++;
    }
  }
  final basic = count;
  if (basic > 0) {
    output.write('-');
  }
  var next = 128;
  var delta = 0;
  var bias = 72;
  while (count < points.length) {
    final minimum = points
        .where((point) => point >= next)
        .reduce((a, b) => a < b ? a : b);
    delta += (minimum - next) * (count + 1);
    next = minimum;
    for (final point in points) {
      if (point < next) {
        delta++;
      } else if (point == next) {
        var remaining = delta;
        for (var k = 36; ; k += 36) {
          final threshold = k <= bias
              ? 1
              : k >= bias + 26
              ? 26
              : k - bias;
          if (remaining < threshold) {
            break;
          }
          final digit = threshold + (remaining - threshold) % (36 - threshold);
          output.writeCharCode(digit < 26 ? 97 + digit : 22 + digit);
          remaining = (remaining - threshold) ~/ (36 - threshold);
        }
        output.writeCharCode(remaining < 26 ? 97 + remaining : 22 + remaining);
        bias = _adapt(delta, count + 1, count == basic);
        delta = 0;
        count++;
      }
    }
    delta++;
    next++;
  }
  return output.toString();
}
