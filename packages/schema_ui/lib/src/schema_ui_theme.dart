import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Layout settings for schema fields, supplied through [ThemeData.extensions].
///
/// Colors, typography, borders, and control sizes come from the surrounding
/// Material theme. This extension supplies spacing, which Material does not
/// expose as a general layout token.
final class SchemaUiTheme extends ThemeExtension<SchemaUiTheme> {
  /// Creates layout settings with [spacing] between fields and sections.
  const SchemaUiTheme({this.spacing = 16}) : assert(spacing >= 0);

  /// The logical pixel gap between fields and nested sections.
  final double spacing;

  @override
  SchemaUiTheme copyWith({double? spacing}) =>
      SchemaUiTheme(spacing: spacing ?? this.spacing);

  @override
  SchemaUiTheme lerp(covariant SchemaUiTheme? other, double t) => other == null
      ? this
      : SchemaUiTheme(spacing: lerpDouble(spacing, other.spacing, t)!);
}
