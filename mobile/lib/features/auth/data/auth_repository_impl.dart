import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/secure_storage.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient = ApiClient();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '468650609948-4rovsabksqpertd42hgc9go8b8jbghp2.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  FirebaseAuth? get _firebaseAuth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Google One-Tap / SSO: exchanges the Google credential for a Firebase ID
  /// token, persists it as the bearer credential, then lets the backend
  /// auto-provision the Supabase resident record from that token.
  @override
  Future<Map<String, dynamic>> signInWithFirebaseGoogle({String? aliasName}) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Resident dismissed the Google account chooser — not an error state.
      if (googleUser == null) {
        return {'success': false, 'cancelled': true};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth = _firebaseAuth;
      if (auth == null) {
        return {
          'success': false,
          'error': 'Firebase is not initialised on this device.',
        };
      }

      final UserCredential userCredential =
          await auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      final String? idToken = await user?.getIdToken();

      if (user == null || idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'error': 'Google sign-in did not return a valid Firebase ID token.',
        };
      }

      final email = user.email ?? googleUser.email;
      final name = aliasName ??
          user.displayName ??
          googleUser.displayName ??
          email.split('@')[0];
      final photo = user.photoURL ?? googleUser.photoUrl;

      await SecureStorageService.saveUserSession(
        accessToken: idToken,
        refreshToken: user.refreshToken ?? '',
        userId: user.uid,
        aliasName: name,
        tier: 'free',
        email: email,
        avatarUrl: photo,
      );

      // Auto-provision / sync the resident record in Supabase via FastAPI.
      await syncUserProfile(
        email: email,
        aliasName: name,
        avatarUrl: photo,
      );

      return {
        'success': true,
        'user': {
          'id': user.uid,
          'email': email,
          'alias_name': name,
          'avatar_url': photo,
        },
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Google sign-in failed. Please try again.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<Map<String, dynamic>> signInWithGoogle({
    required String email,
    String? name,
    String? avatarUrl,
    String? idToken,
    String? clerkUserId,
  }) async {
    return signInWithFirebaseGoogle(aliasName: name);
  }

  @override
  Future<Map<String, dynamic>> syncUserProfile({
    String? clerkUserId,
    String? email,
    String? aliasName,
    String? avatarUrl,
    int? preferredRadiusMeters,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.userSync,
        data: {
          if (clerkUserId != null) 'clerk_user_id': clerkUserId,
          if (email != null) 'email': email,
          if (aliasName != null) 'alias_name': aliasName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (preferredRadiusMeters != null)
            'preferred_radius_meters': preferredRadiusMeters,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final alias = data['alias'] ?? aliasName;
        final tier = data['tier'] ?? 'free';
        final radiusKm = (data['radius_km'] is num)
            ? (data['radius_km'] as num).toDouble()
            : 1.5;

        if (alias != null) {
          await SecureStorageService.saveUserSession(
            accessToken: await SecureStorageService.getAccessToken() ?? '',
            refreshToken: await SecureStorageService.getRefreshToken() ?? '',
            userId: data['id']?.toString() ?? '',
            aliasName: alias,
            tier: tier,
            email: data['email'] ?? email,
            avatarUrl: data['avatar_url'] ?? avatarUrl,
          );
        }
        await SecureStorageService.saveRadiusKm(radiusKm);

        return {'success': true, 'data': data};
      }
    } catch (_) {}
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.usersMe);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['alias'] != null) {
          await SecureStorageService.updateUserTier(data['tier'] ?? 'free');
          if (data['radius_km'] is num) {
            await SecureStorageService.saveRadiusKm(
              (data['radius_km'] as num).toDouble(),
            );
          }
        }
        return data;
      }
    } catch (_) {
      try {
        final authMeRes = await _apiClient.dio.get(ApiEndpoints.me);
        if (authMeRes.statusCode == 200 && authMeRes.data != null) {
          return authMeRes.data;
        }
      } catch (_) {}
    }

    return {
      'alias': await SecureStorageService.getAliasName() ?? 'Resident',
      'alias_name': await SecureStorageService.getAliasName() ?? 'Resident',
      'email': await SecureStorageService.getUserEmail(),
      'tier': await SecureStorageService.getUserTier() ?? 'free',
      'radius_km': await SecureStorageService.getRadiusKm(),
    };
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}
    await SecureStorageService.clearSession();
  }

  @override
  Future<bool> deleteAccount() async {
    try {
      final response = await _apiClient.dio.delete(ApiEndpoints.deleteAccount);
      if (response.statusCode == 200) {
        await SecureStorageService.clearSession();
        try {
          await _firebaseAuth?.currentUser?.delete();
        } catch (_) {}
        return true;
      }
    } catch (_) {}
    await SecureStorageService.clearSession();
    return true;
  }
}
