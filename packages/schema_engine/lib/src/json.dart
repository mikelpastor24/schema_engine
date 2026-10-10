import 'dart:collection';

import 'errors.dart';
import 'json_number.dart';

/// Copies a JSON value into immutable containers.
///
/// Throws [SchemaException] for cycles, non-finite numbers, non-string object
/// keys, or values outside the JSON data model. [parents] tracks recursion.
Object? freezeJson(Object? value, [Set<Object>? parents]) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is BigInt || value is JsonNumber) {
    return value;
  }
  if (value is num) {
    if (!value.isFinite) {
      throw const SchemaException('JSON numbers must be finite.');
    }
    return value;
  }
  final ancestors = parents ?? HashSet<Object>.identity();
  if (!ancestors.add(value)) {
    throw const SchemaException('JSON values cannot contain cycles.');
  }
  try {
    if (value is Map<Object?, Object?>) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const SchemaException('JSON object keys must be strings.');
        }
        result[entry.key as String] = freezeJson(entry.value, ancestors);
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    if (value is List<Object?>) {
      return List<Object?>.unmodifiable(
        value.map((item) => freezeJson(item, ancestors)),
      );
    }
    throw SchemaException('Not a JSON value: ${value.runtimeType}.');
  } finally {
    ancestors.remove(value);
  }
}

/// Escapes one property name for use as a JSON Pointer segment.
String escapePointer(String value) =>
    value.replaceAll('~', '~0').replaceAll('/', '~1');

/// Compares JSON values structurally, ignoring object key order.
///
/// Numeric values compare by value, including an integer and an equal double.
bool jsonEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is num && right is num) {
    return left == right;
  }
  if (isJsonNumber(left) && isJsonNumber(right)) {
    return compareNumbers(left!, right!) == 0;
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!jsonEquals(left[i], right[i])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map<Object?, Object?> && right is Map<Object?, Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (final key in left.keys) {
      if (!right.containsKey(key) || !jsonEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

/// Hashes a JSON value consistently with [jsonEquals].
int jsonHash(Object? value) {
  if (value is BigInt || value is JsonNumber) {
    final exact = exactNumber(value!);
    if (exact.isInteger && -exact.scale <= 19) {
      final integer = int.tryParse(
        (exact.coefficient * BigInt.from(10).pow(-exact.scale)).toString(),
      );
      if (integer != null && compareNumbers(value, integer) == 0) {
        return integer.hashCode;
      }
    }
    final approximate = num.tryParse(value.toString());
    if (approximate != null &&
        approximate.isFinite &&
        compareNumbers(value, approximate) == 0) {
      return approximate.hashCode;
    }
    return Object.hash(exact.coefficient, exact.scale);
  }
  if (value is List<Object?>) {
    return Object.hashAll(value.map(jsonHash));
  }
  if (value is Map<Object?, Object?>) {
    var hash = 0;
    for (final entry in value.entries) {
      hash ^= Object.hash(entry.key, jsonHash(entry.value));
    }
    return Object.hash(value.length, hash);
  }
  return value.hashCode;
}
