// auth_status.dart
//
// Domain enum representing the user's authentication status.
// Used by AuthNotifier to expose auth state to the app.

/// Represents whether a user session is active or not.
///
/// - [authenticated]: a valid session exists.
/// - [unauthenticated]: no session — user must log in.
/// - [pendingEmailConfirmation]: sign-up completed, waiting for user to
///   confirm their email before the session is active (email confirm ON).
enum AuthStatus {
  authenticated,
  unauthenticated,
  pendingEmailConfirmation,
}
