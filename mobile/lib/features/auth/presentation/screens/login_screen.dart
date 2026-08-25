import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Single sign-in surface for Nearo. Google SSO is the only supported provider —
/// phone/SMS OTP was permanently discontinued.
///
/// Expects an [AuthBloc] above it in the widget tree.
class LoginScreen extends StatelessWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              onLoginSuccess();
            }
          },
          builder: (context, state) {
            final isSigningIn = state is AuthLoading;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 44),
                      if (state is AuthFailure) ...[
                        _ErrorBanner(message: state.message),
                        const SizedBox(height: 24),
                      ],
                      _GoogleSignInButton(
                        isLoading: isSigningIn,
                        onPressed: isSigningIn
                            ? null
                            : () => context
                                .read<AuthBloc>()
                                .add(GoogleSignInRequested()),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Instant sign-in for community alerts, civic feed & neighborhood safety.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const _PrivacyNote(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand Header — emblem, wordmark, civic tagline & house attribution
// ---------------------------------------------------------------------------
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 22),
        const Text(
          'Nearo',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryBlue,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        const _RuleOrnament(),
        const SizedBox(height: 16),
        const Text(
          'Sajag Nagarik, Surakshit Mohalla',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'AN ASIVERTICALS INNOVATION',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

/// Hairline rule with a centred diamond — classical divider ornament.
class _RuleOrnament extends StatelessWidget {
  const _RuleOrnament();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 48, height: 1, color: AppColors.borderSubtle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Transform.rotate(
            angle: 0.785398, // 45° — diamond
            child: Container(
              width: 5,
              height: 5,
              color: AppColors.primaryBlue.withValues(alpha: 0.45),
            ),
          ),
        ),
        Container(width: 48, height: 1, color: AppColors.borderSubtle),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Primary Action — full-width Google SSO
// ---------------------------------------------------------------------------
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surfaceCard,
          disabledBackgroundColor: AppColors.surfaceCard,
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primaryBlue,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleMark(),
                  SizedBox(width: 14),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF4285F4),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback & Trust
// ---------------------------------------------------------------------------
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sosRedLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.sosRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.sosRed,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined,
              size: 20, color: AppColors.verifiedGreen),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'DPDP Privacy Guaranteed: Your email is encrypted and never shown to other neighbors. Only your verified alias is displayed.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
