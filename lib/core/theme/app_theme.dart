// app_theme.dart
//
// Changan CS35 Plus brand color: #00529B (Changan Blue)
// Theme stubs — full design tokens added in H2 (theming feature slice).

import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Changan brand blue
  static const Color _changanBlue = Color(0xFF00529B);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _changanBlue,
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _changanBlue,
        brightness: Brightness.dark,
      );
}
