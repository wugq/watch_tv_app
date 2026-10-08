import 'package:flutter/material.dart';
import 'package:tv/core/platform.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF3F51B5);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      scrollbarTheme: isDesktop ? _desktopScrollbar : null,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }

  /// Long lists are common (thousands of channels), so on desktop the
  /// scrollbar is always visible, thick and draggable.
  static final _desktopScrollbar = ScrollbarThemeData(
    thumbVisibility: const WidgetStatePropertyAll(true),
    trackVisibility: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered),
    ),
    thickness: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)
          ? 14
          : 10,
    ),
    radius: const Radius.circular(8),
    interactive: true,
  );
}
