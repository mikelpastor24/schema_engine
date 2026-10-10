import 'draft.dart';
import 'idna.dart';
import 'options.dart';

/// Built-in syntactic format checks, prepared once for schema compilation.
final Map<String, FormatValidator> builtInFormats = {
  'date': _date,
  'time': _time,
  'date-time': _dateTime,
  'duration': (value) => _duration.hasMatch(value),
  'email': (value) => _email(value, international: false),
  'idn-email': (value) => _email(value, international: true),
  'hostname': (value) => _hostname(value, international: false),
  'host-name': (value) => _hostname(value, international: false),
  'idn-hostname': (value) => _hostname(value, international: true),
  'ipv4': _ipv4,
  'ip-address': _ipv4,
  'ipv6': _ipv6,
  'uri': (value) => _uri(value, absolute: true, international: false),
  'uri-reference': (value) =>
      _uri(value, absolute: false, international: false),
  'iri': (value) => _uri(value, absolute: true, international: true),
  'iri-reference': (value) => _uri(value, absolute: false, international: true),
  'uri-template': _uriTemplate,
  'uuid': (value) => _uuid.hasMatch(value),
  'json-pointer': (value) => _pointer.hasMatch(value),
  'relative-json-pointer': (value) => _relativePointer.hasMatch(value),
  'regex': _regex,
  'color': _color,
};

/// Selects built-in format semantics for the published [draft].
FormatValidator? formatForDraft(String name, SchemaDraft draft) {
  if ((name == 'hostname' || name == 'host-name') &&
      draft.index <= SchemaDraft.draft6.index) {
    return _legacyHostname;
  }
  if (name == 'time' && draft.isLegacy) {
    return (value) => _time(value, allowMissingOffset: true);
  }
  return builtInFormats[name];
}

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _timePattern = RegExp(
  r'^(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?([Zz]|[+-]\d{2}:\d{2})$',
);
final _legacyTimePattern = RegExp(
  r'^(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?([Zz]|[+-]\d{2}:\d{2})?$',
);
final _hexColor = RegExp(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');
final _rgbColor = RegExp(
  r'^rgb\(\s*[+-]?\d+\s*,\s*[+-]?\d+\s*,\s*[+-]?\d+\s*\)$',
);
final _rgbPercentColor = RegExp(
  r'^rgb\(\s*[+-]?(?:\d+(?:\.\d+)?|\.\d+)%\s*,\s*[+-]?(?:\d+(?:\.\d+)?|\.\d+)%\s*,\s*[+-]?(?:\d+(?:\.\d+)?|\.\d+)%\s*\)$',
);
const _colorNames = {
  'aqua',
  'black',
  'blue',
  'fuchsia',
  'gray',
  'green',
  'lime',
  'maroon',
  'navy',
  'olive',
  'orange',
  'purple',
  'red',
  'silver',
  'teal',
  'white',
  'yellow',
};

bool _color(String value) {
  final normalized = value.trim().toLowerCase();
  return _colorNames.contains(normalized) ||
      _hexColor.hasMatch(normalized) ||
      _rgbColor.hasMatch(normalized) ||
      _rgbPercentColor.hasMatch(normalized);
}

bool _legacyHostname(String value) {
  if (value.isEmpty || value.length > 253) {
    return false;
  }
  var length = 0;
  var previous = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit == 46) {
      if (length == 0 || previous == 45) {
        return false;
      }
      length = 0;
    } else if (unit >= 48 && unit <= 57 ||
        unit >= 65 && unit <= 90 ||
        unit >= 97 && unit <= 122 ||
        unit == 45 && length != 0) {
      if (++length > 63) {
        return false;
      }
    } else {
      return false;
    }
    previous = unit;
  }
  return length != 0 && previous != 45;
}

final _duration = RegExp(
  r'^P(?=\d|T\d)(?:\d+W|(?:\d+Y(?:\d+M(?:\d+D)?)?|\d+M(?:\d+D)?|\d+D)?(?:T(?:\d+H(?:\d+M(?:\d+S)?)?|\d+M(?:\d+S)?|\d+S))?)$',
);
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _pointer = RegExp(r'^(?:/(?:[^~]|~[01])*)*$');
final _relativePointer = RegExp(
  r'^(?:0|[1-9][0-9]*)(?:#|(?:/(?:[^~]|~[01])*)*)$',
);

final _ipv6Group = RegExp(r'^[0-9a-fA-F]{1,4}$');
final _quotedEmailLocal = RegExp(r'^"(?:[^"\\\r\n]|\\[\x20-\x7e])*"$');
final _asciiEmailLocal = RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+$");
final _internationalEmailLocal = RegExp(r'''^[^\s@(),:;<>\[\]\\"]+$''');
final _invalidUriCharacters = RegExp(r'[\x00-\x20\x7f<>"{}|\\^`]');
final _invalidPercentEscape = RegExp(r'%(?![0-9a-fA-F]{2})');
final _ipvFuture = RegExp(r"^[vV][0-9a-fA-F]+\.[A-Za-z0-9._~!$&'()*+,;=:-]+$");
final _invalidTemplateCharacters = RegExp(r'[\x00-\x20\x7f]');
final _templateExpression = RegExp(
  r'^(?:[A-Za-z0-9_]|%[0-9a-fA-F]{2})+(?:\.(?:[A-Za-z0-9_]|%[0-9a-fA-F]{2})+)*(?::[1-9][0-9]{0,3}|\*)?(?:,(?:[A-Za-z0-9_]|%[0-9a-fA-F]{2})+(?:\.(?:[A-Za-z0-9_]|%[0-9a-fA-F]{2})+)*(?::[1-9][0-9]{0,3}|\*)?)*$',
);

bool _date(String value) {
  final match = _datePattern.firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  if (month < 1 || month > 12 || day < 1) {
    return false;
  }
  final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  final days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day <= days[month - 1];
}

bool _time(String value, {bool allowMissingOffset = false}) {
  final match = (allowMissingOffset ? _legacyTimePattern : _timePattern)
      .firstMatch(value);
  if (match == null) {
    return false;
  }
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final second = int.parse(match[3]!);
  if (hour > 23 || minute > 59 || second > 60) {
    return false;
  }
  final zone = match[4] ?? 'Z';
  var offset = 0;
  if (zone.length > 1) {
    final hours = int.parse(zone.substring(1, 3));
    final minutes = int.parse(zone.substring(4, 6));
    if (hours > 23 || minutes > 59) {
      return false;
    }
    offset = (hours * 60 + minutes) * (zone[0] == '+' ? 1 : -1);
  }
  return second < 60 || (hour * 60 + minute - offset) % 1440 == 1439;
}

bool _dateTime(String value) =>
    value.length > 11 &&
    (value[10] == 'T' || value[10] == 't') &&
    _date(value.substring(0, 10)) &&
    _time(value.substring(11));

bool _ipv4(String value) {
  var separators = 0;
  var digits = 0;
  var octet = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 48 && unit <= 57) {
      if (digits == 3 || digits > 0 && octet == 0) {
        return false;
      }
      octet = octet * 10 + unit - 48;
      if (octet > 255) {
        return false;
      }
      digits++;
    } else if (unit == 46 && digits != 0 && separators < 3) {
      separators++;
      digits = 0;
      octet = 0;
    } else {
      return false;
    }
  }
  return separators == 3 && digits != 0;
}

bool _ipv6(String value) {
  if (value.isEmpty || value.contains('%') || value.contains(':::')) {
    return false;
  }
  final compressed = value.split('::');
  if (compressed.length > 2) {
    return false;
  }
  final groups = <String>[];
  for (final half in compressed) {
    if (half.isNotEmpty) {
      groups.addAll(half.split(':'));
    }
  }
  var count = 0;
  for (var i = 0; i < groups.length; i++) {
    final group = groups[i];
    if (group.contains('.')) {
      if (i != groups.length - 1 || !value.endsWith(group) || !_ipv4(group)) {
        return false;
      }
      count += 2;
    } else {
      if (!_ipv6Group.hasMatch(group)) {
        return false;
      }
      count++;
    }
  }
  return compressed.length == 2 ? count < 8 : count == 8;
}

bool _hostname(String value, {required bool international}) =>
    validHostname(value, international: international);

bool _email(String value, {required bool international}) {
  final at = value.lastIndexOf('@');
  if (at <= 0 || at == value.length - 1 || value.length > 254) {
    return false;
  }
  final local = value.substring(0, at);
  final domain = value.substring(at + 1);
  if (local.length > 64 ||
      !international && local.codeUnits.any((c) => c > 127)) {
    return false;
  }
  final quoted =
      local.startsWith('"') &&
      local.endsWith('"') &&
      _quotedEmailLocal.hasMatch(local);
  if (!quoted &&
      (local.startsWith('.') ||
          local.endsWith('.') ||
          local.contains('..') ||
          !(international ? _internationalEmailLocal : _asciiEmailLocal)
              .hasMatch(local))) {
    return false;
  }
  if (domain.startsWith('[') && domain.endsWith(']')) {
    final address = domain.substring(1, domain.length - 1);
    return address.toLowerCase().startsWith('ipv6:')
        ? _ipv6(address.substring(5))
        : _ipv4(address);
  }
  return _hostname(domain, international: international);
}

bool _uri(String value, {required bool absolute, required bool international}) {
  if (_invalidUriCharacters.hasMatch(value) ||
      _invalidPercentEscape.hasMatch(value) ||
      !international && value.codeUnits.any((c) => c > 127)) {
    return false;
  }
  try {
    var input = value;
    final opening = value.indexOf('[');
    final closing = value.indexOf(']');
    if (opening >= 0 &&
        closing > opening &&
        _ipvFuture.hasMatch(value.substring(opening + 1, closing))) {
      // Dart URI parsing does not recognize every IPvFuture spelling.
      input = value.replaceRange(opening + 1, closing, '::1');
    }
    final uri = Uri.parse(input);
    if (absolute && !uri.hasScheme) {
      return false;
    }
    if (value.contains('[') || value.contains(']')) {
      final start = value.indexOf('[');
      final end = value.indexOf(']');
      final authorityStart = value.indexOf('//') + 2;
      var authorityEnd = value.length;
      for (final delimiter in ['/', '?', '#']) {
        final index = value.indexOf(delimiter, authorityStart);
        if (index >= 0 && index < authorityEnd) {
          authorityEnd = index;
        }
      }
      if (!uri.hasAuthority ||
          start < authorityStart ||
          end < start ||
          end >= authorityEnd ||
          value.indexOf('[', start + 1) >= 0 ||
          value.indexOf(']', end + 1) >= 0 ||
          !(_ipv6(value.substring(start + 1, end)) ||
              _ipvFuture.hasMatch(value.substring(start + 1, end)))) {
        return false;
      }
    }
    return true;
  } on FormatException {
    return false;
  }
}

bool _uriTemplate(String value) {
  if (_invalidTemplateCharacters.hasMatch(value)) {
    return false;
  }
  var outside = true;
  var start = 0;
  for (var i = 0; i < value.length; i++) {
    if (value[i] == '{') {
      if (!outside) {
        return false;
      }
      outside = false;
      start = i + 1;
    } else if (value[i] == '}') {
      if (outside) {
        return false;
      }
      var expression = value.substring(start, i);
      if (expression.isNotEmpty && '+#./;?&'.contains(expression[0])) {
        expression = expression.substring(1);
      }
      if (!_templateExpression.hasMatch(expression)) {
        return false;
      }
      outside = true;
    }
  }
  return outside && !_invalidPercentEscape.hasMatch(value);
}

bool _regex(String value) {
  try {
    RegExp(value, unicode: true);
    return true;
  } on FormatException {
    return false;
  }
}
