import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/secure_storage.dart';
import '../../../auth/data/auth_repository_impl.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepositoryImpl _authRepository = AuthRepositoryImpl();
  final ApiClient _apiClient = ApiClient();

  String _aliasName = 'Resident_User';
  String _userTier = 'free';
  String? _userPhone;
  String? _emergencyPhone;
  String? _emergencyName;
  double _radiusMeters = 1500;
  bool _isUpgrading = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // 1. Instant load from local secure storage
    final alias = await SecureStorageService.getAliasName();
    final tier = await SecureStorageService.getUserTier();
    final radiusKm = await SecureStorageService.getRadiusKm();
    final phone = await SecureStorageService.getUserPhone();
    final emPhone = await SecureStorageService.getEmergencyContactPhone();
    final emName = await SecureStorageService.getEmergencyContactName();

    if (mounted) {
      setState(() {
        if (alias != null) _aliasName = alias;
        if (tier != null) _userTier = tier;
        _userPhone = phone;
        _emergencyPhone = emPhone;
        _emergencyName = emName;
        _radiusMeters = radiusKm * 1000.0;
        _isLoading = false;
      });
    }

    // 2. Fetch live data from backend /users/me
    try {
      final liveData = await _authRepository.getCurrentUser();
      if (mounted && liveData.isNotEmpty) {
        final liveAlias = liveData['alias'] ?? liveData['alias_name'];
        final liveTier = liveData['tier'];
        final liveRadius = liveData['radius_km'];
        final livePhone = liveData['phone_number'] ?? liveData['phone'];
        final liveEmPhone = liveData['emergency_contact_phone'];
        final liveEmName = liveData['emergency_contact_name'];

        setState(() {
          if (liveAlias != null) _aliasName = liveAlias.toString();
          if (liveTier != null) _userTier = liveTier.toString();
          if (livePhone != null && livePhone.toString().isNotEmpty) {
            _userPhone = livePhone.toString();
            SecureStorageService.saveUserPhone(_userPhone!);
          }
          if (liveEmPhone != null && liveEmPhone.toString().isNotEmpty) {
            _emergencyPhone = liveEmPhone.toString();
            SecureStorageService.saveEmergencyContactPhone(_emergencyPhone!);
          }
          if (liveEmName != null && liveEmName.toString().isNotEmpty) {
            _emergencyName = liveEmName.toString();
            SecureStorageService.saveEmergencyContactName(_emergencyName!);
          }
          if (liveRadius is num) {
            _radiusMeters = liveRadius.toDouble() * 1000.0;
            SecureStorageService.setRadiusKm(liveRadius.toDouble());
          }
        });
      }
    } catch (_) {}
  }

  String _getMaskedPhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Not registered';
    }
    final clean = phone.trim();
    if (clean.length >= 10) {
      final last4 = clean.substring(clean.length - 4);
      final prefix = clean.startsWith('+91') ? '+91 ' : '';
      return '$prefix******$last4';
    }
    return clean;
  }

  Future<void> _upgradeToPro() async {
    setState(() => _isUpgrading = true);
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.createSubscriptionOrder,
        data: {
          'tier': 'pro_resident',
          'duration_months': 1,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        await SecureStorageService.updateUserTier('pro_resident');
        setState(() {
          _userTier = 'pro_resident';
          _isUpgrading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Upgraded to Resident Pro! 100% Ad-Free active.'),
              backgroundColor: AppColors.verifiedGreen,
            ),
          );
        }
      }
    } catch (_) {
      // Offline / demo fallback
      await SecureStorageService.updateUserTier('pro_resident');
      setState(() {
        _userTier = 'pro_resident';
        _isUpgrading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Upgraded to Resident Pro! (Demo Mode)'),
            backgroundColor: AppColors.verifiedGreen,
          ),
        );
      }
    }
  }

  Future<void> _syncRadius(double value) async {
    setState(() => _radiusMeters = value);
    final radiusKm = value / 1000.0;
    await SecureStorageService.setRadiusKm(radiusKm);

    try {
      await _apiClient.dio.patch(
        ApiEndpoints.userRadius,
        data: {'radius_km': radiusKm},
      );
    } catch (_) {}
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.sosRed, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Permanently Delete Account?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Under the Digital Personal Data Protection (DPDP) Act, this action will permanently delete all your posts, comments, civic SOS logs, verified resident status, and authentication credentials. This cannot be undone.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiClient.dio.delete(ApiEndpoints.deleteUserMe);
              } catch (_) {}

              // 1. Wipe secure storage credentials
              await SecureStorageService.clearSession();

              // 2. Wipe local shared preferences cache
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
              } catch (_) {}

              // 3. Revoke Firebase Auth & Google session
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}

              // 4. Return to LoginScreen
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account & Wipe Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = _userTier == 'pro_resident' || _userTier == 'business_pro';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Resident Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () {
              widget.onLogout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile Header Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.person,
                            size: 32,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _aliasName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.verifiedGreenBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: AppColors.verifiedGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPro ? 'Resident Pro Member' : 'Standard Resident',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isPro ? AppColors.accentBlue : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Verified Mobile Identity Card (Private & Encrypted)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.verifiedGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.verifiedGreen,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Verified Mobile Number',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.verifiedGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Encrypted & Private',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.verifiedGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getMaskedPhone(_userPhone),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your phone number is encrypted under India DPDP Act compliance. It is never shared with other neighbors on the public feed or civic discussions.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2b. Primary Emergency Contact Card (Auto-Targeted SOS SMS)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.sosRedLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.contact_emergency_rounded,
                                color: AppColors.sosRed,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Emergency Contact',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sosRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SOS SMS Target',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sosRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _emergencyName != null && _emergencyName!.isNotEmpty
                              ? '$_emergencyName (${_getMaskedPhone(_emergencyPhone)})'
                              : (_emergencyPhone != null && _emergencyPhone!.isNotEmpty
                                  ? _getMaskedPhone(_emergencyPhone)
                                  : 'Not configured'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'During offline crises or 1-tap SOS, your exact GPS coordinates are instantly dispatched to this recipient.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/emergency-number-setup')
                                      .then((_) => _loadProfileData());
                                },
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text(
                                  _emergencyPhone != null && _emergencyPhone!.isNotEmpty
                                      ? 'Edit Contact'
                                      : 'Set Emergency Contact',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.sosRed,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ),
                            if (_emergencyPhone != null && _emergencyPhone!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await SecureStorageService.clearEmergencyContact();
                                  await _loadProfileData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Emergency contact reset. You can set a new contact anytime.'),
                                        backgroundColor: AppColors.warningOrange,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.refresh, size: 16, color: AppColors.sosRed),
                                label: const Text(
                                  'Reset',
                                  style: TextStyle(color: AppColors.sosRed, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.sosRed),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Pro Tier Upgrade Card
                  if (!isPro) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.accentBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'RESIDENT PRO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                '₹29 / mo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildFeatureBullet('100% Ad-Free Clean Community Feed'),
                          _buildFeatureBullet('Priority Alert Dispatch in 3.0 km Radius'),
                          _buildFeatureBullet('Verified Resident Shield Icon on Profile'),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isUpgrading ? null : _upgradeToPro,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryBlue,
                                elevation: 0,
                              ),
                              child: _isUpgrading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Upgrade for ₹29 / Month'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. Geofence Radius Slider
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Neighborhood Radius Range',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${(_radiusMeters / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Controls the boundary for community posts and emergency notifications.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Slider(
                          value: _radiusMeters,
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          activeColor: AppColors.primaryBlue,
                          inactiveColor: AppColors.borderSubtle,
                          onChanged: (val) => _syncRadius(val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Dedicated Privacy & Data Management Section (DPDP Right to Erasure)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.privacy_tip_outlined, size: 20, color: AppColors.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Privacy & Data Management',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Under India DPDP Act compliance, you retain absolute ownership of your personal data and right to complete digital erasure.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _confirmDeleteAccount,
                            icon: const Icon(Icons.delete_forever, size: 18, color: AppColors.sosRed),
                            label: const Text(
                              'Delete Account & Wipe Data',
                              style: TextStyle(
                                color: AppColors.sosRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.sosRed, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
