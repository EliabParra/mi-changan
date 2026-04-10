// auth_form_field.dart
//
// Shared styled text-form field for auth screens (login + register).
//
// Design decisions (AD-H2-2):
//   - Stateless widget — pure presentation, no business logic.
//   - Wraps [TextFormField] with consistent label, border and error styling.
//   - [validator] is injected — each screen defines its own rules.
//   - [obscureText] supports password fields.
//   - [testKey] allows test finders to locate the field by [Key].

import 'package:flutter/material.dart';

/// A styled text-form field with label, border decoration and optional
/// password obscuring — used across all auth screens.
class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.testKey,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
  });

  /// The [Key] used in widget tests to locate this field.
  final Key testKey;

  /// Label text displayed above/inside the field.
  final String label;

  /// The text editing controller.
  final TextEditingController controller;

  /// Keyboard type hint.
  final TextInputType keyboardType;

  /// If true, the text is obscured (password fields).
  final bool obscureText;

  /// Form validation function. Returns an error string or null if valid.
  final String? Function(String?)? validator;

  /// Whether the field is enabled — false during loading states.
  final bool enabled;

  /// Action button on the keyboard.
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: testKey,
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorMaxLines: 2,
      ),
      validator: validator,
    );
  }
}
