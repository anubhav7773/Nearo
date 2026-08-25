abstract class AuthState {}

class AuthInitial extends AuthState {}

/// Boot-time session check or an in-flight Google sign-in.
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String aliasName;
  final String? email;
  final String? avatarUrl;
  final String tier;

  AuthAuthenticated({
    required this.aliasName,
    this.email,
    this.avatarUrl,
    this.tier = 'free',
  });
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure(this.message);
}
