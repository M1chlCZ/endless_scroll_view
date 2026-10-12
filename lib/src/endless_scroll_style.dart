import 'package:flutter/material.dart';

/// The style of the default footers of an [EndlessScrollView].
///
/// Register it in the app theme to style every endless list at once. A
/// custom `loadingBuilder`, `errorBuilder` or `endOfListBuilder` wins over
/// the style.
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       EndlessScrollStyle(loadingColor: Colors.teal),
///     ],
///   ),
/// );
/// ```
@immutable
class EndlessScrollStyle extends ThemeExtension<EndlessScrollStyle> {
  /// Creates an [EndlessScrollStyle].
  const EndlessScrollStyle({
    this.loadingColor,
    this.errorTextStyle,
    this.retryStyle,
    this.footerPadding = const EdgeInsets.all(16),
  });

  /// The color of the default loading indicator.
  final Color? loadingColor;

  /// The text style of the default error message.
  final TextStyle? errorTextStyle;

  /// The button style of the default retry button.
  final ButtonStyle? retryStyle;

  /// The padding around the default footer.
  final EdgeInsetsGeometry footerPadding;

  /// The style of the current theme, or null.
  static EndlessScrollStyle? of(BuildContext context) {
    return Theme.of(context).extension<EndlessScrollStyle>();
  }

  @override
  EndlessScrollStyle copyWith({
    Color? loadingColor,
    TextStyle? errorTextStyle,
    ButtonStyle? retryStyle,
    EdgeInsetsGeometry? footerPadding,
  }) {
    return EndlessScrollStyle(
      loadingColor: loadingColor ?? this.loadingColor,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
      retryStyle: retryStyle ?? this.retryStyle,
      footerPadding: footerPadding ?? this.footerPadding,
    );
  }

  @override
  EndlessScrollStyle lerp(EndlessScrollStyle? other, double t) {
    if (other == null) {
      return this;
    }
    return EndlessScrollStyle(
      loadingColor: Color.lerp(loadingColor, other.loadingColor, t),
      errorTextStyle: TextStyle.lerp(errorTextStyle, other.errorTextStyle, t),
      retryStyle: ButtonStyle.lerp(retryStyle, other.retryStyle, t),
      footerPadding:
          EdgeInsetsGeometry.lerp(footerPadding, other.footerPadding, t) ??
          footerPadding,
    );
  }
}
