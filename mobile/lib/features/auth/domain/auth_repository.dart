abstract class AuthRepository {
  /// Sign in with Google One-Tap / Firebase Google SSO
  Future<Map<String, dynamic>> signInWithFirebaseGoogle({String? aliasName});

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

  /// Clear the local session and revoke the Google / Firebase sign-in
  Future<void> signOut();

  /// DPDP Right to Erasure / Account deletion
  Future<bool> deleteAccount();
}
