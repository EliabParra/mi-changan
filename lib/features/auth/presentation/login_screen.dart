// login_screen.dart
//
// Auth UI — Login screen (Batch D, task 5.2).
//
// Design decisions (AD-H2-2, AD-H2-3):
//   - Single screen: email field + password field + two CTAs:
//       1. "Iniciar sesión" (email+password login)
//       2. "Enviar enlace mágico" (magic link — email only)
//   - Reads auth state from [authNotifierProvider] via ConsumerStatefulWidget.
//   - Loading indicator: buttons disabled while [AsyncLoading] or waiting for
//     a pending call (tracked locally with [_submitting]).
//   - Error feedback: listens for [AsyncError] and shows a SnackBar.
//   - No business logic in this widget — delegates all auth calls to notifier.
//   - Widget Keys match contracts used by router tests (Batch C).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mi_changan/core/router/route_names.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';
import 'package:mi_changan/features/auth/presentation/widgets/auth_form_field.dart';

// ── Pure validation helpers (pure functions — easy to test independently) ─────

/// Returns an error message or null for a valid email string.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Ingresá tu email';
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(value.trim())) return 'Email inválido';
  return null;
}

/// Returns an error message or null for a valid (non-empty) password string.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Ingresá tu contraseña';
  return null;
}

/// Maps technical Supabase/exception error messages to friendly Spanish text.
///
/// Technical SDK error strings are replaced with user-facing Spanish messages.
/// If the error message is already a friendly string (e.g. set by the notifier
/// layer), it is returned as-is after stripping the "Exception: " prefix.
String _friendlyLoginError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').toLowerCase();
  if (raw.contains('invalid login credentials') ||
      raw.contains('invalid credentials')) {
    return 'Email o contraseña incorrectos. Revisá tus datos.';
  }
  if (raw.contains('email not confirmed')) {
    return 'Confirmá tu email antes de iniciar sesión.';
  }
  if (raw.contains('too many requests') || raw.contains('rate limit')) {
    return 'Demasiados intentos. Esperá unos minutos e intentá de nuevo.';
  }
  if (raw.contains('network') || raw.contains('connection')) {
    return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
  }
  // Fallback: strip the "Exception: " prefix so the message is readable.
  // Avoids leaking raw SDK stacktraces while still surfacing domain-level
  // messages that may already be user-friendly.
  final cleaned = error.toString().replaceFirst('Exception: ', '');
  return cleaned.isEmpty ? 'Ocurrió un error. Intentá de nuevo.' : cleaned;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// True while a login or magic-link network call is in-flight.
  /// Prevents double-tap submissions before the auth stream fires.
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Auth state listener ──────────────────────────────────────────────────

  /// Called on every auth state change to show errors and navigate on success.
  void _onAuthStateChanged(
    AsyncValue<AuthStatus>? previous,
    AsyncValue<AuthStatus> next,
  ) {
    if (!mounted) return;

    next.whenOrNull(
      error: (error, _) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyLoginError(error))),
        );
      },
      data: (status) {
        if (status == AuthStatus.authenticated) {
          setState(() => _submitting = false);
          context.go(RouteNames.dashboard);
        }
      },
    );
  }

  // ── CTA handlers ─────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await ref.read(authNotifierProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _handleMagicLink() async {
    // Magic link only needs the email field validated
    final emailError = validateEmail(_emailController.text);
    if (emailError != null) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _submitting = true);
    await ref.read(authNotifierProvider.notifier).sendMagicLink(
          email: _emailController.text.trim(),
        );
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisá tu email para el enlace mágico.'),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes for error / success side effects
    ref.listen(authNotifierProvider, _onAuthStateChanged);

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading || _submitting;

    return Scaffold(
      key: const Key('login_screen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  'Mi Changan',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Iniciá sesión para continuar',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── Email field ──────────────────────────────────────────
                AuthFormField(
                  testKey: const Key('login_email_field'),
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),

                // ── Password field ───────────────────────────────────────
                AuthFormField(
                  testKey: const Key('login_password_field'),
                  label: 'Contraseña',
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  validator: validatePassword,
                ),
                const SizedBox(height: 24),

                // ── Iniciar sesión CTA ────────────────────────────────────
                ElevatedButton(
                  key: const Key('login_submit_button'),
                  onPressed: isLoading ? null : _handleLogin,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 12),

                // ── Enlace mágico CTA ────────────────────────────────────
                OutlinedButton(
                  key: const Key('login_magic_link_button'),
                  onPressed: isLoading ? null : _handleMagicLink,
                  child: const Text('Enviar enlace mágico'),
                ),
                const SizedBox(height: 32),

                // ── Register link ────────────────────────────────────────
                TextButton(
                  key: const Key('login_register_link'),
                  onPressed: () => context.push(RouteNames.register),
                  child: const Text('¿No tenés cuenta? Registrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
