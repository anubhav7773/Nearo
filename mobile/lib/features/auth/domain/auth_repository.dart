abstract class AuthRepository {
  /// Verify phone SMS OTP via Firebase and acquire ID token
  Future<Map<String, dynamic>> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
    String? aliasName,
  });

  /// Sign in with Google One-Tap / Firebase Google SSO
  Future<Map<String, dynamic>> signInWithFirebaseGoogle({String? aliasName});

  /// Sign in or register with Email & Password
  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
    bool isSignUp = false,
    String? aliasName,
  });

  /// Send a 6-digit verification code to the resident email (REST fallback)
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
