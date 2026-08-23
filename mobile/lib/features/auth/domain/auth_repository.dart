abstract class AuthRepository {
  /// Send a 6-digit verification code to the resident email
  Future<Map<String, dynamic>> sendEmailOtp(String email);

  /// Verify the 6-digit email code and acquire JWT tokens
  Future<Map<String, dynamic>> verifyEmailOtp({
    required String sessionId,
    required String email,
    required String code,
    String? aliasName,
  });

  /// Sign in or sync via Google OAuth / One-Tap SSO
  Future<Map<String, dynamic>> signInWithGoogle({
    required String email,
    String? name,
    String? avatarUrl,
    String? idToken,
    String? clerkUserId,
  });

  /// Phase 1 Live Profile Sync Endpoint
  Future<Map<String, dynamic>> syncUserProfile({
    String? clerkUserId,
    String? email,
    String? aliasName,
    String? avatarUrl,
    int? preferredRadiusMeters,
  });

  /// Get current resident profile
  Future<Map<String, dynamic>> getCurrentUser();

  /// DPDP Right to Erasure / Account deletion
  Future<bool> deleteAccount();
}
