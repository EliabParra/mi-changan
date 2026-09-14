// register_screen.dart
//
// Auth UI — Register screen (Batch D, task 5.2).
//
// Design decisions (AD-H2-7, AD-H2-3):
//   - Separate /register route for email+password registration.
//   - Fields: email, password, confirm password.
//   - Client-side validations before calling notifier.register():
//       1. Email format
//       2. Password minimum length (6 chars)
//       3. Passwords must match
//   - Loading indicator: button disabled while [AsyncLoading].
//   - pendingEmailConfirmation state: shows inline confirmation banner.
//   - Error feedback: listens for [AsyncError] and shows SnackBar with
//     friendly Spanish message (no raw technical errors).
//   - No business logic in this widget — delegates to notifier.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mi_changan/core/router/route_names.dart';
import 'package:mi_changan/features/auth/domain/auth_notifier_provider.dart';
import 'package:mi_changan/features/auth/domain/auth_status.dart';
import 'package:mi_changan/features/auth/presentation/widgets/auth_form_field.dart';

// ── Pure validation helpers ───────────────────────────────────────────────────

/// Returns an error message or null for a valid email string.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Ingresá tu email';
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(value.trim())) return 'Email inválido';
  return null;
}

/// Returns an error message or null for a password meeting minimum requirements.
String? validateRegisterPassword(String? value) {
  if (value == null || value.isEmpty) return 'Ingresá tu contraseña';
  if (value.length < 6) {
    return 'La contraseña debe tener al menos 6 caracteres';
  }
  return null;
}

/// Returns an error message or null if confirm matches password.
String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) return 'Confirmá tu contraseña';
  if (value != password) return 'Las contraseñas no coinciden';
  return null;
}

/// Maps technical Supabase/exception error messages to friendly Spanish text.
///
/// Technical SDK error strings are replaced with user-facing Spanish messages.
/// If the error message is already a friendly string (e.g. set by the notifier
/// layer), it is returned as-is after stripping the "Exception: " prefix.
String _friendlyError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').toLowerCase();
  if (raw.contains('already registered') || raw.contains('user already exists')) {
    return 'Este email ya está registrado. Intentá iniciar sesión.';
  }
  if (raw.contains('password') && raw.contains('weak')) {
    return 'La contraseña es muy débil. Usá al menos 6 caracteres.';
  }
  if (raw.contains('invalid email')) {
    return 'El email ingresado no es válido.';
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Auth state listener ──────────────────────────────────────────────────

  void _onAuthStateChanged(
    AsyncValue<AuthStatus>? previous,
    AsyncValue<AuthStatus> next,
  ) {
    if (!mounted) return;

    next.whenOrNull(
      error: (error, _) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      },
      data: (status) {
        if (status == AuthStatus.authenticated) {
          setState(() => _submitting = false);
          context.go(RouteNames.dashboard);
        } else if (status == AuthStatus.pendingEmailConfirmation) {
          setState(() => _submitting = false);
          // Banner is shown inline — no navigation needed
        } else if (status == AuthStatus.unauthenticated) {
          // Stream emitted unauthenticated without an error (e.g. during the
          // 100 ms window before pendingEmailConfirmation is set).
          // Only clear the spinner if we're still waiting (not if banner is already showing).
          final current = previous?.valueOrNull;
          if (current != AuthStatus.pendingEmailConfirmation) {
            setState(() => _submitting = false);
          }
        }
      },
    );
  }

  // ── CTA handler ──────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await ref.read(authNotifierProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, _onAuthStateChanged);

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AsyncLoading || _submitting;
    final isPendingConfirm =
        authState.valueOrNull == AuthStatus.pendingEmailConfirmation;

    return Scaffold(
      key: const Key('register_screen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: isPendingConfirm
              ? _EmailConfirmBanner(email: _emailController.text.trim())
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        'Crear cuenta',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registrate para rastrear tu Changan',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // ── Email field ──────────────────────────────────────────
                      AuthFormField(
                        testKey: const Key('register_email_field'),
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // ── Password field ───────────────────────────────────────
                      AuthFormField(
                        testKey: const Key('register_password_field'),
                        label: 'Contraseña',
                        controller: _passwordController,
                        obscureText: true,
                        enabled: !isLoading,
                        validator: validateRegisterPassword,
                      ),
                      const SizedBox(height: 16),

                      // ── Confirm password field ───────────────────────────────
                      AuthFormField(
                        testKey: const Key('register_confirm_password_field'),
                        label: 'Confirmar contraseña',
                        controller: _confirmPasswordController,
                        obscureText: true,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.done,
                        validator: (value) => validateConfirmPassword(
                          value,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Registrarme CTA ──────────────────────────────────────
                      ElevatedButton(
                        key: const Key('register_submit_button'),
                        onPressed: isLoading ? null : _handleRegister,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Registrarme'),
                      ),
                      const SizedBox(height: 32),

                      // ── Login link ───────────────────────────────────────────
                      TextButton(
                        key: const Key('register_login_link'),
                        onPressed: () => context.push(RouteNames.login),
                        child: const Text('¿Ya tenés cuenta? Iniciá sesión'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Email confirmation banner ─────────────────────────────────────────────────

class _EmailConfirmBanner extends StatelessWidget {
  const _EmailConfirmBanner({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('register_confirm_banner'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.mark_email_unread_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '¡Revisá tu email!',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Te enviamos un email de confirmación a:',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          email,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Hacé clic en el link del email para activar tu cuenta.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Consumer(
          builder: (context, ref, _) => OutlinedButton(
            key: const Key('register_back_to_login_button'),
            onPressed: () => context.go(RouteNames.login),
            child: const Text('Volver al inicio de sesión'),
          ),
        ),
      ],
    );
  }
}
