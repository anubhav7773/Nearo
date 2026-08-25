import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/secure_storage.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Single-provider authentication BLoC: Google Sign-In only.
/// Phone/SMS OTP was permanently discontinued (billing & SMS gateway constraints).
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepositoryImpl(),
        super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final token = await SecureStorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      emit(AuthUnauthenticated());
      return;
    }

    final profile = await _authRepository.getCurrentUser();
    emit(AuthAuthenticated(
      aliasName: (profile['alias'] ?? profile['alias_name'] ?? 'Resident').toString(),
      email: profile['email']?.toString(),
      avatarUrl: profile['avatar_url']?.toString(),
      tier: (profile['tier'] ?? 'free').toString(),
    ));
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.signInWithFirebaseGoogle(
      aliasName: event.aliasName,
    );

    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>? ?? const {};
      emit(AuthAuthenticated(
        aliasName: (user['alias_name'] ??
                await SecureStorageService.getAliasName() ??
                'Resident')
            .toString(),
        email: user['email']?.toString(),
        avatarUrl: user['avatar_url']?.toString(),
        tier: await SecureStorageService.getUserTier() ?? 'free',
      ));
      return;
    }

    // A dismissed account chooser returns the resident to the login screen
    // without surfacing a red error banner.
    if (result['cancelled'] == true) {
      emit(AuthUnauthenticated());
      return;
    }

    emit(AuthFailure(
      result['error']?.toString() ?? 'Google sign-in could not be completed.',
    ));
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }
}
