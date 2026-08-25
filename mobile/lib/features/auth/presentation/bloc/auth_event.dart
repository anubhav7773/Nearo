abstract class AuthEvent {}

/// Resident tapped "Continue with Google" — runs the Firebase Google SSO flow.
class GoogleSignInRequested extends AuthEvent {
  final String? aliasName;

  GoogleSignInRequested({this.aliasName});
}

/// Clears the local session and revokes the Google / Firebase sign-in.
class SignOutRequested extends AuthEvent {}

/// Resolves the persisted bearer token on app boot.
class CheckAuthStatus extends AuthEvent {}
